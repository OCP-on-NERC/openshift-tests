# Verify that the internal OpenShift image registry is functional.
# Tests registry operator status, registry pods are running, and
# that the registry is accessible for image operations.

setup() {
	load 'lib/bats-support/load'
	load 'lib/bats-assert/load'
	load 'lib/common.bash'
}

teardown() {
	${KUBECTL} -n "$TARGET_NAMESPACE" delete -k manifests/image_registry --ignore-not-found
}


@test "image registry operator is available" {
	cluster_has_apigroup config.openshift.io ||
		skip "cluster does not have OpenShift image registry (not OpenShift)"

	# Check if the image registry operator exists and is available
	${KUBECTL} get clusteroperator image-registry ||
		skip "image registry operator not found"

	# Check operator status
	available=$(${KUBECTL} get clusteroperator image-registry -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')

	if [ "$available" != "True" ]; then
		${KUBECTL} get clusteroperator image-registry >&3
		fail "Image registry operator is not available"
	fi

	echo "✅ Image registry operator is available" >&3
}

@test "image registry pods are running" {
	cluster_has_apigroup config.openshift.io ||
		skip "cluster does not have OpenShift image registry (not OpenShift)"

	${KUBECTL} get deployment -n openshift-image-registry image-registry ||
		skip "image registry deployment not found"

	# Wait for registry pods to be ready
	timeout 60 sh -c '
		while ! ${KUBECTL} -n openshift-image-registry wait \
				--for=condition=Available \
				--timeout=10s \
				deployment/image-registry 2>/dev/null; do
			sleep 2
		done
	'

	# Get running registry pods
	running_pods=$(${KUBECTL} get pods -n openshift-image-registry \
		-l docker-registry=default \
		--field-selector=status.phase=Running \
		--no-headers | wc -l)

	if [ "$running_pods" -eq 0 ]; then
		echo "❌ No image registry pods are running" >&3
		${KUBECTL} get pods -n openshift-image-registry -l docker-registry=default >&3
		fail "No image registry pods are running"
	fi

	echo "✅ Image registry has $running_pods running pod(s)" >&3
}

@test "image registry service is accessible" {
	cluster_has_apigroup config.openshift.io ||
		skip "cluster does not have OpenShift image registry (not OpenShift)"

	# Check if the registry service exists
	${KUBECTL} -n openshift-image-registry get service image-registry ||
		fail "Image registry service not found"

	# Check if service has endpoints
	timeout 30 sh -c '
		while ! ${KUBECTL} -n openshift-image-registry get endpoints image-registry \
				-o jsonpath="{.subsets[0].addresses[0].ip}" 2>/dev/null | grep -q .; do
			sleep 2
		done
	'

	echo "✅ Image registry service is accessible" >&3
}

@test "image registry storage is configured" {
	cluster_has_apigroup config.openshift.io ||
		skip "cluster does not have OpenShift image registry (not OpenShift)"

	# Check registry configuration for storage
	storage_type=$(${KUBECTL} get configs.imageregistry.operator.openshift.io cluster \
		-o jsonpath='{.spec.storage}' 2>/dev/null)

	if [ -z "$storage_type" ] || [ "$storage_type" = "{}" ]; then
		echo "❌ Image registry storage is not configured" >&3
		fail "Image registry storage is not configured"
	fi

	echo "✅ Image registry storage is configured" >&3
}

@test "can pull image from internal registry" {
	cluster_has_apigroup image.openshift.io ||
		skip "cluster does not have OpenShift image registry (not OpenShift)"

	# Create the imagestream
	${KUBECTL} -n "$TARGET_NAMESPACE" apply -f manifests/image_registry/imagestream.yaml

	# Wait for the imagestream to import
	timeout 120 sh -c '
		while ! ${KUBECTL} -n "$TARGET_NAMESPACE" get imagestream test-registry-pull \
				-o jsonpath="{.status.tags[0].items[0].dockerImageReference}" 2>/dev/null | grep -q .; do
			sleep 2
		done
	'

	# Get the internal registry reference for logging
	internal_image=$(${KUBECTL} -n "$TARGET_NAMESPACE" get imagestream test-registry-pull \
		-o jsonpath='{.status.dockerImageRepository}:latest')
	echo "Internal registry image: $internal_image" >&3

	# Create a pod that pulls from the internal registry
	INTERNAL_IMAGE="$internal_image" envsubst < manifests/image_registry/pod.yaml | ${KUBECTL} -n "$TARGET_NAMESPACE" apply -f -

	# Wait for pod to start (which means image pull succeeded)
	timeout 120 sh -c '
		while true; do
			phase=$(${KUBECTL} -n "$TARGET_NAMESPACE" get pod test-registry-pull-pod \
				-o jsonpath="{.status.phase}" 2>/dev/null)
			if [ "$phase" = "Running" ] || [ "$phase" = "Succeeded" ]; then
				break
			fi
			if [ "$phase" = "Failed" ]; then
				exit 1
			fi
			sleep 2
		done
	'

	echo "✅ Successfully pulled image from internal registry" >&3
}
