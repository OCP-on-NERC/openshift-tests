setup() {
    load 'lib/bats-support/load'
    load 'lib/bats-assert/load'
    load 'lib/common.bash'
}

@test "Check Cluster Operators status" {

    # Get unavailable operators
    unavailable_operators=$(${KUBECTL} get co --no-headers | awk '$3 != "True"')

    # Check for unavailable operators
    if [ -n "$unavailable_operators" ]; then
        echo -e "UNAVAILABLE operator/s:\n$unavailable_operators" >&3
        fail "Some cluster operators are unavailable."
    else
        echo -e "All cluster operators are Available\n"
    fi
}
