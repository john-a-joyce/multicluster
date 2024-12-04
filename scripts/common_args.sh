#!/usr/bin/env bash

# Functions for parsing common arguments to several exec scripts

# export all vars
set -a

# Checks if $GOPATH is set. If not uses /go for default
DIR_ROOT=${GOPATH}
if [[ ${DIR_ROOT} == "" ]]; then
    DIR_ROOT="/go"
fi

print_options() {
    echo "
Options:
  --kind-hostip=PATTERN     Configure KinD clusters to use host IP matching the pattern
  --cluster-start-num=<num> The starting number to use for the clusters (default=1)
  --kind-kubecfgdir=<dir>   The root directory to use for storing kubeconfigs (default=${HOME})
  --cluster-map-file=<>     The filename to use for the generated clustermap file when --kind-kubecfgdir
                              is set. (default=config/kind_clustermaps.sh)
  --lb-ip-offset=<num>      IPAM offset for configuring metallb (default=${LB_IP_OFFSET})
  --no-metallb              Don't use metallb for a LB controller (use this option if the cloud
                              already has a loadbalancer controller, ie. AWS)
  --aws                      Installation on AWS EKS clusters
  --delete                   Delete the clusters.
  --cleanup                  Delete the deployments.
  --dry-run                  Just print out all sub-component install scripts' invocations

    " >&2
}

AWS=false
DRYRUN=false
USE_METALLB=true
LB_IP_OFFSET=255
CLUSTER_START_NUM=${CLUSTER_START_NUM:-1}
KCONFDIR_ROOT=${HOME}/samples
#KIND_CREATE_CLUSTERMAP=false
#CLUSTER_MAP_FILE=${SCRIPTDIR}/config/kind_clustermaps.sh

function parse_args {

    for i in "$@"
    do
        case $i in
            --kind-hostip=*)
                HOSTIP_PATTERN="${i#*=}"
                ;;
            --cluster-start-num=*)
                CLUSTER_START_NUM="${i#*=}"
                ;;
            #--cluster-map-file=*)
                #CLUSTER_MAP_FILE="${i#*=}"
                #;;
            --kind-kubecfgdir=*)
                KCONFDIR_ROOT="${i#*=}"
                #KIND_CREATE_CLUSTERMAP=true
                ;;
            --aws)
               USE_METALLB=false
                AWS=true
                ;;
            --lb-ip-offset=*)
                LB_IP_OFFSET="${i#*=}"
                ;;
            --no-metallb)
                USE_METALLB=false
                ;;
            --delete)
                DELETE=true
                CLEANUP=true
                ;;
            --cleanup)
                CLEANUP=true
                DELETE=true
                ;;
            --dry-run)
                DRYRUN=true
                ;;
            -h|--help)
                print_common_options
                ;;
            *)
                return 1;
                ;;
        esac
    done
}

