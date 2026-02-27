LOGFILE="log_$(date +'%Y%m%d_%H%M%S').txt"
touch $LOGFILE
NPROC=$(nproc)
OUTDIR=rmgpy_output

cases=(diesel octane heptane)

for i in "${!cases[@]}"; do
    case="${cases[$i]}"
    mkdir "${OUTDIR}_${case}"
    /usr/bin/time -f "\nReal Time: %E\nMax. Memory Used in kB: %M" \
        python RMG-Py/rmg.py \
        --maxproc "$NPROC" \
        --output-directory "${OUTDIR}_${case}" \
        "${case}.py" |& tee -a "$LOGFILE"
done
