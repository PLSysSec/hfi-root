set terminal pdf enhanced size 5,2 

set key outside
set key above
set key font "Times New Roman,9"

set output 'output-gem5.pdf'

set style data histogram

set style histogram cluster gap 1
set style fill solid 1.00 border lc "#000000"

set boxwidth 0.8

set xtics format ""
set xtics rotate by 45 right

set xtics font "Times New Roman,9"
set xtics scale 0

set ytics font "Times New Roman,6"
set ytics -20,20,200
set ytics format "%g%%"
set yrange[-20:80]

set ylabel "Relative cycle count"
set ylabel font "Times New Roman,9"

set grid ytics lt 1 lw 0 lc rgb "#bbbbbb"
set arrow 50 from graph 0,0.2 to graph 1,0.2 nohead lc "#aa000000" back

plot \
     '< paste results_guardpage_asmmove.out results_hfi.out' using (100*$4/$2-100):xtic(1) title 'HFI' linecolor rgb "#ABDDA4" fill pattern 3, \
     '< paste results_guardpage_asmmove.out results_hfiemulate2.out' using (100*$4/$2-100):xtic(1) title 'HFI emulation' linecolor rgb "#2B83BA" fill pattern 3
