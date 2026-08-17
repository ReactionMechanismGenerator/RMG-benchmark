#!/usr/bin/env bash

OUTFILE="benchmark_summary.csv"

# Write CSV header
echo "version,benchmark,nproc,run,iteration,core_species,core_reactions,edge_species,edge_reactions,exec_time_dd_hh_mm_ss,memory_mb" > "$OUTFILE"

find . -type f -name "RMG.log" | while read -r logfile; do
    version=$(echo "$logfile" | cut -d'/' -f2)
    rundir=$(basename "$(dirname "$logfile")")

    # Account for the new _runX directory format
    benchmark=$(echo "$rundir" | sed -E 's/_([0-9]+)proc.*//')
    nproc=$(echo "$rundir" | sed -E 's/.*_([0-9]+)proc.*/\1/')
    run=$(echo "$rundir" | sed -E 's/.*_run([0-9]+)/\1/')

    awk -v version="$version" \
        -v benchmark="$benchmark" \
        -v nproc="$nproc" \
        -v run="$run" '

    # capture most recent enlargement numbers using standard field iterations
    /After model enlargement:/ {
        getline
        for(i=1; i<=NF; i++) {
            if ($i == "species") core_species = $(i-1)
            if ($i == "reactions") core_rxns = $(i-1)
        }

        getline
        for(i=1; i<=NF; i++) {
            if ($i == "species") edge_species = $(i-1)
            if ($i == "reactions") edge_rxns = $(i-1)
        }
    }

    /Execution time/ {
        # Using [0-9][0-9] to avoid older awk strict POSIX interval limitations
        match($0, /[0-9][0-9]:[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/)
        if (RSTART > 0) exec_time = substr($0, RSTART, RLENGTH)
    }

    # this marks the end of an iteration
    /Memory used:/ {
        match($0, /[0-9]+\.[0-9]+/)
        if (RSTART > 0) mem = substr($0, RSTART, RLENGTH)

        iter++

        printf "%s,%s,%s,%s,%d,%s,%s,%s,%s,%s,%s\n", version, benchmark, nproc, run, iter, core_species, core_rxns, edge_species, edge_rxns, exec_time, mem
    }

    ' "$logfile" >> "$OUTFILE"

done
