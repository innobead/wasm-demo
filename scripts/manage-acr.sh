#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
#set -o xtrace

# ref: https://docs.microsoft.com/en-us/azure/container-registry/container-registry-auth-kubernetes

AZ_RESOURCE_GROUP=${AZ_RESOURCE_GROUP:-dko}
AZ_ACR_NAME=${AZ_ACR_NAME:-dkoacr}
AZ_SP_NAME=${AZ_SP_NAME:-dko-wasi-sp}

K8S_NAMESPACE=${K8S_NAMESPACE:-default}
K8S_CR_SECRET=${K8S_CR_SECRET:-demo-wasi-secret}

# shellcheck disable=SC2086
function create_acr() {
  az acr create --sku Basic --resource-group ${AZ_RESOURCE_GROUP} --name ${AZ_ACR_NAME}
}

# shellcheck disable=SC2086
function delete_acr() {
  az acr delete -n ${AZ_ACR_NAME}
}

# shellcheck disable=SC2086
function create_acr_access_secret() {
  ACR_REGISTRY_ID=$(az acr show --name $AZ_ACR_NAME --query id --output tsv)
  SP_PASSWD=$(az ad sp create-for-rbac --name http://$AZ_SP_NAME --scopes $ACR_REGISTRY_ID --role acrpull --query password --output tsv)
  SP_APP_ID=$(az ad sp show --id http://$AZ_SP_NAME --query appId --output tsv)

  kubectl create secret docker-registry $K8S_CR_SECRET \
    --namespace $K8S_NAMESPACE \
    --docker-server=$AZ_ACR_NAME.azurecr.io \
    --docker-username=$SP_APP_ID \
    --docker-password=$SP_PASSWD
}

# shellcheck disable=SC2086
function delete_acr_access_secret() {
  az ad sp delete --id http://$AZ_SP_NAME || true
  kubectl delete secret $$K8S_CR_SECRET --namespace $K8S_NAMESPACE || true
}

function help() {
  cat <<EOF
Usage: create_acr | delete_acr | create_acr_access_secret | delete_acr_access_secret
EOF
}

if [[ $# -lt 1 ]]; then
  printf "[error] Please specify correct commands\n" >&2
  help
  exit 1
fi

while [[ $# -ge 1 ]]; do
  case $1 in
  create_acr | delete_acr | create_acr_access_secret | delete_acr_access_secret)
    echo "Action: $1"
    $1
    shift
    ;;
  *)
    printf "[error] Invalid command: %s\n" "$1" >&2
    help
    exit 1
    ;;
  esac
done
