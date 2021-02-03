.PHONY: all $(MAKECMDGOALS)

BUILD_DIR := $(CURDIR)/target
TARGET := wasm32-wasi
EMSDK_DIR := $(HOME)/emsdk

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-35s\033[0m %s\n", $$1, $$2}'

install-emsdk: ## Install Emscripten SDK
	# Install emsdk for emscripten compiler. ref: https://github.com/rust-lang/rust/blob/master/src/ci/docker/scripts/emscripten.sh
	mkdir $(EMSDK_DIR) || true
	git clone https://github.com/emscripten-core/emsdk.git $(EMSDK_DIR); cd $(EMSDK_DIR); ./emsdk install 1.39.20; ./emsdk activate 1.39.20

build-rust-wasi-helloworld: ## Build wasm32-wasi hello world application
	# https://github.com/rust-lang/rust/blob/master/compiler/rustc_target/src/spec/wasm32_wasi.rs
	# https://github.com/WebAssembly/wasi-sdk
	cargo build --package wasi-helloworld --target wasm32-wasi

build-rust-wasi-httpserver: ## Build wasm32-wasi http server application. This will be failed because system call not supported
	# https://github.com/rust-lang/rust/blob/master/compiler/rustc_target/src/spec/wasm32_unknown_emscripten.rs
	cargo build --package wasi-httpserver --target wasm32-wasi

build-rust-emscripten-helloworld: ## Build wasm32-unknown-emscripten hello world application. Only wasm + JS output supported in Rust
	cargo build --package wasm-hellworld --target wasm32-unknown-emscripten
	# RUSTFLAGS="-o wasm-httpserver.wasm -C opt-level=s" cargo build --package wasi-httpserver --target wasm32-unknown-emscripten

build-cpp-emscripten-wasm: ## Build wasm32-unknown-emscripten hello world 'standalone' application vis emcc.
	rm -rf ./target/emscripten-wasm && mkdir -p ./target/emscripten-wasm
	cd ./target/emscripten-wasm && emcc $(CURDIR)/emscripten/hello.cpp -O3 -o hello.wasm

build-cpp-emscripten-js: ## Build wasm32-unknown-emscripten hello world 'non-standalone' application vis emcc.
	rm -rf ./target/emscripten-wasm-js && mkdir -p ./target/emscripten-wasm-js
	cd ./target/emscripten-wasm-js && emcc $(CURDIR)/emscripten/hello.cpp -O3 -o hello.html

build-dev-container: ## Build dev container image
	docker build -f Dockerfile.dev -t wasi-demo-dev:latest .

run-nginx-emscripten: ## Run nginx.wasm built by emscripten on wasmer runtime
	# https://syrusakbary.medium.com/running-nginx-with-webassembly-6353c02c08ac
	docker run -p 8080:8080 -w /workspace/wasmer-nginx-example wasi-demo-dev:latest /root/.wasmer/bin/wasmer run nginx.wasm -- -p . -c nginx.conf

clean: ## Clean
	cargo clean

