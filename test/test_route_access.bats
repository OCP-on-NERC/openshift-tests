# Verify that we can create a route and access it from outside the cluster.
# This tests ingress controller functionality, DNS resolution for routes,
# and external accessibility of services.

setup() {
	load 'lib/bats-support/load'
	load 'lib/bats-assert/load'
	load 'lib/common.bash'

	${KUBECTL} -n "$TARGET_NAMESPACE" apply -k manifests/route_access
}

teardown() {
	${KUBECTL} -n "$TARGET_NAMESPACE" delete -k manifests/route_access
}

@test "pod starts successfully" {
	wait_for_phase Running pod/test-route-pod
	echo "✅ Pod is running" >&3
}

@test "service binds endpoint" {
	timeout 30 sh -c '
		while ! ${KUBECTL} -n "$TARGET_NAMESPACE" wait \
				--for=jsonpath="{.subsets[0].ports[0].port}"=8080 \
				endpoints/test-route-service; do
			sleep 1
		done
	'
	echo "✅ Service endpoint bound" >&3
}

@test "route is created and admitted" {
	cluster_has_apigroup route.openshift.io ||
		skip "cluster does not have route support (not OpenShift)"

	# Wait for route to be admitted by the router
	timeout 30 sh -c '
		while ! ${KUBECTL} -n "$TARGET_NAMESPACE" get route test-route \
				-o jsonpath="{.status.ingress[0].conditions[?(@.type==\"Admitted\")].status}" |
				grep -q "True"; do
			sleep 1
		done
	'

	echo "✅ Route has been admitted by the ingress controller" >&3
}

@test "route is externally accessible" {
	cluster_has_apigroup route.openshift.io ||
		skip "cluster does not have route support (not OpenShift)"

	# Get the route hostname
	route_host=$(${KUBECTL} -n "$TARGET_NAMESPACE" get route test-route -o jsonpath='{.status.ingress[0].host}')

	if [ -z "$route_host" ]; then
		fail "Route hostname is empty"
	fi

	# Wait for pod to be fully ready
	${KUBECTL} -n "$TARGET_NAMESPACE" wait --for=condition=Ready --timeout=30s pod/test-route-pod

	# Attempt to access the route via HTTPS (routes use TLS edge termination)
	# Use -k to allow self-signed certificates
	# Retry a few times as routing tables may take time to update
	max_attempts=15
	attempt=0
	success=0
	last_status=""

	while [ $attempt -lt $max_attempts ]; do
		status=$(curl -k -s -o /dev/null -w "%{http_code}" "https://$route_host" 2>&1)
		last_status="$status"

		if [ "$status" != "000" ]; then
			success=1
			break
		fi

		attempt=$((attempt + 1))
		sleep 5
	done

	if [ $success -eq 0 ]; then
		echo "❌ Route not accessible (no response)" >&3
		echo "Note: HTTP 000 indicates connection failure" >&3
		fail "Route is not externally accessible"
	fi

	echo "✅ Route is externally accessible via HTTPS (HTTP $last_status)" >&3
}
