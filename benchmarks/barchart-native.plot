set terminal pdf enhanced size 3.5,2 

set key outside
set key above
set key font "Times New Roman,9"

set output 'output.pdf'

set style data histogram

set style histogram cluster gap 1
set style fill solid 1.00 border lt -1

set boxwidth 0.5

set xtics format ""
set xtics rotate by 60 right

set xtics font "Times New Roman,9"
set xtics scale 0

set ytics font "Times New Roman,6"
set ytics -60,20,140
set ytics format "%g%%"
set yrange [-45:80]

set ylabel "Overhead"
set ylabel font "Times New Roman,9"

set grid ytics lt 1 lw 0 lc rgb "#bbbbbb"
set arrow 50 from graph 0,0.36 to graph 1,0.36 nohead lc "#aa000000" back

plot \
     '< paste results_guardpage_asmmove.out results_boundschecks.out' using (100*$4/$2-100):xtic(1) title 'Bounds-checking' linecolor rgb "#D7191C" fill pattern 3, \
     '< paste results_guardpage_asmmove.out results_hfiemulate2.out' using (100*$4/$2-100):xtic(1) title 'HFI emulation' linecolor rgb "#2B83BA" fill pattern 3
