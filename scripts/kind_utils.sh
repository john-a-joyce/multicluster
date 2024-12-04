#!/usr/bin/env bash


K8S_STARTPORT=${K8S_STARTPORT:-38790}
JAEGER_STARTPORT=${JAEGER_STARTPORT:-38900}
KIND_IMAGE=${KIND_IMAGE:-kindest/node:v1.31.2}

function get_hostip {
    local pattern=$1; shift
    if [[ $(uname) == "Darwin" ]]; then
        ifconfig | grep inet."${pattern}" | awk '{ print $2 }'
        return 0
    fi

    ip a | grep inet."${pattern}" |  awk '{ print $2 }' | cut -d '/' -f 1
}

function convert_kconf {
    local kconf=$1; shift
    local hostip=$1; shift
    local hostport=$1; shift
    local kindName=$1; shift
    echo "Converting $kconf -- ${hostip}:${hostport}"
    kubectl --kubeconfig "${kconf}" config set "clusters.kind-$kindName.server" "https://${hostip}:${hostport}"

    # Change ~/.kube/config as well to be able to use contexts for debugging instead of kubeconfigs
    kubectl config set "clusters.kind-$kindName.server" "https://${hostip}:${hostport}"
}

function fixup-cluster() {
  local i=${1} # cluster name

  if [ "$OS" != "Darwin" ];then
    # Set container IP address as kube API endpoint in order for clusters to reach kube API servers in other clusters.
    local docker_ip
    docker_ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${i}-control-plane")
    echo "1 ${1}"
    echo "ip docker_ip"
    kubectl config set-cluster "kind-${i}" --server="https://${docker_ip}:6443"
  fi
}

function kind_create_cluster {
    local name=$1; shift
    local kconf=$1; shift
    if [[ $# > 1 ]]; then
        local hostip=$1; shift
        local portoffset=$1; shift
    fi

    if [[ -n ${hostip} ]]; then
        HOSTIP=${hostip}
        K8S_HOSTPORT=$((${K8S_STARTPORT} + $portoffset))
        JAEGER_HOSTPORT=$((${JAEGER_STARTPORT} + $portoffset))
        cat <<EOF > "${KINDCFGDIR}"/"${name}".yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: ${HOSTIP}

nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 6443
    hostPort: ${K8S_HOSTPORT}
    listenAddress: ${HOSTIP}
  - containerPort:  31922
    hostPort: ${JAEGER_HOSTPORT}
    listenAddress: ${HOSTIP}
EOF
        kind create cluster --name "${name}" --image "${KIND_IMAGE}" --config "${KINDCFGDIR}"/"${name}".yaml
    else
        kind create cluster --name "${name}" --image "${KIND_IMAGE}"
    fi
    kind get kubeconfig --name="${name}" > "${kconf}"
    if [[ -n ${hostip} ]]; then
        convert_kconf "${kconf}" "${HOSTIP}" "${K8S_HOSTPORT}" "${name}"
    else
        fixup-cluster ${name}
    fi
}
