NOTPARALLEL:

.PHONY: build pull pull_subrepos test-gem5 clean

.DEFAULT_GOAL := build

SHELL := /bin/bash

CURR_USER=${USER}
CURR_PATH=${PATH}
CURR_TIME=$(shell date --iso=seconds)
PARALLEL_COUNT=$(shell nproc)
REPO_PATH=$(shell realpath .)

DIRS=hw_isol_gem5 hfi_wasm2c_sandbox_compiler hfi_misc rlbox_hfi_wasm2c_sandbox hfi_firefox hfi-sightglass rust_libloading_aslr btbflush-module lucet-spectre hfi_spectre_webserver hfi-nginx

hw_isol_gem5:
	git clone --recursive git@github.com:PLSysSec/hw_isol_gem5.git

hfi_wasm2c_sandbox_compiler:
	git clone --recursive git@github.com:PLSysSec/hfi_wasm2c_sandbox_compiler.git

hfi_misc:
	git clone --recursive git@github.com:PLSysSec/hfi_misc.git

rlbox_hfi_wasm2c_sandbox:
	git clone --recursive git@github.com:PLSysSec/rlbox_hfi_wasm2c_sandbox

hfi_firefox:
	git clone --recursive git@github.com:PLSysSec/hfi_firefox.git

sightglass:
	git clone https://github.com/bytecodealliance/sightglass
	cd sightglass && git checkout -b working 1ab26cdaca913a38c53d8db5808fc5bf0fdb23f5


hfi-sightglass:
	git clone --recursive git@github.com:PLSysSec/hfi-sightglass

rust_libloading_aslr:
	git clone git@github.com:PLSysSec/rust_libloading_aslr.git

btbflush-module:
	git clone git@github.com:PLSysSec/btbflush-module.git

lucet-spectre:
	git clone --recursive git@github.com:PLSysSec/lucet-spectre

hfi_spectre_webserver:
	git clone --recursive git@github.com:PLSysSec/hfi_spectre_webserver.git

hfi-nginx:
	git clone --recursive git@github.com:PLSysSec/hfi-nginx.git

wasi-sdk-14.0-linux.tar.gz:
	wget https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-14/wasi-sdk-14.0-linux.tar.gz

wasi-sdk: wasi-sdk-14.0-linux.tar.gz
	mkdir -p $@
	tar -zxf $< -C $@ --strip-components 1

node_modules:
	npm install autocannon

wrk:
	git clone https://github.com/wg/wrk

get_source: $(DIRS) sightglass wasi-sdk node_modules wrk

bootstrap: get_source
	sudo apt install -y make gcc g++ clang cmake python3 libpng-dev libuv1-dev \
		build-essential git m4 scons zlib1g zlib1g-dev \
		libprotobuf-dev protobuf-compiler libprotoc-dev libgoogle-perftools-dev \
		python3-dev python-is-python3 python3-pip libboost-all-dev pkg-config \
		cpuset cpufrequtils xvfb gnuplot npm \
		ca-certificates curl gnupg lsb-release libssl-dev \
		apache2-utils jq libseccomp-dev gawk
	cd hfi_firefox/mybuild && make bootstrap
	wget https://github.com/sharkdp/hyperfine/releases/download/v1.15.0/hyperfine_1.15.0_amd64.deb
	sudo dpkg -i hyperfine_1.15.0_amd64.deb
	pip3 install simplejson matplotlib
	pip3 install --upgrade requests
	npm install autocannon

