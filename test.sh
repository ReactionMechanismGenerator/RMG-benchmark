OUTDIR="rmgpy_output_$(date +'%Y%m%d_%H%M%S')"
mkdir "$OUTDIR"
LOGFILE="$OUTDIR/log.txt"
touch "$LOGFILE"

TOTAL_MEM_KB=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
echo "Machine Total Memory (MiB): $((TOTAL_MEM_KB / 1024))" >> $LOGFILE

cases=(teos ch3no2 octane)

nprocs=(1 2 4 8)

envs=(rmg_241_env rmg_300_env)
dirs=(2.4.1 3.0.0)

for v in "${!envs[@]}"; do
    mkdir "${OUTDIR}/${dirs[$v]}"
    conda activate "${envs[$v]}"
    for case in "${cases[@]}"; do
        for np in "${nprocs[@]}"; do
            subdir="${OUTDIR}/${dirs[$v]}/${case}_${np}proc"
            mkdir "$subdir"

            # 1. Start the Python process in the background
            python ${dirs[$v]}/RMG-Py/rmg.py --maxproc "$np" --output-directory "$subdir" "${dirs[$v]}/${case}.py" &
            PY_PID=$!
            
            # 2. Watcher loop: Track total RSS (parent + all children)
            max_total_kb=0
            min_available_kb=$TOTAL_MEM_KB
            while ps -p $PY_PID > /dev/null; do
                # Peak summed RSS (existing)
                current_total_kb=$(ps -o rss= --pid $PY_PID $(pgrep -P $PY_PID) 2>/dev/null | \
                                awk '{sum+=$1} END {print sum+0}')

                if [ "$current_total_kb" -gt "$max_total_kb" ]; then
                    max_total_kb=$current_total_kb
                fi

                current_available_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)

                if [ "$current_available_kb" -lt "$min_available_kb" ]; then
                    min_available_kb=$current_available_kb
                fi

                sleep 1
            done

            # 3. Log results manually
            used_actual_kb=$((TOTAL_MEM_KB - min_available_kb))

            echo -e "\nVersion: ${dirs[$v]} | Case: $case | Processes: $np" | tee -a "$LOGFILE"
            echo "Peak aggregate RSS (MiB): $((max_total_kb / 1024))" | tee -a "$LOGFILE"
            echo "Minimum system MemAvailable (MiB): $((min_available_kb / 1024))" | tee -a "$LOGFILE"
            echo "Peak actual RAM pressure (MiB): $((used_actual_kb / 1024))" | tee -a "$LOGFILE"
        done
    done
done
