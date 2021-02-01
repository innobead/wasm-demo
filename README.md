> This project guides you how to run and orchestrate WASI workloads. 

# Prerequisites

- wasmtime
- wasm-to-oci
- krustlet
- kind
- rust toolchains
- AZ CLI
    - https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
- kubectl
- kustomize
    
You can use `huber`(https://github.com/innobead/huber) to install all prerequisites except rust and AZ CLI.

```console
huber install wasmtime wasm-to-oci krustlet kind kubectl kustomize
curl https://sh.rustup.rs -sSf | sh
```

# Getting Started

## Create a WASI application

```console
rustup target install wasm32-wasi
cargo init <app>
```

```console
cd <app>
cargo build --target wasm32-wasi
ls -al target/wasm32-wasi
```


## Run the WASI application on host

```console
wasetime target/wasm32-wasi/debug/<app>.wasm
```

## Package and Publish the WASI application to the OCI compatible registry

```console
az acr login --name dkoacr
linuxwasm-to-oci push target/wasm32-wasi/debug/<app>.wasm <acr-name>.azurecr.io/<app>:<version>
```

## Pull the WASI application from the OCI compatible registry

```console
linuxwasm-to-oci pull <acr-name>.azurecr.io/<app>:<version> -o <app>.wasm
wasmtime <app>.wasm
```

## Run the WASI application on the K8s cluster (Krustlet)

### 1. Set up a K8s cluster

```console
kind create cluster
```

### 2. Setup and Join a krustlet node

```console
# Prepare bootstrap token
bash <(curl https://raw.githubusercontent.com/deislabs/krustlet/master/docs/howto/assets/bootstrap.sh)
ls ~/.krustlet/config/bootstrap.conf

# Run krustlet, create the CSR (<hostname>-tls)
NODE_IP=$(ip -o -4 addr show docker0 | awk '{print $4}' | cut -d/ -f1)
KUBECONFIG=~/.krustlet/config/kubeconfig krustlet-wasi \
  --node-ip=$NODE_IP \
  --hostname=demo \
  --node-name=demo \
  --bootstrap-file ~/.krustlet/config/bootstrap.conf

# Approve signing the serving certification
kubectl certificate approve demo-tls

# Show registered nodes including krustlet node
kubectl get nodes
```

### 3. Set up a container registry

```console
./scripts/manage-acr.sh create_acr
```

### 4. Create a WASI application

[Ref](#create-a-wasi-application)

### 5. Package and Publish the WASI application to the OCI compatible registry

[Ref](#package-and-publish-the-wasi-application-to-the-oci-compatible-registry)

### 6. Create the secret for pulling images from the container

```console
./scripts/manage-acr.sh create_acr_access_secret
```

```console
kustomize edit set image dkoacr.azurecr.io/wasi-demo:v0.0.0 <acr-name>.azurecr.io/<app>:<version>
```

### 7. Create the WASI application deployment

```console
kustomize build ./examples/krustlet | kubectl apply -f -
kubectl logs -f wasi-demo
```
### 8. Clean up

```console
kustomize build ./examples/krustlet | kubectl delete -f -
./scripts/manage-acr.sh delete_acr_access_secret delete_acr
kind delete cluster

# stop kurstlet process
```

# References

- https://webassembly.org/
- https://wascc.dev/
- https://wasi.dev/
- https://wasmtime.dev/
- https://bytecodealliance.org/
- https://github.com/deislabs/krustlet/tree/master/docs