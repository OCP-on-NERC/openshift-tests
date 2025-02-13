setup() {
    load 'lib/bats-support/load'
    load 'lib/bats-assert/load'
    load 'lib/common.bash'
}

teardown() {
    ${KUBECTL} delete pod -l app=storage-test -n "$TARGET_NAMESPACE" --as system:admin
    ${KUBECTL} delete pvc -l app=storage-test -n "$TARGET_NAMESPACE" --as system:admin
}

@test "Test Storage with One PVC per Node" {
    # Get all worker nodes
    nodes=$(${KUBECTL} get nodes --no-headers -l node-role.kubernetes.io/worker -o custom-columns=":metadata.name")

    # Create PVCs for each node
    for node in $nodes; do
        cat <<EOF | ${KUBECTL} apply -n "$TARGET_NAMESPACE" --as system:admin -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: storage-test-pvc-$node
  labels:
    app: storage-test
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ocs-external-storagecluster-ceph-rbd
EOF
    done

    # Create Pods for each node
    for node in $nodes; do
        cat <<EOF | ${KUBECTL} apply -n "$TARGET_NAMESPACE" --as system:admin -f -
apiVersion: v1
kind: Pod
metadata:
  name: storage-test-pod-$node
  labels:
    app: storage-test
spec:
  tolerations:
    - key: "nvidia.com/gpu.product"
      operator: "Equal"
      value: "NVIDIA-A100-SXM4-40GB"
      effect: "NoSchedule"
    - key: "nvidia.com/gpu.product"
      operator: "Equal"
      value: "Tesla-V100-PCIE-32GB"
      effect: "NoSchedule"
  containers:
  - name: test-container
    image: quay.io/libpod/alpine
    command: [ "sleep", "600" ]
    volumeMounts:
    - mountPath: "/mnt/test"
      name: test-storage
  volumes:
  - name: test-storage
    persistentVolumeClaim:
      claimName: storage-test-pvc-$node
  nodeSelector:
    kubernetes.io/hostname: "$node"
EOF
    done

    # Wait for all Pods to reach Running state
    failed=0
    for node in $nodes; do
        pod_name="storage-test-pod-$node"
        echo "Checking Pod status: $pod_name"

        # Wait loop for pod to reach Running
        timeout=300  # Max wait time: 5 minutes
        interval=5
        elapsed=0

        while true; do

            status=$(${KUBECTL} get pod "$pod_name" -n "$TARGET_NAMESPACE" -o jsonpath="{.status.phase}")
            if [[ "$status" == "Running" ]]; then
                echo "✅ Pod $pod_name is Running" >&3
                break
            fi

            if [[ "$elapsed" -ge "$timeout" ]]; then
                echo "❌ ERROR: Pod $pod_name did not reach Running state" >&3
                failed=1
                break
            fi

            sleep "$interval"
            ((elapsed+=interval))
            echo "waiting for pod..." >&3

        done
    done

    # Fail test if any pod did not reach Running state
    if [ "$failed" -ne 0 ]; then
        fail "❌ Some pods failed to reach Running state."
    fi
}
