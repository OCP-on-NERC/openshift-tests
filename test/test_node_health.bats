# Verify cluster nodes are healthy: all nodes are Ready, no pressure
# conditions (DiskPressure, MemoryPressure, PIDPressure), and nodes
# have adequate resources.

setup() {
	load 'lib/bats-support/load'
	load 'lib/bats-assert/load'
	load 'lib/common.bash'
}

@test "all nodes are ready" {
	# Get nodes that are not Ready
	not_ready=$(${KUBECTL} get nodes --no-headers | awk '$2 != "Ready"')

	if [ -n "$not_ready" ]; then
		echo -e "❌ NOT READY nodes:\n$not_ready" >&3
		fail "Some nodes are not in Ready state."
	fi

	node_count=$(${KUBECTL} get nodes --no-headers | wc -l)
	echo "✅ All $node_count nodes are Ready" >&3
}

@test "no nodes have pressure conditions" {
	# Check for DiskPressure, MemoryPressure, PIDPressure
	failed=0
	nodes=$(${KUBECTL} get nodes --no-headers -o custom-columns=":metadata.name")
	problem_nodes=""

	for node in $nodes; do
		# Check each pressure condition
		disk_pressure=$(${KUBECTL} get node "$node" -o jsonpath='{.status.conditions[?(@.type=="DiskPressure")].status}')
		memory_pressure=$(${KUBECTL} get node "$node" -o jsonpath='{.status.conditions[?(@.type=="MemoryPressure")].status}')
		pid_pressure=$(${KUBECTL} get node "$node" -o jsonpath='{.status.conditions[?(@.type=="PIDPressure")].status}')

		if [ "$disk_pressure" = "True" ]; then
			problem_nodes="${problem_nodes}Node $node has DiskPressure\n"
			failed=1
		fi

		if [ "$memory_pressure" = "True" ]; then
			problem_nodes="${problem_nodes}Node $node has MemoryPressure\n"
			failed=1
		fi

		if [ "$pid_pressure" = "True" ]; then
			problem_nodes="${problem_nodes}Node $node has PIDPressure\n"
			failed=1
		fi
	done

	if [ "$failed" -eq 0 ]; then
		node_count=$(${KUBECTL} get nodes --no-headers | wc -l)
		echo "✅ No pressure conditions on $node_count nodes" >&3
	else
		echo -e "❌ Pressure conditions found:\n$problem_nodes" >&3
		fail "Some nodes have pressure conditions."
	fi
}

@test "nodes have adequate resources" {
	# Verify nodes have CPU and memory allocatable
	failed=0
	nodes=$(${KUBECTL} get nodes --no-headers -o custom-columns=":metadata.name")
	problem_nodes=""

	for node in $nodes; do
		cpu=$(${KUBECTL} get node "$node" -o jsonpath='{.status.allocatable.cpu}')
		memory=$(${KUBECTL} get node "$node" -o jsonpath='{.status.allocatable.memory}')

		if [ -z "$cpu" ] || [ -z "$memory" ]; then
			problem_nodes="${problem_nodes}Node $node has missing resource information\n"
			failed=1
		fi
	done

	if [ "$failed" -eq 0 ]; then
		node_count=$(${KUBECTL} get nodes --no-headers | wc -l)
		echo "✅ All $node_count nodes have adequate resources" >&3
	else
		echo -e "❌ Resource issues found:\n$problem_nodes" >&3
		fail "Some nodes have missing or invalid resource information."
	fi
}
