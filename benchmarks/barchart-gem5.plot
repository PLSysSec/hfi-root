set terminal pdf enhanced size 3.5,2

set key outside
set key above
set key font "Times New Roman,9"

set output 'output-gem5.pdf'

set style data histogram

set style histogram cluster gap 1
set style fill solid 1.00 border lc "#000000"

set boxwidth 0.5

set xtics format ""
set xtics rotate by 60 right

set xtics font "Times New Roman,9"
set xtics scale 0

set ytics font "Times New Roman,9"
set ytics 0,20,140
set ytics format "%g%%"
set yrange[00:140]

set ylabel "Norm. runtime"
set ylabel font "Times New Roman,9"

set grid ytics lt 1 lw 0 lc rgb "#bbbbbb"
#set arrow 50 from graph 0,0.33333 to graph 1,0.33333 nohead lc "#aa000000" back

plot \
     '< paste results_hfi.out results_hfi.out' using (100):xtic(1) title 'HFI' linecolor rgb '#ABDDA4' fill pattern 3, \
     '< paste results_hfi.out results_hfiemulate2.out' using (100*$4/$2):xtic(1) title 'HFI emulation' linecolor rgb "#2B83BA" fill pattern 3
