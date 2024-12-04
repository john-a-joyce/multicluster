#!/usr/bin/env bash

# Utilities for deploying metallb

function install_metallb() {
   kubectl get configmap kube-proxy -n kube-system -o yaml | \
    sed -e "s/strictARP: false/strictARP: true/" | \
    kubectl apply -f - -n kube-system

    local cmd="${KUBEOP} -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml"

    if [[ "${CLEANUP}" == "true" ]]; then
        echo "Removing Metallb on the cluster"

    else
        echo "Installing Metallb on the cluster"

    fi

    nodeAddrPrfx=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[?(@.type=='InternalIP')].address}" | cut -d '.' -f 1,2)

    if [[ "${DRYRUN}" == "false" ]]; then
        kubectl ${cmd}
    else
        echo "kubectl ${cmd}"
    fi

    if [[ "${CLEANUP}" != "true" ]]; then
        kubectl wait pod --all --for=condition=Ready --namespace=metallb-system  --timeout=90s
        echo "Configure metallb IP range: ${nodeAddrPrfx}.${GLOBAL_METALLB_PRFX}.1-${nodeAddrPrfx}.${GLOBAL_METALLB_PRFX}.250"
    else
        # CRD deleted above so no need to delete CR
        return
    fi

    if [[ "${DRYRUN}" == "false" ]]; then
        eval "cat <<EOF | kubectl ${KUBEOP} -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - ${nodeAddrPrfx}.${GLOBAL_METALLB_PRFX}.1-${nodeAddrPrfx}.${GLOBAL_METALLB_PRFX}.250
EOF"
    fi

    # Decrease the global prefix so successive clusters can avoid pool collision
    let "GLOBAL_METALLB_PRFX--"
}
