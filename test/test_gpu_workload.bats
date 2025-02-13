setup() {
    load 'lib/bats-support/load'
    load 'lib/bats-assert/load'
    load 'lib/common.bash'
}

teardown() {
    ${KUBECTL} delete pods -l app=vectoradd -n "$TARGET_NAMESPACE"
}

@test "Run vectorAdd pod on all GPU nodes" {
    # Get all GPU nodes
    gpu_nodes=$(${KUBECTL} get nodes -l nvidia.com/gpu.present=true --no-headers -o custom-columns=":metadata.name")

    if [[ -z "$gpu_nodes" ]]; then
        echo "No GPU nodes found in the cluster. Skipping test." >&3
        skip
    fi

    # Deploy vectorAdd pods on each GPU node
    for node in $gpu_nodes; do
        pod_name="vectoradd-$node"
        cat <<EOF | ${KUBECTL} apply -n "$TARGET_NAMESPACE" -f -
apiVersion: v1
kind: Pod
metadata:
  name: $pod_name
  labels:
    app: vectoradd
spec:
  restartPolicy: OnFailure
  containers:
  - name: vectoradd
    image: nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda10.2
    resources:
      limits:
        nvidia.com/gpu: 1
  tolerations:
    - key: "nvidia.com/gpu.product"
      operator: "Equal"
      value: "NVIDIA-A100-SXM4-40GB"
      effect: "NoSchedule"
    - key: "nvidia.com/gpu.product"
      operator: "Equal"
      value: "Tesla-V100-PCIE-32GB"
      effect: "NoSchedule"
  nodeSelector:
    kubernetes.io/hostname: $node
EOF
    done

    # Wait and check if all pods reached "Completed" status
    failed=0
    for node in $gpu_nodes; do

      pod_name="vectoradd-$node"
      timeout=300
      interval=5
      elapsed=0

      while [[ $elapsed -lt $timeout ]]; do
        pod_status=$(${KUBECTL} get pod "$pod_name" -n "$TARGET_NAMESPACE" -o jsonpath="{.status.phase}")

        if [[ "$pod_status" == "Succeeded" ]]; then
          echo "Pod $pod_name has completed successfully." >&3
          break
        fi

        if [[ "$pod_status" == "Failed" ]]; then
          echo "Pod $pod_name failed!" >&3
          failed=1
          break
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
      done

      if [[ $elapsed -ge $timeout ]]; then
        echo "Timeout reached waiting for $pod_name to complete." >&3
        failed=1
      fi
    done



    # Fail test if any pod did not start successfully
    if [[ "$failed" -ne 0 ]]; then
        fail "Some vectorAdd pods failed to reach Running or Succeeded state."
    fi
}
