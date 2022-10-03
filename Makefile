NOTPARALLEL:

.PHONY: build pull pull_subrepos clean

.DEFAULT_GOAL := build

SHELL := /bin/bash

DIRS=hw_isol_gem5

x86_64-linux-musl-native.tgz:
	wget https://musl.cc/x86_64-linux-musl-native.tgz

musl-gcc: x86_64-linux-musl-native.tgz
	mkdir -p $@
	tar -zxf x86_64-linux-musl-native.tgz -C $@ --strip-components 1

hw_isol_gem5:
	git clone git@github.com:PLSysSec/hw_isol_gem5.git

get_source: $(DIRS)

bootstrap: get_source
	sudo apt install -y make gcc g++ clang cmake python3 python-is-python3 scons m4 libgoogle-perftools-dev libpng-dev protobuf-compiler

autopull_%:
	cd $* && git pull --rebase --autostash

pull_subrepos: $(addprefix autopull_,$(DIRS))

pull:
	git pull --rebase --autostash
	$(MAKE) -C pull_subrepos

build:
	cd hw_isol_gem5/mybuild && make build

clean:
	cd hw_isol_gem5/mybuild && make clean

