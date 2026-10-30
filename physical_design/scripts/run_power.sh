#!/bin/bash
##  Post-layout power of every verified SAIF of sim/sim_postlayout.do.
##
##  results/sim/saif_manifest.csv lists them:
##      tag,workload,saif_path,sim_period_ns,constraint_ns,cycles,window_cycles
##  and each becomes one Innovus run in runs/<tag>/, which writes
##  reports/12_power_<workload>.rpt.  Reports already there are skipped.

cd "$(dirname "$0")"

manifest=results/sim/saif_manifest.csv
if [ ! -f $manifest ]; then
    echo "no $manifest: run sim/sim_postlayout.do first"
    exit 1
fi

tail -n +2 $manifest | tr -d '\r' |
while IFS=, read tag workload saif period constraint cycles window; do
    run=runs/$tag
    if [ -f $run/reports/12_power_$workload.rpt ]; then
        echo "$run / $workload: already done"
        continue
    fi
    if [ ! -d $run/dbs/10_final.enc.dat ]; then
        echo "$run / $workload: no saved design dbs/10_final.enc, skipped"
        continue
    fi

    echo "$run / $workload: power at $period ns"
    ( cd $run &&
      PD_WORKLOAD=$workload PD_SAIF=$saif PD_SIM_PERIOD=$period \
      innovus -nowin -files ../../scripts/power_postlayout.tcl \
          < /dev/null > power_$workload.log 2>&1 )
    [ -f $run/reports/12_power_$workload.rpt ] || echo "    FAILED, see $run/power_$workload.log"
done
