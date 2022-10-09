NOTPARALLEL:

.PHONY: build pull pull_subrepos test-gem5 clean

.DEFAULT_GOAL := build

SHELL := /bin/bash

DIRS=hw_isol_gem5 walkspec-hfi hfi_wasm2c_sandbox_compiler

x86_64-linux-musl-native.tgz:
	wget https://musl.cc/x86_64-linux-musl-native.tgz

musl-gcc: x86_64-linux-musl-native.tgz
	mkdir -p $@
	tar -zxf x86_64-linux-musl-native.tgz -C $@ --strip-components 1

hw_isol_gem5:
	git clone --recursive git@github.com:PLSysSec/hw_isol_gem5.git

walkspec-hfi:
	git clone --recursive git@github.com:PLSysSec/walkspec-hfi.git
	cd walkspec-hfi && make walkspec_deps

hfi_wasm2c_sandbox_compiler:
	git clone --recursive git@github.com:PLSysSec/hfi_wasm2c_sandbox_compiler.git

get_source: $(DIRS) musl-gcc

bootstrap: get_source
	sudo apt install -y make gcc g++ clang cmake python3 python-is-python3 scons m4 libgoogle-perftools-dev libpng-dev protobuf-compiler libuv1-dev

autopull_%:
	cd $* && git pull --rebase --autostash

pull_subrepos: $(addprefix autopull_,$(DIRS))

pull:
	git pull --rebase --autostash
	$(MAKE) pull_subrepos

build:
	cd hw_isol_gem5/mybuild && make build && cd ../..
	cd hfi_wasm2c_sandbox_compiler/mybuild && make build && cd ../..
	cd walkspec-hfi && make build

test-gem5:
	cd hw_isol_gem5/mybuild && make test

clean:
	cd hw_isol_gem5/mybuild && make clean

