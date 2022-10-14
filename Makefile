NOTPARALLEL:

.PHONY: build pull pull_subrepos test-gem5 clean

.DEFAULT_GOAL := build

SHELL := /bin/bash

DIRS=hw_isol_gem5 hfi_wasm2c_sandbox_compiler hfi_misc hfi_firefox

hw_isol_gem5:
	git clone --recursive git@github.com:PLSysSec/hw_isol_gem5.git

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
		python3-dev python-is-python3 python3-pip libboost-all-dev pkg-config \
		cpuset cpufrequtils xvfb
	cd hfi_firefox/mybuild && make bootstrap

autopull_%:
	cd $* && git pull --rebase --autostash

pull_subrepos: $(addprefix autopull_,$(DIRS))

pull:
	git pull --rebase --autostash
	$(MAKE) pull_subrepos

build_gem5:
	cd hw_isol_gem5/mybuild && make build

build_wasm2c:
	cd hfi_wasm2c_sandbox_compiler/mybuild && make build

build_firefox:
	cd hfi_firefox/mybuild && make build

build: build_gem5 build_wasm2c build_firefox

test-gem5:
	cd hw_isol_gem5/mybuild && make test

run_xvfb:
	if [ -z "$(shell pgrep Xvfb)" ]; then \
		Xvfb :99 & \
	fi

shielding_on: run_xvfb
	sudo cset shield -c 1 -k on
	sudo cset shield -e sudo -- -u ${CURR_USER} env "PATH=${CURR_PATH}" bash

shielding_off:
	sudo cset shield --reset

disable_hyperthreading:
	sudo bash -c "echo off > /sys/devices/system/cpu/smt/control"

restore_hyperthreading:
	sudo bash -c "echo on > /sys/devices/system/cpu/smt/control"

benchmark_env_setup: disable_hyperthreading
	sudo cset shield -c 1 -k on
	(taskset -c 1 echo "testing shield..." > /dev/null 2>&1 && echo "Shielded shell running!") || (echo "Shielded shell not running. Run make shielding_on first!" && sudo cset shield --reset && exit 1)
	if [ -x "$(shell command -v cpupower)" ]; then \
		sudo cpupower -c 1 frequency-set -g performance && sudo cpupower -c 1 frequency-set --min 2200MHz --max 2200MHz; \
	else \
		sudo cpufreq-set -c 1 -g performance && sudo cpufreq-set -c 1 --min 2200MHz --max 2200MHz; \
	fi

benchmark_env_close: restore_hyperthreading shielding_off

testmode_benchmark_graphite:
	cd hfi_firefox && ./testsRunBenchmark "../benchmarks/graphite_test_$(shell date --iso=seconds)" "graphite_perf_test"

benchmark_graphite: benchmark_env_setup
	export DISPLAY=:99 && make testmode_benchmark_graphite

testmode_benchmark_jpeg:
	cd hfi_firefox && ./testsRunBenchmark "../benchmarks/jpeg_test_$(shell date --iso=seconds)" "jpeg_perf"
	cd hfi_firefox && ./testsRunBenchmark "../benchmarks/jpeg_black_width_test_$(shell date --iso=seconds)" "jpeg_black_width_perf"

benchmark_jpeg: benchmark_env_setup
	export DISPLAY=:99 && make testmode_benchmark_jpeg


#### Keep Spec stuff separate so we can easily release other artifacts
SPEC_BUILDS=wasm_hfi_wasm2c_guardpages wasm_hfi_wasm2c_boundschecks wasm_hfi_wasm2c_masking wasm_hfi_wasm2c_hfiemulate wasm_hfi_wasm2c_hfiemulate2

hfi_spec:
	git clone --recursive git@github.com:PLSysSec/hfi_spec.git
	cd $@ && SPEC_INSTALL_NOCHECK=1 SPEC_FORCE_INSTALL=1 sh install.sh -f

build_spec: hfi_spec autopull_hfi_spec
	cd hfi_spec && source shrc &&  cd config && \
	for spec_build in $(SPEC_BUILDS); do \
		runspec --config=$$spec_build.cfg --action=build --define cores=1 --iterations=1 --noreportable --size=ref all_c_cpp; \
	done

testmode_benchmark_spec:
	cd hfi_spec && source shrc && cd config && \
	for spec_build in $(SPEC_BUILDS); do \
		runspec --config=$$spec_build.cfg --action=run --define cores=1 --iterations=1 --noreportable --size=ref all_c_cpp; \
	done
	python3 spec_stats.py -i hfi_spec/result --filter  \
		"hfi_spec/result/spec_results=wasm_hfi_wasm2c_guardpages:GuardPages,wasm_hfi_wasm2c_boundschecks:BoundsChecks,wasm_hfi_wasm2c_masking:Masking,wasm_hfi_wasm2c_hfiemulate:HfiEmulateLB,wasm_hfi_wasm2c_hfiemulate2:HfiEmulateUB" -n 5 --usePercent
	mv hfi_spec/result/ benchmarks/spec_$(shell date --iso=seconds)

benchmark_spec: benchmark_env_setup
	export DISPLAY=:99 && make testmode_benchmark_spec

clean:
	cd hw_isol_gem5/mybuild && make clean
	cd hfi_wasm2c_sandbox_compiler/mybuild && make clean
	cd hfi_firefox/mybuild && make clean
