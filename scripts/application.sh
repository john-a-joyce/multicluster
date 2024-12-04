#!/usr/bin/env bash

#!/bin/bash

set -e

SKIP_STEP=0

DELETE="false"

ISTIO_DIR="${ISTIO_DIR:-$HOME/samples/istio-1.24.0}"
SCRIPTDIR=$(dirname "${BASH_SOURCE}")
. "${SCRIPTDIR}"/common_args.sh

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

NUM_CLUSTERS="${NUM_CLUSTERS:-2}"

for i in $(seq "${NUM_CLUSTERS}"); do
    if [[ "$DELETE" == "true" ]]; then
        echo "Deleting application from cluster${i}"
        kubectl delete --context="kind-kind-${i}" namespace sample
    else
        echo "Installing application in cluster${i}"
        kubectl create --context="kind-kind-${i}" namespace sample
        kubectl label --context="kind-kind-${i}" namespace sample \
            istio-injection=enabled
        kubectl apply --context="kind-kind-${i}" \
            -f "${ISTIO_DIR}"/samples/helloworld/helloworld.yaml \
            -l service=helloworld -n sample

        v=$(($(($i%2))+1))
        kubectl apply --context="kind-kind-${i}" \
            -f "${ISTIO_DIR}"/samples/helloworld/helloworld.yaml \
            -l version="v${v}" -n sample
    fi
done
