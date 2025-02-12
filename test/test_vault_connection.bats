setup() {
    load 'lib/bats-support/load'
    load 'lib/bats-assert/load'
    load 'lib/common.bash'
}

teardown() {
    ${KUBECTL} -n "$TARGET_NAMESPACE" delete daemonset test-vault-connection
}

@test "Apply DaemonSet and verify pods Vault connection" {
    # Apply the DaemonSet
    ${KUBECTL} -n "$TARGET_NAMESPACE" apply -f manifests/check_vault_daemonset.yaml

    # Wait for the DaemonSet rollout to complete (wait_for_phase does not wokr here as daemonset does not have a status)
    ${KUBECTL} -n "$TARGET_NAMESPACE" rollout status daemonset/test-vault-connection --timeout=10m

    # Get all pod names in the DaemonSet (this is a string)
    podnames=$(${KUBECTL} -n "$TARGET_NAMESPACE" get pods -l name=test-vault-connection -o jsonpath='{.items[*].metadata.name}')

    # Track failures
    failed=0

    # Check if pods connected successfully
    for pod in $podnames; do

        output=$(${KUBECTL} logs "$pod" -n "$TARGET_NAMESPACE")
        if ! echo "$output" | grep -iq "initialized"; then
            echo "❌ Pod $pod failed to connect to Vault." >&3
            node=$(${KUBECTL} get pod/"$pod" --no-headers -o wide)
            echo "The pod is running on node: $(echo "$node" | awk '{print $7}')" >&3
            failed=1  # Mark as failed
        else
            echo "✅ Pod $pod successfully connected to Vault." >&3
        fi
    done

    # If any pod failed report failure
    if [ "$failed" -ne 0 ]; then
        fail "Some pods failed to connect to Vault."
    fi
}
