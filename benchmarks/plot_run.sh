#!/bin/bash

if [ $# != 1 ]; then
	echo "usage: ./plot_run.sh <results_directory>"
	exit 1
fi

RESULTS=$(realpath $1)

if [ ! -d "$RESULTS" ]; then
	echo "$RESULTS does not exist"
	exit 1
fi

cd $RESULTS
# assume that results are in hfi-root/benchmarks/
../make_results_files.sh
if [[ $RESULTS == *"simulate"* ]]; then
	gnuplot ../barchart-gem5.plot
	pdfcrop $RESULTS/output-gem5.pdf $RESULTS/output-gem5.pdf
elif [[ $RESULTS == *"emulate"* ]]; then
	gnuplot ../barchart-native.plot
	pdfcrop $RESULTS/output.pdf $RESULTS/output.pdf
else
	echo "Results directory doesn't have 'simulate' or 'emulate' in name; not sure which script to use."
	echo "cd into $RESULTS and run gnuplot with the appropriate barchart-*.plot."
	exit 1
fi

