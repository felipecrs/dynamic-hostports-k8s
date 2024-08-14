#!/bin/bash
# Runs an one-off pod on node to get the fqdn hostname using kubectl apply, wait and exec

set -euo pipefail

readonly fqdn_pod_name="$1"
readonly namespace="$2"
readonly node_name="$3"
readonly fqdn_image="$4"
readonly managed_by_label_key="$5"
readonly managed_by_label_value="$6"
readonly for_pod_label_key="$7"
readonly for_pod_label_value="$8"

trap 'kubectl -n "$namespace" delete pod "$fqdn_pod_name" --ignore-not-found --wait=false >/dev/null' EXIT

kubectl -n "$namespace" apply -f - <<EOF >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: '$fqdn_pod_name'
  labels:
    $managed_by_label_key: '$managed_by_label_value'
    $for_pod_label_key: '$for_pod_label_value'
spec:
  restartPolicy: Never
  hostNetwork: true
  nodeName: '$node_name'
  containers:
    - name: fqdn
      image: '$fqdn_image'
      command:
        - sleep
        - infinity
EOF

kubectl -n "$namespace" wait pod "${fqdn_pod_name}" --for=condition=Ready >/dev/null

output=$(kubectl -n "$namespace" exec "${fqdn_pod_name}" -- hostname -A)

printf '%s' "${output}" | cut -d' ' -f1 | grep .
