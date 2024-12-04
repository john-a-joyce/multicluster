#!/usr/bin/env bash

# Shell script to setup kind clusters

# export all vars
set -a

SCRIPTDIR=$(dirname "${BASH_SOURCE}")
. "${SCRIPTDIR}"/common_args.sh

echo "$DEPLOY_ARGS"

 SETUP_DEPLOY_ARGS=
 for i in "$@"
 do
 case $i in
     -h|--help)
       print_options
       exit 0
     ;;
     *)
       if ! parse_args $i; then
            print_options
            exit 1
       fi
     ;;
 esac
 done

KINDCFGDIR=${KINDCFGDIR:-${HOME}/samples/kindcfgs}

KCONFDIR=${KCONFDIR:-${HOME}/samples/kubeconfigs/main}

KIND_NUM=${CLUSTER_START_NUM}
CLUSTER_START_NUM=${CLUSTER_START_NUM:-1}

NAME_KIND1=${NAME_KIND1:-kind-${KIND_NUM}}
let "KIND_NUM++"
NAME_KIND2=${NAME_KIND2:-kind-${KIND_NUM}}

. ${SCRIPTDIR}/kind_utils.sh

# Mock out kind for dryruns
function kind {
    echo "kind $@"
}

if [[ ${DRYRUN} == false ]]; then
    unset kind
fi

CLUSTER_PORTOFFSET=${CLUSTER_START_NUM}
function create_cluster {
    local name=$1; shift
    local kconf=$1; shift
    echo "create cluster $name -> kconf = ${kconf}"
    if [[ -n ${HOSTIP_PATTERN} ]]; then
        echo "      ... with hostip matching ${HOSTIP_PATTERN}"
        hostIP=$(get_hostip "${HOSTIP_PATTERN}")
	echo "kind_create_cluster $name ${kconf} $hostIP $CLUSTER_PORTOFFSET"
        kind_create_cluster "${name}" "${kconf}" "${hostIP}" "${CLUSTER_PORTOFFSET}"
        let "CLUSTER_PORTOFFSET++"
    else
        echo "kind_create_cluster $name ${kconf}"
        kind_create_cluster "${name}" "${kconf}"
    fi
}

if [[ "${DELETE}" == "true" ]]; then
    kind delete cluster --name "${NAME_KIND1}"
    kind delete cluster --name "${NAME_KIND2}"
    rm -rf "${KINDCFGDIR}"
    rm -rf "${KCONFDIR}"
    exit 0
fi

#if [[ "${KIND_CREATE_CLUSTERMAP}" == "true" ]]; then
 #   cat <<EOF > ${CLUSTER_MAP_FILE}
cluster1=${KCONFDIR}/${NAME_KIND1}.kubeconfig
cluster2=${KCONFDIR}/${NAME_KIND2}.kubeconfig
#EOF
#fi
# setup cluster reference to kubeconfig file mappings
#. ${CLUSTER_MAP_FILE}

mkdir -p "${KCONFDIR}"
mkdir -p "${KINDCFGDIR}"

# Create two clusters
create_cluster "${NAME_KIND1}" "${cluster1}"
create_cluster "${NAME_KIND2}" "${cluster2}"
