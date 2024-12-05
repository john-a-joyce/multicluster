#!/bin/bash

set -e

SKIP_STEP=0

DELETE="false"

ISTIO_DIR="${ISTIO_DIR:-$HOME/samples/istio-1.24.0}"
SCRIPTDIR=$(dirname "${BASH_SOURCE}")
. "${SCRIPTDIR}"/common_args.sh
. "${SCRIPTDIR}"/metallb.sh

usage() {
  echo "DEPENDENCIES: bash, kubectl, istioctl, helm"
  echo "REQUIREMENTS: Two kind clusters with contexts named kind-kind-1 and kind-kind-2"
  echo "REQUIREMENTS cont.: helm repos added helm repo add istio https://istio-release.storage.googleapis.com/charts"
  echo "usage: $0 [OPTIONS]"
  echo ""
  echo "  OPTIONS:"
  echo "    --delete  OPTIONAL. Teardown the cluster components."
  echo ""
}

#TODO - Add Dryrun option and make metallb LB an option
for i in "$@"; do
    case $i in
        -h|--help)
            usage
            exit
            ;;
        --delete)
            DELETE="true"
            ;;

        *)
            usage
            exit 1
            ;;
    esac
done

GLOBAL_METALLB_PRFX=${GLOBAL_METALLB_PRFX:-${LB_IP_OFFSET}}
#TODO - Could make this more variable and work for more than 2 clusters
NUM_CLUSTERS=2
KIND_NUM=1
count=$NUM_CLUSTERS
for i in $(seq $count)
do
  	kubectl config use-context kind-kind-"$KIND_NUM"
    if [[ "$DELETE" == "true" ]]; then
    	#Lots of these will return a failure so just keep going.
    	set +e
    	echo ""
    	echo "Going to delete the installation"
    	echo ""
		KUBEOP="delete"
        install_metallb
    	istioctl uninstall -y --purge
    	kubectl delete namespace istio-system
    	kubectl label namespace default istio-injection-
    	kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.2.0" | kubectl delete -f -
        kubectl delete clusterroles istio-reader-clusterrole-istio-system istiod-clusterrole-istio-system istiod-gateway-controller-istio-system
        kubectl delete clusterrolebindings istio-reader-clusterrole-istio-system istiod-clusterrole-istio-system istiod-gateway-controller-istio-system --context=kind-kind-1
    	echo ""
    	echo "Deletion done"
    	echo ""
    else
    	echo ""
    	echo "Installing METALLB"
    	echo ""
		KUBEOP="apply"
        install_metallb
		echo ""
    	echo "Installing Istio"
    	echo ""
        #TODO Make the create below idempotent
        kubectl create namespace istio-system
        kubectl create secret generic cacerts -n istio-system \
            --from-file="$ISTIO_DIR"/certs/cluster"$KIND_NUM"/ca-cert.pem \
            --from-file="$ISTIO_DIR"/certs/cluster"$KIND_NUM"/ca-key.pem \
            --from-file="$ISTIO_DIR"/certs/cluster"$KIND_NUM"/root-cert.pem \
            --from-file="$ISTIO_DIR"/certs/cluster"$KIND_NUM"/cert-chain.pem
        sleep 5
    	helm install istio-base istio/base -n istio-system
		helm install istiod istio/istiod -n istio-system --set global.meshID=mesh"$KIND_NUM" --set global.multiCluster.clusterName=cluster"$KIND_NUM" --set global.network=network"$KIND_NUM" --set global.multiCLuster.enabled=true
		helm install istio-eastwestgateway istio/gateway -n istio-system --set name=istio-eastwestgateway --set networkGateway=network"$KIND_NUM"
		sleep 20
		kubectl label namespace istio-system topology.istio.io/network=network"$KIND_NUM"
		kubectl label namespace default istio-injection=enabled
		kubectl apply -n istio-system -f "$ISTIO_DIR/"samples/multicluster/expose-services.yaml
    	echo ""
    fi
	(( KIND_NUM++ ))
done
    # The below comand cause resources to be created on both clusters. So do this after both Istios up.
    # If done inline there will be collisions with some resources already created.
    # These resources are deleted as part of namespace deletion

if [[ "$DELETE" == "false" ]]; then
    echo "Creating the remote secrets which will allow the clusters to exchange state"
    istioctl create-remote-secret --context=kind-kind-2 --name=cluster2 | \
    kubectl apply -f - --context=kind-kind-1

    istioctl create-remote-secret --context=kind-kind-1 --name=cluster1 | \
    kubectl apply -f - --context=kind-kind-2
fi
