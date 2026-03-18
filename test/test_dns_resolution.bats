# Verify that DNS resolution works correctly in the cluster.
# Tests internal cluster DNS (service.namespace.svc.cluster.local),
# short name resolution, and external DNS resolution.

setup() {
	load 'lib/bats-support/load'
	load 'lib/bats-assert/load'
	load 'lib/common.bash'

	${KUBECTL} -n "$TARGET_NAMESPACE" apply -k manifests/dns_resolution
}

teardown() {
	${KUBECTL} -n "$TARGET_NAMESPACE" delete -k manifests/dns_resolution
}

@test "dns test pod is running" {
	wait_for_phase Running pod/dns-test-pod
	# Also wait for container to be ready
	${KUBECTL} -n "$TARGET_NAMESPACE" wait --for=condition=Ready --timeout=30s pod/dns-test-pod
	echo "✅ DNS test pod is ready" >&3
}

@test "can resolve service by short name" {
	# Wait for service to exist
	${KUBECTL} -n "$TARGET_NAMESPACE" get service dns-test-service

	# Wait for pod to be ready (in case tests run in parallel or order changes)
	${KUBECTL} -n "$TARGET_NAMESPACE" wait --for=condition=Ready --timeout=30s pod/dns-test-pod

	# Try to resolve the service by short name from within the pod
	${KUBECTL} -n "$TARGET_NAMESPACE" exec dns-test-pod -- \
		getent hosts dns-test-service

	echo "✅ Service resolved by short name" >&3
}

@test "can resolve service by fqdn" {
	# Wait for service to exist
	${KUBECTL} -n "$TARGET_NAMESPACE" get service dns-test-service

	# Wait for pod to be ready
	${KUBECTL} -n "$TARGET_NAMESPACE" wait --for=condition=Ready --timeout=30s pod/dns-test-pod

	# Resolve service using fully qualified domain name
	fqdn="dns-test-service.${TARGET_NAMESPACE}.svc.cluster.local"

	${KUBECTL} -n "$TARGET_NAMESPACE" exec dns-test-pod -- \
		getent hosts "$fqdn"

	echo "✅ Service resolved by FQDN" >&3
}

@test "can resolve kubernetes service" {
	# Wait for pod to be ready
	${KUBECTL} -n "$TARGET_NAMESPACE" wait --for=condition=Ready --timeout=30s pod/dns-test-pod

	# The kubernetes service should always exist in the default namespace
	${KUBECTL} -n "$TARGET_NAMESPACE" exec dns-test-pod -- \
		getent hosts kubernetes.default.svc.cluster.local

	echo "✅ Kubernetes service resolved" >&3
}

@test "can resolve external dns" {
	# Wait for pod to be ready
	${KUBECTL} -n "$TARGET_NAMESPACE" wait --for=condition=Ready --timeout=30s pod/dns-test-pod

	# Test that external DNS resolution works
	${KUBECTL} -n "$TARGET_NAMESPACE" exec dns-test-pod -- \
		getent hosts google.com

	echo "✅ External DNS resolved" >&3
}
