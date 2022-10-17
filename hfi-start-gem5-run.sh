#!/bin/bash
if [ $# -ne 1 ]; then
    echo "usage: ./hfi-start-run.sh <mode>, where mode is guardpage_asmmove, hfi, or hfiemulate2"
    exit 1
fi
if [ "$1" != "guardpage_asmmove" ] && [ "$1" != "hfi" ] && [ "$1" != "hfiemulate2" ]; then
    echo "usage: ./hfi-start-run.sh <mode>, where mode is guardpage_asmmove, hfi, or hfiemulate2"
    exit 1
fi
MODE=$1

# this file's location is hfi-root
HFIROOT=$(dirname $(realpath -s $0))
GEM5DIR=${HFIROOT}/hw_isol_gem5
BMKSDIR=${HFIROOT}/benchmarks/sightglass_${MODE}_$(date +%b%d-%H:%M)

mkdir -p $BMKSDIR

# assume that the user ran `make bootstrap` already and that everything is built

# goal: build bmks and construct a command which will run each benchmark in parallel thru gem5
BMKS=$(cat $HFIROOT/hfi-sightglass/mybuild/SightglassBench.inc)
BMKS_ARR=($BMKS)
bmk=${BMKS_ARR[0]}  # one extra benchmark, since the assignment to run_bmks_cmd is different at first
unset BMKS_ARR[0]
BMKS=$(echo ${BMKS_ARR[@]})

# for each benchmark, build only the correct config
cd ${HFIROOT}/hfi-sightglass/mybuild
NOTIMED=1 CC=clang make ${bmk}_build_${MODE} -j21
gem5_run_cmd="${GEM5DIR}/build/X86/gem5.fast --outdir=${BMKSDIR}/${bmk}_gem5 ${GEM5DIR}/configs/example/se.py --cpu-type=Skylake --caches -c ./benchmark_${MODE}"
run_bmks_cmd="(cd ${bmk} && ${gem5_run_cmd} && cd ..)"

for bmk in $BMKS; 
do
    NOTIMED=1 CC=clang make ${bmk}_build_${MODE} -j21
    gem5_run_cmd="${GEM5DIR}/build/X86/gem5.fast --outdir=${BMKSDIR}/${bmk}_gem5 ${GEM5DIR}/configs/example/se.py --cpu-type=Skylake --caches -c ./benchmark_${MODE}"
    run_bmks_cmd="${run_bmks_cmd} & (cd ${bmk} && ${gem5_run_cmd} && cd ..)"
done

# finally, run the command
cd ../benchmarks

eval $run_bmks_cmd

