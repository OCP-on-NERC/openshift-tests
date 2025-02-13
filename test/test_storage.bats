setup() {
    load 'lib/bats-support/load'
    load 'lib/bats-assert/load'
    load 'lib/common.bash'
}

teardown() {
    ${KUBECTL} delete pod -l app=storage-test -n "$TARGET_NAMESPACE"
    ${KUBECTL} delete pvc -l app=storage-test -n "$TARGET_NAMESPACE"
}

@test "Test Storage with One PVC per Node" {
    # Get all worker nodes
    nodes=$(${KUBECTL} get nodes --no-headers -l node-role.kubernetes.io/worker -o custom-columns=":metadata.name")

    # Create PVCs for each node
    for node in $nodes; do
        ${KUBECTL} apply -n "$TARGET_NAMESPACE" -f - <<EOF
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
        ${KUBECTL} apply -n "$TARGET_NAMESPACE" -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: storage-test-pod-$node
  labels:
    app: storage-test
spec:
  tolerations:
    - key: "nvidia.com/gpu.product"
      operator: "Exists"
      effect: "NoSchedule"
  containers:
  - name: test-container
    image: ghcr.io/ocp-on-nerc/openshift-tests:latest
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
    timeout=300
    nodecount=$(${KUBECTL} get nodes -o name | wc -l)
    t_start=$SECONDS
    while true; do
      podcount=$(${KUBECTL} get pod -l app=storage-test -n "$TARGET_NAMESPACE" -o go-template='{{range .items}}{{.status.phase}}{{"\n"}}{{end}}' | grep Running | wc -l)
      if (( podcount = nodecount )); then
        echo "✅ All pods are Running" >&3
        break
      fi

      if (( SECONDS - t_start > timeout )); then
        echo "❌ ERROR: Timeout waiting for pods to reach Running state" >&3
        failed=1
        break
      fi
    done

    # Fail test if any pod did not reach Running state
    if [ "$failed" -ne 0 ]; then
        fail "❌ Some pods failed to reach Running state."
    fi
}
