setup() {
    load 'lib/bats-support/load'
    load 'lib/bats-assert/load'
    load 'lib/common.bash'
}

@test "Check MCP status" {
    
    # Define the pools to check
    pools=("master" "worker")

    # Track failures
    failed=0

    for pool in "${pools[@]}"; do
        echo "Checking MCP status for: $pool" >&3
        upgraded_status=$(${KUBECTL} get mcp "$pool" --no-headers | awk '{print $3}')

        if [[ "$upgraded_status" == "True" ]]; then
            echo -e "✅ $pool pool is Ready, all nodes are upgraded\n" >&3
        else
            echo -e "❌ $pool pool is Not Ready. Here is the command output:\n" >&3
            ${KUBECTL} get mcp "$pool" >&3
            failed=1
        fi
    done

    # If any pod failed report failure
    if [ "$failed" -ne 0 ]; then
        fail "Machine Config pool/s Not Ready."
    fi
}
