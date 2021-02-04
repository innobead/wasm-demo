#!/usr/bin/env bash

function step() {
  read -r
  clear
  printf "> %s" "$1"
  read -r

  set -o xtrace
  $2
  set +o xtrace

  printf "\n"
}

function create_build_wasi_app() {
  make build-rust-wasi-helloworld
  tree target/wasm32-wasi/debug
}

function run_wasi_app_local() {
  echo run \"wasmtime target/wasm32-wasi/debug/wasi-helloworld.wasm\" to check the ouptut
}

function setup_container_registry() {
  ./scripts/manage-acr.sh create_acr
}

function package_publish_wasi_app() {
  az acr login --name dkoacr
  linuxwasm-to-oci push target/wasm32-wasi/debug/wasi-helloworld.wasm dkoacr.azurecr.io/wasm-demo:v0.0.0
}

function verify_published_wasi_app() {
  linuxwasm-to-oci pull dkoacr.azurecr.io/wasm-demo:v0.0.0 -o wasm-demo.wasm
  echo run \"wasmtime wasm-demo.wasm\" to check the ouptut
}

function setup_k8s_cluster() {
  kind delete cluster || true
  kind create cluster
}

function setup_krustlet_node_join_cluster() {
  rm -rf ~/.krustlet

  # Prepare bootstrap token
  bash <(curl https://raw.githubusercontent.com/deislabs/krustlet/master/docs/howto/assets/bootstrap.sh)
  ls ~/.krustlet/config/bootstrap.conf

  # Run krustlet, create the CSR (<hostname>-tls)
  NODE_IP=$(ip -o -4 addr show docker0 | awk '{print $4}' | cut -d/ -f1)
  KUBECONFIG=~/.krustlet/config/kubeconfig krustlet-wasi \
    --node-ip=$NODE_IP \
    --hostname=demo \
    --node-name=demo \
    --bootstrap-file ~/.krustlet/config/bootstrap.conf >krustlet.log 2>&1 &

  # Approve signing the serving certification
  kubectl certificate approve demo-tls

  # Show registered nodes including krustlet node
  kubectl get nodes
}

function create_container_registry_pull_secret() {
  ./scripts/manage-acr.sh create_acr_access_secret
  kubectl get secret

  pushd ./examples/krustlet || exit
  kustomize edit set image dkoacr.azurecr.io/wasm-demo:v0.0.0 dkoacr.azurecr.io/wasm-demo:v0.0.0
  popd || exit
}

function deploy_wasi_app_to_cluster() {
  kustomize build ./examples/krustlet | kubectl apply -f -
  echo run \"kubectl logs -f wasm-demo\" to check the output
}

function cleanup() {
  kustomize build ./examples/krustlet | kubectl delete -f -
  ./scripts/manage-acr.sh delete_acr_access_secret delete_acr

  pgrep krustlet-wasi | xargs kill -9
  rm -rf ~/.krustlet

  kind delete cluster
}

step1="Create and build a WASI application 🔥"
step2="Run the WASI application on host"
step3="Set up a container registry"
step4="Package and publish the WASI application to the OCI compatible registry"
step5="Verify the uploaded WASI application from the OCI compatible registry"
step6="Set up a K8s cluster"
step7="Setup and Join a Krustlet node"
step8="Create the secret for pulling images from the container"
step9="Deploy the WASI application to the cluster"

cat <<EOT
Demo - Manage WASM workloads by Krustlet on K8s cluster

- $step1
- $step2
- $step3
- $step4
- $step5
- $step6
- $step7
- $step8
- $step9
EOT

step "$step1" create_build_wasi_app
step "$step2" run_wasi_app_local
step "$step3" setup_container_registry
step "$step4" package_publish_wasi_app
step "$step5" verify_published_wasi_app
step "$step6" setup_k8s_cluster
step "$step7" setup_krustlet_node_join_cluster
step "$step8" create_container_registry_pull_secret
step "$step9" deploy_wasi_app_to_cluster

printf "\nThank you!\n"
step "Clean up" cleanup