# Only needed if you need to rebuild sightglass wasm files
install_docker:
	sudo mkdir -p /etc/apt/keyrings
 	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	echo \
	"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
		$(shell lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
	sudo service docker start
	sudo usermod -a -G docker ${CURR_USER}
	@echo "--------------------------------------------------------------------------"
	@echo "Attention!!!!!!:"
	@echo ""
	@echo "Installed new packages, docker etc."
	@echo "You need to reboot before proceeding."
	@echo ""
	@echo "--------------------------------------------------------------------------"

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

build_sightglass:
	cd hfi-sightglass/mybuild && make -j$(PARALLEL_COUNT) build

build_faas:
	cd wrk && $(MAKE) -j$(PARALLEL_COUNT)
	cd lucet-spectre && cargo build --release
	cd hfi_spectre_webserver && cargo build --release
	cd hfi_spectre_webserver/modules && make clean && make -j$(PARALLEL_COUNT)

build_nginx:
	cd hfi-nginx/bench/webserver && ./build.sh

build_firefox:
	cd hfi_firefox/mybuild && make build

build_wasmtime_%:
	export REPOSITORY="git@github.com:PLSysSec/hfi-wasmtime.git" && \
		export REVISION="$*" && \
		export BUILD_DIR="$(REPO_PATH)/wasmtime-builds/$*" && \
		mkdir -p $$BUILD_DIR && \
		cd sightglass/engines/wasmtime && rustc build.rs && ./build
	cd wasmtime-builds/$* && cargo build --release

# build_wasmtime_hfi-grow-without-mprotect-lfence
build_wasmtime: build_wasmtime_hfi-baseline build_wasmtime_hfi-grow-without-mprotect build_wasmtime_hfi-grow-without-mprotect-baseline build_wasmtime_hfi-baseline-instantiation build_wasmtime_hfi-reg-pressure build_wasmtime_hfi-reg-pressure2
	cd wasmtime-builds/hfi-grow-without-mprotect/growth_bench && cargo build --release
	cd wasmtime-builds/hfi-grow-without-mprotect-baseline/growth_bench && cargo build --release
	cd sightglass && cargo build --release

build_misc:
	cd hfi_misc && make -j$(PARALLEL_COUNT) build

build: build_gem5 build_wasm2c build_sightglass build_faas build_nginx build_firefox build_wasmtime build_misc

test-gem5:
	cd hw_isol_gem5/mybuild && make test

run_xvfb:
	if [ -z "$(shell pgrep Xvfb)" ]; then \
		Xvfb :99 & \
	fi

shielded_shell: run_xvfb
	sudo cset shield -c 1 -k on
	sudo cset shield -e sudo -- -u ${CURR_USER} env "PATH=${CURR_PATH}" bash

shielding_off:
	sudo cset shield --reset

disable_hyperthreading:
	sudo bash -c "echo off > /sys/devices/system/cpu/smt/control"

restore_hyperthreading:
	sudo bash -c "echo on > /sys/devices/system/cpu/smt/control"

disable_cpufreq:
	sudo cpufreq-set -c 1 -g performance
	sudo cpufreq-set -c 1 --min 2200MHz --max 2200MHz

restore_cpufreq:
	POLICYINFO=($$(cpufreq-info -c 0 -p)) && \
	sudo cpufreq-set -c 1 -g $${POLICYINFO[2]} && \
	sudo cpufreq-set -c 1 --min $${POLICYINFO[0]}MHz --max $${POLICYINFO[1]}MHz

benchmark_env_setup: disable_hyperthreading disable_cpufreq
	sudo cset shield -c 1 -k on
	(taskset -c 1 echo "testing shielded shell..." > /dev/null 2>&1 && echo "Shielded shell running!") || (echo "Not running in shielded shell. Run make shielded_shell first!" && sudo cset shield --reset && exit 1)

benchmark_env_close: restore_hyperthreading shielding_off restore_cpufreq

benchmark_graphite:
	export DISPLAY=:99 && cd hfi_firefox && ./testsRunBenchmark "../benchmarks/graphite_test_$(CURR_TIME)" "graphite_perf_test"

# cd hfi_firefox && ./testsRunBenchmark "../benchmarks/jpeg_black_width_test_$(CURR_TIME)" "jpeg_black_width_perf"

benchmark_jpeg:
	export DISPLAY=:99 && cd hfi_firefox && ./testsRunBenchmark "../benchmarks/jpeg_test_$(CURR_TIME)" "jpeg_perf"
	./hfi_firefox/testsProduceImagePlotData.py ./benchmarks/jpeg_test_$(CURR_TIME)/compare_stock_terminal_analysis.json.dat ./benchmarks/jpeg_test_$(CURR_TIME)/jpeg_perf.plotdat
	gnuplot -e "inputfilename='./benchmarks/jpeg_test_$(CURR_TIME)/jpeg_perf.plotdat';outputfilename='./benchmarks/jpeg_test_$(CURR_TIME)/jpeg_perf.pdf'" ./hfi_firefox/testsProduceImagePlot.gnu

SIGHTGLASS_OUTPUTFOLDER="$(REPO_PATH)/benchmarks/sightglass_emulated_$(CURR_TIME)/"

benchmark_sightglass_emulated:
	mkdir -p "$(SIGHTGLASS_OUTPUTFOLDER)" && \
		export SIGHTGLASS_OUTPUTFOLDER="$(SIGHTGLASS_OUTPUTFOLDER)" && \
		cd hfi-sightglass/mybuild && \
		make run_guardpage_asmmove && \
		make run_boundschecks && \
		make run_masking && \
		make run_hfiemulate2
	./benchmarks/plot_run.sh $(SIGHTGLASS_OUTPUTFOLDER)

install_btbflush: btbflush-module
	# make -C does not work below
	if [ -z "$(shell lsmod | grep "cool")" ]; then  \
		echo "Installing BTB flush module" && \
		cd ./btbflush-module/module && make clean && make && make insert; \
	fi

benchmark_faas: install_btbflush
	rm -rf ./hfi_spectre_webserver/wrk_scripts/results
	cd ./hfi_spectre_webserver/wrk_scripts && ./runall.sh

benchmark_faas_finish:
	python3 ./hfi_spectre_webserver/wrk_analysis.py -folders ./hfi_spectre_webserver/wrk_scripts/results -sofolder ./hfi_spectre_webserver/modules -o1 ./hfi_spectre_webserver/wrk_scripts/results/wrk_table_1.tex -o2 ./hfi_spectre_webserver/wrk_scripts/results/wrk_table_2.tex -o3 ./hfi_spectre_webserver/wrk_scripts/results/metrics.txt
	mv ./hfi_spectre_webserver/wrk_scripts/results ./benchmarks/faas_$(CURR_TIME)

benchmark_nginx:
	cd hfi-nginx/bench/webserver/ && ./simple_bench.sh 60
	cd hfi-nginx/bench/webserver/ && ./draw.py
	mkdir -p ./benchmarks/nginx_$(CURR_TIME)
	mv hfi-nginx/bench/webserver/*.log ./benchmarks/nginx_$(CURR_TIME)/
	mv hfi-nginx/bench/webserver/nginx.png ./benchmarks/nginx_$(CURR_TIME)/nginx.png

benchmark_wasmtime_regpressure:
	# cp wasmtime-builds/hfi-baseline/target/release/libwasmtime_bench_api.so hfi-sightglass/engines/wasmtime/libengine.so
	# cp wasmtime-builds/hfi-baseline/.build-info hfi-sightglass/engines/wasmtime/.build-info
	cd sightglass && cargo run --release -- benchmark \
		--engine $(REPO_PATH)/wasmtime-builds/hfi-baseline/target/release/libwasmtime_bench_api.so \
		--engine $(REPO_PATH)/wasmtime-builds/hfi-reg-pressure/target/release/libwasmtime_bench_api.so \
		--engine $(REPO_PATH)/wasmtime-builds/hfi-reg-pressure2/target/release/libwasmtime_bench_api.so \
		-- benchmarks/spidermonkey/benchmark.wasm | tee $(REPO_PATH)/benchmarks/wasmtime_regpressure_$(CURR_TIME).txt

WASMTIME_MPROTECT_OUTPUTFOLDER="$(REPO_PATH)/benchmarks/wasmtime_mprotect_$(CURR_TIME)/"

benchmark_wasmtime_mprotect:
	mkdir -p $(WASMTIME_MPROTECT_OUTPUTFOLDER)
	hyperfine --warmup 1 -m 5 --export-json "$(WASMTIME_MPROTECT_OUTPUTFOLDER)/mprotect.json" \
		"cd $(REPO_PATH)/wasmtime-builds/hfi-grow-without-mprotect-baseline/growth_bench && ../target/release/growth_bench" \
		"cd $(REPO_PATH)/wasmtime-builds/hfi-grow-without-mprotect/growth_bench && ../target/release/growth_bench"

	# ~/Code/HardwareIsolation/wasmtime-builds/hfi-grow-without-mprotect/growth_bench$ ../target/release/growth_bench
	# cd sightglass && cargo run --release -- benchmark \
	# 	--engine $(REPO_PATH)/wasmtime-builds/hfi-grow-without-mprotect-baseline/target/release/libwasmtime_bench_api.so \
	# 	--engine $(REPO_PATH)/wasmtime-builds/hfi-grow-without-mprotect/target/release/libwasmtime_bench_api.so \
	# 	-- benchmarks/spidermonkey/benchmark.wasm | tee $(REPO_PATH)/benchmarks/wasmtime_mprotect_$(CURR_TIME).txt

WASM2C_MPROTECT_OUTPUTFOLDER="$(REPO_PATH)/benchmarks/wasm2c_mprotect_$(CURR_TIME)/"

benchmark_wasm2c_mprotect:
	mkdir -p "$(WASM2C_MPROTECT_OUTPUTFOLDER)" && \
		export BENCH_OUTPUTFOLDER="$(WASM2C_MPROTECT_OUTPUTFOLDER)" && \
		cd hfi_misc && make benchmark_mprotect

SYSCALL_OUTPUTFOLDER="$(REPO_PATH)/benchmarks/syscall_$(CURR_TIME)/"

benchmark_syscall:
	mkdir -p "$(SYSCALL_OUTPUTFOLDER)" && \
		export BENCH_OUTPUTFOLDER="$(SYSCALL_OUTPUTFOLDER)" && \
		cd hfi_misc && make benchmark_syscall

benchmark_wasmtime_instantiation:
	cd ./wasmtime-builds/hfi-baseline-instantiation/ && \
	RAYON_NUM_THREADS=1 cargo bench --bench instantiation | tee "$(REPO_PATH)/benchmarks/wasmtime_instantiation_$(CURR_TIME).txt"

#### Keep Spec stuff separate so we can easily release other artifacts
SPEC_BUILDS=wasm_hfi_wasm2c_hfiemulate2 wasm_hfi_wasm2c_guardpages wasm_hfi_wasm2c_boundschecks # wasm_hfi_wasm2c_masking

hfi_spec:
	git clone --recursive git@github.com:PLSysSec/hfi_spec.git
	cd $@ && SPEC_INSTALL_NOCHECK=1 SPEC_FORCE_INSTALL=1 sh install.sh -f

build_wasm2c_dependency:
	cd hfi_wasm2c_sandbox_compiler/mybuild && make ../build_release_guardpages
	cd hfi_wasm2c_sandbox_compiler/build_release_guardpages && make -j$(PARALLEL_COUNT)

build_spec: hfi_spec autopull_hfi_spec build_wasm2c_dependency
	cd hfi_spec && source shrc &&  cd config && \
	echo "Cleaning dirs..." && \
	for spec_build in $(SPEC_BUILDS); do \
		runspec --config=$$spec_build.cfg --action=clobber --define cores=1 --iterations=1 --noreportable --size=ref wasmint 2&>1 > /dev/null; \
	done && \
	for spec_build in $(SPEC_BUILDS); do \
		echo "Building $$spec_build"; \
		runspec --config=$$spec_build.cfg --action=build --define cores=1 --iterations=1 --noreportable --size=ref wasmint | grep "Build "; \
	done

run_spec_graph:
	cd $(REPO_PATH)/benchmarks/spec_2022-10-19T03:57:08-04:00 && \
	python3 $(REPO_PATH)/spec_stats.py -i ./ --filter  \
		"./spec_results=hfi_wasm2c_guardpages:Guard pages,hfi_wasm2c_boundschecks:Bounds checks,hfi_wasm2c_hfiemulate2:HFI emulation" -n 4 --usePercent

benchmark_spec:
	cd hfi_spec && source shrc && cd config && \
	for spec_build in $(SPEC_BUILDS); do \
		runspec --config=$$spec_build.cfg --action=run --define cores=1 --iterations=1 --noreportable --size=ref wasmint; \
	done
	python3 spec_stats.py -i hfi_spec/result --filter  \
		"hfi_spec/result/spec_results=hfi_wasm2c_boundschecks:BoundsChecks,hfi_wasm2c_hfiemulate2:HfiEmulation" -n $(words $(SPEC_BUILDS)) --usePercent
	mv hfi_spec/result/ benchmarks/spec_$(CURR_TIME)

clean:
	cd hw_isol_gem5/mybuild && make clean
	cd hfi_wasm2c_sandbox_compiler/mybuild && make clean
	cd hfi_firefox/mybuild && make clean
