NOTPARALLEL:

.PHONY: build pull pull_subrepos test-gem5 clean

.DEFAULT_GOAL := build

SHELL := /bin/bash

DIRS=hw_isol_gem5 walkspec-hfi hfi_wasm2c_sandbox_compiler hfi_misc hfi_firefox

hw_isol_gem5:
	git clone --recursive git@github.com:PLSysSec/hw_isol_gem5.git

walkspec-hfi:
	git clone --recursive git@github.com:PLSysSec/walkspec-hfi.git
	cd walkspec-hfi && make walkspec_deps

hfi_wasm2c_sandbox_compiler:
	git clone --recursive git@github.com:PLSysSec/hfi_wasm2c_sandbox_compiler.git

hfi_misc:
	git clone --recursive git@github.com:PLSysSec/hfi_misc.git

hfi_firefox:
	git clone --recursive git@github.com:PLSysSec/hfi_firefox.git

wasi-sdk-14.0-linux.tar.gz:
	wget https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-14/wasi-sdk-14.0-linux.tar.gz

wasi-sdk: wasi-sdk-14.0-linux.tar.gz
	mkdir -p $@
	tar -zxf $< -C $@ --strip-components 1

get_source: $(DIRS) wasi-sdk

bootstrap: get_source
	sudo apt install -y make gcc g++ clang cmake python3 libpng-dev libuv1-dev \
		build-essential git m4 scons zlib1g zlib1g-dev \
		libprotobuf-dev protobuf-compiler libprotoc-dev libgoogle-perftools-dev \
		python3-dev python-is-python3 python3-pip libboost-all-dev pkg-config
	cd hfi_firefox/mybuild && make bootstrap

autopull_%:
	cd $* && git pull --rebase --autostash

pull_subrepos: $(addprefix autopull_,$(DIRS))

pull:
	git pull --rebase --autostash
	$(MAKE) pull_subrepos

build:
	cd hw_isol_gem5/mybuild && make build
	cd hfi_wasm2c_sandbox_compiler/mybuild && make build
	cd walkspec-hfi && make build
	cd hfi_firefox/mybuild && make build

test-gem5:
	cd hw_isol_gem5/mybuild && make test

clean:
	cd hw_isol_gem5/mybuild && make clean
	cd hfi_wasm2c_sandbox_compiler/mybuild && make clean
	cd hfi_firefox/mybuild && make clean
