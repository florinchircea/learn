#!/bin/bash

export KUBE_VERSION=kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315

# function setup_metallb() {

# }

function setup_nginx() {
  cluster=$1

  # Install Ingress NGINX controller
  kubectl --context "kind-$cluster" apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

  # Wait for Ingress NGINX controller to be ready
  kubectl --context "kind-$cluster" wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
}

function create_cluster() {
  cluster_config=$1

  CONFIG_FILE=$(mktemp)
  envsubst < $cluster_config > $CONFIG_FILE
  cluster_name=$(cat $CONFIG_FILE | yq '.name')
  cluster_exists=$(kind get clusters | grep $cluster_name)
  
  if [ "$cluster_exists" != "" ]; then
    echo "Delete existing cluster: $cluster_name"    
    kind delete cluster --name ${cluster_name}
  fi
  
  kind create cluster \
      --config $CONFIG_FILE \
      --verbosity 1

  setup_nginx $cluster_name
  
  rm -f $CONFIG_FILE
}

create_cluster "cluster-mgmt.yaml"
# create_cluster cluster-client.yaml
