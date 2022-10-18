NOTPARALLEL:

.PHONY: build pull pull_subrepos test-gem5 clean

.DEFAULT_GOAL := build

SHELL := /bin/bash

CURR_USER=${USER}
CURR_PATH=${PATH}
CURR_TIME=$(shell date --iso=seconds)
PARALLEL_COUNT=$(shell nproc)
REPO_PATH=$(shell realpath .)

DIRS=hw_isol_gem5 hfi_wasm2c_sandbox_compiler hfi_misc hfi_firefox hfi-sightglass rust_libloading_aslr btbflush-module lucet-spectre hfi_spectre_webserver

hw_isol_gem5:
	git clone --recursive git@github.com:PLSysSec/hw_isol_gem5.git

hfi_wasm2c_sandbox_compiler:
	git clone --recursive git@github.com:PLSysSec/hfi_wasm2c_sandbox_compiler.git

hfi_misc:
	git clone --recursive git@github.com:PLSysSec/hfi_misc.git

hfi_firefox:
	git clone --recursive git@github.com:PLSysSec/hfi_firefox.git

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

wasi-sdk-14.0-linux.tar.gz:
	wget https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-14/wasi-sdk-14.0-linux.tar.gz

wasi-sdk: wasi-sdk-14.0-linux.tar.gz
	mkdir -p $@
	tar -zxf $< -C $@ --strip-components 1

node_modules:
	npm install autocannon

wrk:
	git clone https://github.com/wg/wrk

get_source: $(DIRS) wasi-sdk node_modules wrk

bootstrap: get_source
	sudo apt install -y make gcc g++ clang cmake python3 libpng-dev libuv1-dev \
		build-essential git m4 scons zlib1g zlib1g-dev \
		libprotobuf-dev protobuf-compiler libprotoc-dev libgoogle-perftools-dev \
		python3-dev python-is-python3 python3-pip libboost-all-dev pkg-config \
		cpuset cpufrequtils xvfb gnuplot npm \
		ca-certificates curl gnupg lsb-release libssl-dev
	cd hfi_firefox/mybuild && make bootstrap
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

build_firefox:
	cd hfi_firefox/mybuild && make build

build: build_gem5 build_wasm2c build_sightglass build_faas build_firefox

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

testmode_benchmark_graphite:
	cd hfi_firefox && ./testsRunBenchmark "../benchmarks/graphite_test_$(CURR_TIME)" "graphite_perf_test"

benchmark_graphite: benchmark_env_setup
	export DISPLAY=:99 && make testmode_benchmark_graphite

# cd hfi_firefox && ./testsRunBenchmark "../benchmarks/jpeg_black_width_test_$(CURR_TIME)" "jpeg_black_width_perf"

testmode_benchmark_jpeg:
	cd hfi_firefox && ./testsRunBenchmark "../benchmarks/jpeg_test_$(CURR_TIME)" "jpeg_perf"
	./hfi_firefox/testsProduceImagePlotData.py ./benchmarks/jpeg_test_$(CURR_TIME)/compare_stock_terminal_analysis.json.dat ./benchmarks/jpeg_test_$(CURR_TIME)/jpeg_perf.plotdat
	gnuplot -e "inputfilename='./benchmarks/jpeg_test_$(CURR_TIME)/jpeg_perf.plotdat';outputfilename='./benchmarks/jpeg_test_$(CURR_TIME)/jpeg_perf.pdf'" ./hfi_firefox/testsProduceImagePlot.gnu

benchmark_jpeg: benchmark_env_setup
	export DISPLAY=:99 && make testmode_benchmark_jpeg

SIGHTGLASS_OUTPUTFOLDER="$(REPO_PATH)/benchmarks/sightglass_emulated_$(CURR_TIME)/"

testmode_benchmark_sightglass_emulated:
	mkdir -p "$(SIGHTGLASS_OUTPUTFOLDER)" && \
		export SIGHTGLASS_OUTPUTFOLDER="$(SIGHTGLASS_OUTPUTFOLDER)" && \
		export SIGHTGLASS_WRITEOUTPUT=1 && \
		cd hfi-sightglass/mybuild && \
		make run_guardpage && \
		make run_guardpage_asmmove && \
		make run_hfiemulate && \
		make run_hfiemulate2

benchmark_benchmark_sightglass_emulated: benchmark_env_setup
	make testmode_benchmark_benchmark_sightglass_emulated

install_btbflush: btbflush-module
	# make -C does not work below
	if [ -z "$(shell lsmod | grep "cool")" ]; then  \
		echo "Installing BTB flush module" && \
		cd ./btbflush-module/module && make clean && make && make insert; \
	fi

testmode_benchmark_faas: install_btbflush
	rm -rf ./hfi_spectre_webserver/wrk_scripts/results
	cd ./hfi_spectre_webserver/wrk_scripts && ./runall.sh

testmode_benchmark_faas_finish:
	python3 ./hfi_spectre_webserver/wrk_analysis.py -folders ./hfi_spectre_webserver/wrk_scripts/results -sofolder ./hfi_spectre_webserver/modules -o1 ./hfi_spectre_webserver/wrk_scripts/results/wrk_table_1.tex -o2 ./hfi_spectre_webserver/wrk_scripts/results/wrk_table_2.tex -o3 ./hfi_spectre_webserver/wrk_scripts/results/metrics.txt
	mv ./hfi_spectre_webserver/wrk_scripts/results ./benchmarks/faas_$(CURR_TIME)

benchmark_benchmark_faas: benchmark_env_setup
	make testmode_benchmark_benchmark_faas

#### Keep Spec stuff separate so we can easily release other artifacts
# SPEC_BUILDS=wasm_hfi_wasm2c_hfiemulate2 wasm_hfi_wasm2c_hfiemulate
SPEC_BUILDS=wasm_hfi_wasm2c_guardpages wasm_hfi_wasm2c_boundschecks wasm_hfi_wasm2c_masking wasm_hfi_wasm2c_hfiemulate2 wasm_hfi_wasm2c_hfiemulate

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

testmode_benchmark_spec:
	cd hfi_spec && source shrc && cd config && \
	for spec_build in $(SPEC_BUILDS); do \
		runspec --config=$$spec_build.cfg --action=run --define cores=1 --iterations=1 --noreportable --size=ref wasmint; \
	done
	python3 spec_stats.py -i hfi_spec/result --filter  \
		"hfi_spec/result/spec_results=hfi_wasm2c_boundschecks:BoundsChecks,hfi_wasm2c_masking:Masking,hfi_wasm2c_hfiemulate:HfiEmulateLB,hfi_wasm2c_hfiemulate2:HfiEmulateUB" -n $(words $(SPEC_BUILDS)) --usePercent
	mv hfi_spec/result/ benchmarks/spec_$(CURR_TIME)

benchmark_spec: benchmark_env_setup
	make testmode_benchmark_spec

clean:
	cd hw_isol_gem5/mybuild && make clean
	cd hfi_wasm2c_sandbox_compiler/mybuild && make clean
	cd hfi_firefox/mybuild && make clean
