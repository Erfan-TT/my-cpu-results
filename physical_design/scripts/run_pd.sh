#!/bin/bash
##  Place and route the DLX netlist, one Innovus run per netlist, each at the
##  period the netlist achieved in synthesis (syn/reports/results.csv).
##
##      ./run_pd.sh                      the shipped netlist, 1p0
##      PD_TAGS="1p0 1p2" ./run_pd.sh    other synthesis runs (syn/netlist/DLX_<tag>.v)
##      PD_UTIL=0.55 ./run_pd.sh         another core utilisation
##
##  Run folder: runs/pd_<tag>/ ; log: runs/pd_<tag>/innovus_run.log.
##  A run that already has its routed netlist is skipped.

cd "$(dirname "$0")"

tags=${PD_TAGS:-"1p0"}
csv=../syn/reports/results.csv

for tag in $tags; do
    run=runs/pd_$tag

    if [ -f $run/outputs/DLX_routed.v ]; then
        echo "$run: already done"
        continue
    fi
    if [ ! -f ../syn/netlist/DLX_$tag.v ]; then
        echo "$run: no netlist ../syn/netlist/DLX_$tag.v, skipped"
        continue
    fi

    ##  columns: tag,period_ns,achieved_ns,...
    achieved=$(tr -d '\r' < $csv | awk -F, -v t=$tag '$1 == t {print $3}')
    if [ -z "$achieved" ]; then
        echo "$run: $tag not in $csv, skipped"
        continue
    fi

    echo "$run: clock $achieved ns, started $(date +%H:%M)"
    mkdir -p $run

    ##  < /dev/null: if a command fails, Innovus exits instead of
    ##  waiting at its prompt
    ( cd $run &&
      PD_TAG=$tag PD_CLOCK=$achieved PD_BATCH=1 \
      innovus -nowin -files ../../scripts/innovus_script.tcl \
          < /dev/null > innovus_run.log 2>&1 )

    if [ -f $run/outputs/DLX_routed.v ]; then
        echo "$run: finished $(date +%H:%M)"
    else
        echo "$run: FAILED, see $run/innovus_run.log"
    fi
done
