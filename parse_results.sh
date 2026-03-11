#!/usr/bin/env bash

OUTFILE="benchmark_summary.csv"

echo "version,benchmark,nproc,iteration,core_species,core_reactions,edge_species,edge_reactions,exec_time_dd_hh_mm_ss,memory_mb" > "$OUTFILE"

find . -type f -name "RMG.log" | while read -r logfile; do
    version=$(echo "$logfile" | cut -d'/' -f2)
    run=$(basename "$(dirname "$logfile")")

    benchmark=${run%_*proc}
    nproc=$(echo "$run" | sed -E 's/.*_([0-9]+)proc/\1/')

    awk -v version="$version" \
        -v benchmark="$benchmark" \
        -v nproc="$nproc" '

    # capture most recent enlargement numbers
    /After model enlargement:/ {
        getline
        match($0, /has ([0-9]+) species and ([0-9]+) reactions/, a)
        core_species=a[1]
        core_rxns=a[2]

        getline
        match($0, /has ([0-9]+) species and ([0-9]+) reactions/, a)
        edge_species=a[1]
        edge_rxns=a[2]
    }

    /Execution time/ {
        match($0, /([0-9]{2}:[0-9]{2}:[0-9]{2}:[0-9]{2})/, a)
        exec_time=a[1]
    }

    # this marks the end of an iteration
    /Memory used:/ {
        match($0, /([0-9]+\.[0-9]+)/, a)
        mem=a[1]

        iter++

        printf "%s,%s,%s,%d,%s,%s,%s,%s,%s,%s\n", \
            version, benchmark, nproc, iter, \
            core_species, core_rxns, \
            edge_species, edge_rxns, \
            exec_time, mem
    }

    ' "$logfile" >> "$OUTFILE"

done
