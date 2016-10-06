#!/bin/sh
set -f
plot=
for file in "$@"; do
	test $# -gt 1 && : $((i+=1))
	title="${title:+$title, }${file%.*}"
	plot="${plot:+$plot,} \
'$file' using 'time[s]':'max(recloads)' title '${i:+$i: }load (abs)' w lines, \
'' using 'time[s]':'max(loads)' title '${i:+$i: }load (rel)' w lines, \
'' using 'time[s]':'max(freqs)[MHz]' title '${i:+$i: }clock freq' w steps axis x1y2"
done
gnuplot << CMDS
set title '$title'
set xlabel "time[s]"
set ylabel "load"
set y2label "freq[MHz]"
set ytics nomirror
set y2tics
set y2range [0:]
set grid
set terminal svg size 800,450
plot $plot
CMDS
