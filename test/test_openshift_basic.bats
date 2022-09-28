# Test basic OpenShift functionality: Can we perform simple API operations
# like listing namespaces? Are there any failed pods? Is the ClusterVersion
# resource `Available`? Etc.

setup() {
	load 'lib/bats-support/load'
	load 'lib/bats-assert/load'
	load 'lib/common.bash'
}

@test "can get default namespace" {
	${KUBECTL} get ns default
}

@test "no system pods are failing" {
	diff -u /dev/null \
		<(
			${KUBECTL} get --no-headers pod -A  |
			grep -E '(kube|openshift)-' |
			grep -Ev "Running|Completed"
		)
}

@test "clusterversion is available" {
	cluster_has_apigroup config.openshift.ioa ||
		skip "cluster does not have clusterversion resource"

	${KUBECTL} -n "$TARGET_NAMESPACE" wait --for=condition=available \
		--timeout=10s clusterversion version
}
