#!/bin/bash

for c in guardpage boundschecks guardpage_asmmove hfiemulate2 hfi masking segment
do
	awk '{
	f = gensub("shootout-","","g",FILENAME)
	print gensub("_.*","","g",f) "\t" $1
}' *${c} > results_$c.out 2>/dev/null
done

exit 0
