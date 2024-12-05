# Multicluster Istio with Kind

This repository contains the scripts and configuration to deploy Istio in multi-cluster mode on Kind.  The multi-primary multi-network mode is deployed.

## Dependencies

- docker
- kubectl
- Kind
- istioctl
- Helm
- make
- Metallb (although installed by the scripts)

---

## Cluster Setup

### Create 2 Kind clusters
Starting at the base of this repository.

```shell
./scripts/setup_kind_clusters.sh
```

---

## Prerequisites

The following are prerequisites before running the remaining scripts

### Add Helm Repos

We will use Helm to install Istio so we need to make sure the repos are available to helm.

```shell
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

### Download istioctl and samples [1](https://istio.io/latest/docs/setup/getting-started/#download)

```shell
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.24.1
export PATH=$PWD/bin:$PATH
```

This provides us the istioctl command.  It also provides us some samples.  Finally, we will put the CA certs we create in a sub-directory (see below).
The scripts expect **ISTIO_DIR** to be set to the location where the above download is installed.

### Create Certs [2](https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/)

A multicluster service mesh deployment requires all clusters can establish
trust between themselves.  We will use a
common root to generate intermediate certificates for each cluster

```shell
cd $ISTIO_DIR
mkdir -p certs
pushd certs
make -f ../tools/certs/Makefile.selfsigned.mk root-ca
make -f ../tools/certs/Makefile.selfsigned.mk cluster1-cacerts
make -f ../tools/certs/Makefile.selfsigned.mk cluster2-cacerts
popd
```

This only needs to be done once, but could be incorporated in the scripts to refresh each time.

---

## Deploy and configure the topology

We will use one script to deploy the infra we need and do some configuration of Istio.  This step has four main steps

1. Metallb installation and configuration
2. Istio install using helm (including gateway) [3](https://istio.io/latest/docs/setup/install/multicluster/multi-primary_multi-network/)
3. Istio base configuration and exposing remote services through the gateways
4. Configuring Istio so it can synchronize state between the two clusters

In the case of Metallb[4](https://kind.sigs.k8s.io/docs/user/loadbalancer/) it is important to configure it a way that the two clusters have reachability to each other. That the two gateways can send traffic to one another. That the two Istiods can reach the Kube API server in the opposite cluster.

```shell
./scripts/istio-2cluster.sh
```

---

## Deploying applications and manual tests

These scripts follow the steps here. [5](https://istio.io/latest/docs/setup/install/multicluster/verify/)

### Deploy Applications

It does the following:

- create ns sample in both clusters
- create service helloworld in both clusters
- deploy v1 and v2 of helloworld alternatively in each cluster

```shell
./deploy-application.sh
```

### Manual testing

Go inside a pod and try: `curl -s "helloworld.sample:5000/hello"`. When run multiple times the response should indicate the instances on both clusters.

```shell
while true; do curl -s "helloworld.sample:5000/hello"; done
```

```shell
Hello version: v1, instance: helloworld-v1-776f57d5f6-znwk5
Hello version: v2, instance: helloworld-v2-54df5f84b-qmg8t..
...
```

## Debug

- Go inside the proxy pod and use curl localhost:15000/help

### - Change the Istio multicluster logic

Play with some code here: [pkg/kube/multicluster/secretcontroller.go](https://github.com/istio/istio/blob/master/pkg/kube/multicluster/secretcontroller.go)
This small istio diff [diff](./istio-play-diff) uses a label to add and remove remote clusters without removing the secret. Note this is extraneous for testing only as one could just remove the
multicluster label to achieve the same result.


## Work in progress and next steps


## Caveats

- The scripts have not been vetted as runnable from any arbitrary directory
- There are some unused functions that are still work in progress and will contain bugs if executed. (e.g. trying to set the certSANs via kubadm patch)
- In general much of this could be ported to any two cluster environment,  but the networking required to ensure the two clusters can talk to each other will be very specific.
- Currently the services are not exchanged between the clusters, although the remote cluster state is synced.  Some config must have changed perhaps to ignore remote services in some way.

## References:

- [Download Istio](https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/)
- [Istio: Plugin CA Cert](https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/)
- [Istio: Install Multi-Primary on different networks](https://istio.io/latest/docs/setup/install/multicluster/multi-primary_multi-network/)
- [Kind: MetalLB](https://kind.sigs.k8s.io/docs/user/loadbalancer/)
- [Istio: Verify MultiCluster Installation](https://istio.io/latest/docs/setup/install/multicluster/verify/)
