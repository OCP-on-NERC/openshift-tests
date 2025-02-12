setup() {
    load 'lib/bats-support/load'
    load 'lib/bats-assert/load'
    load 'lib/common.bash'
}

@test "Check Cluster Operators status" {

    # Get unavailable operators
    unavailable_operators=$(${KUBECTL} get co --no-headers | awk '$3 != "True"')

    # Track failures
    failed=0

    if [ -n "$unavailable_operators" ]; then
        echo -e "UNAVAILABLE operator/s:\n$unavailable_operators" >&3
        failed=1
    else
        echo -e "All cluster operators are Available\n"
    fi

    # If any pod failed report failure
    if [ "$failed" -ne 0 ]; then
        fail "Some cluster operators are unavailable."
    fi
}
