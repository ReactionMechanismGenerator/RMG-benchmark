OUTDIR="rmgpy_output_$(date +'%Y%m%d_%H%M%S')"
mkdir -p "$OUTDIR"

CSVFILE="$OUTDIR/results.csv"
touch "$CSVFILE"

# Write CSV header
echo "version,case,processes,execution_time_s,execution_time_mmss,peak_rss_mib,min_memavailable_mib,peak_ram_pressure_mib" >> "$CSVFILE"

TOTAL_MEM_KB=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)

cases=(propane ch3no2 octane)
nprocs=(1 2 4 8)
envs=("rmg_241_env" "rmg_300_env" "rmg_3.3.0+c2d1cee_env")
dirs=("2.4.1" "3.0.0" "3.3.0+c2d1cee")

for v in "${!envs[@]}"; do
    mkdir -p "${OUTDIR}/${dirs[$v]}"
    conda activate "${envs[$v]}"

    for case in "${cases[@]}"; do
        for np in "${nprocs[@]}"; do
            subdir="${OUTDIR}/${dirs[$v]}/${case}_${np}proc"
            mkdir -p "$subdir"

            start_time=$(date +%s)

            python "${dirs[$v]}/RMG-Py/rmg.py" \
                --maxproc "$np" \
                --output-directory "$subdir" \
                "${dirs[$v]}/${case}.py" &
            PY_PID=$!

            max_total_kb=0
            min_available_kb=$TOTAL_MEM_KB

            while ps -p $PY_PID > /dev/null; do
                current_total_kb=$(ps -o rss= --pid $PY_PID $(pgrep -P $PY_PID) 2>/dev/null | \
                                awk '{sum+=$1} END {print sum+0}')

                if [[ -n "$current_total_kb" && "$current_total_kb" -gt "$max_total_kb" ]]; then
                    max_total_kb=$current_total_kb
                fi

                current_available_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)

                if [[ -n "$current_available_kb" && "$current_available_kb" -lt "$min_available_kb" ]]; then
                    min_available_kb=$current_available_kb
                fi

                sleep 1
            done

            end_time=$(date +%s)
            execution_time=$((end_time - start_time))
            formatted_time=$(printf "%02d:%02d" $((execution_time / 60)) $((execution_time % 60)))

            used_actual_kb=$((TOTAL_MEM_KB - min_available_kb))

            peak_rss_mib=$((max_total_kb / 1024))
            min_memavail_mib=$((min_available_kb / 1024))
            ram_pressure_mib=$((used_actual_kb / 1024))

            # Write CSV row
            echo "${dirs[$v]},${case},${np},${execution_time},${formatted_time},${peak_rss_mib},${min_memavail_mib},${ram_pressure_mib}" >> "$CSVFILE"

            # Optional console progress output
            echo "Finished: version=${dirs[$v]} case=${case} procs=${np}"
        done
    done
done
