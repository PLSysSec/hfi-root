#!/bin/bash

for c in boundschecks guardpage_asmmove hfiemulate2 hfi masking 
do
	awk '{print gensub("_.*","","g",FILENAME) "\t" $1}' *${c} > results_$c.out
done
