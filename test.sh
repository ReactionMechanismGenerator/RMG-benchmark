#!/usr/bin/env bash

# Configure repetitions (default to 3)
REPETITIONS=${1:-3}

OUTDIR="rmgpy_output_$(date +'%Y%m%d_%H%M%S')"
mkdir -p "$OUTDIR"

CSVFILE="$OUTDIR/results.csv"
touch "$CSVFILE"

# Write CSV header (added 'run' column)
echo "version,case,processes,run,execution_time_s,execution_time_mmss,peak_rss_mib,min_memavailable_mib,peak_ram_pressure_mib" >> "$CSVFILE"

TOTAL_MEM_KB=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)

cases=(heptane diesel propane octane)
nprocs=(1 2 4 8)
envs=("rmg_241_env" "rmg_300_env" "rmg_400_env")
dirs=("2.4.1" "3.0.0" "4.0.0")

echo "Starting benchmark with $REPETITIONS repetitions..."

for v in "${!envs[@]}"; do
    mkdir -p "${OUTDIR}/${dirs[$v]}"
    conda activate "${envs[$v]}"

    for case in "${cases[@]}"; do
        for np in "${nprocs[@]}"; do
            for rep in $(seq 1 $REPETITIONS); do
                # Append run number to the output directory
                subdir="${OUTDIR}/${dirs[$v]}/${case}_${np}proc_run${rep}"
                mkdir -p "$subdir"

                echo "--- Running version=${dirs[$v]} case=${case} procs=${np} run=${rep} ---"

                python "${dirs[$v]}/RMG-Py/rmg.py" \
                    --maxproc "$np" \
                    --output-directory "$subdir" \
                    "${dirs[$v]}/${case}.py" &
                PY_PID=$!

                # Initialize timing and memory tracking
                start_time=$(date +%s)
                max_total_kb=0
                min_available_kb=$TOTAL_MEM_KB
                TIMEOUT_SECONDS=3600  # 1 hour limit

                while ps -p $PY_PID > /dev/null; do
                    current_time=$(date +%s)
                    elapsed=$((current_time - start_time))

                    # Check if execution has exceeded 1 hour
                    if [ "$elapsed" -ge "$TIMEOUT_SECONDS" ]; then
                        echo "Timeout reached (1 hour). Terminating process $PY_PID..."
                        # Kill the process and all its children
                        pkill -P $PY_PID
                        kill $PY_PID
                        break
                    fi

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

                # Write CSV row (includes the run number)
                echo "${dirs[$v]},${case},${np},${rep},${execution_time},${formatted_time},${peak_rss_mib},${min_memavail_mib},${ram_pressure_mib}" >> "$CSVFILE"

                echo "Finished: version=${dirs[$v]} case=${case} procs=${np} run=${rep}"
            done
        done
    done
done

echo "All $REPETITIONS runs completed."
