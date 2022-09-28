# Verify that we can successfully create an ObjectBucketClaim: submit an
# OBC manifest and wait for it to become `Bound`.

setup() {
	load 'lib/bats-support/load'
	load 'lib/bats-assert/load'
	load 'lib/common.bash'
}

teardown() {
	if cluster_has_apigroup objectbucket.io; then
		${KUBECTL} -n "$TARGET_NAMESPACE" delete -f manifests/obc.yaml
	fi
}


@test "can create obc" {
	cluster_has_apigroup objectbucket.io ||
		skip "cluster has no object bucket support"

	${KUBECTL} -n "$TARGET_NAMESPACE" apply -f manifests/obc.yaml
	wait_for_phase Bound obc/test-bucket
}
