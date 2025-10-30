#!/bin/bash
# This script starts BigChem Celery workers in daemon mode, one per GPU.
# Usage: bash ./start-bigchem-workers.sh [queue_name] [gpu_list]
# Example: bash ./start-bigchem-workers.sh my-queue 0,1,4,7
# If no queue name is provided, the default queue (celery) is used.
# If no GPU list is provided, all available GPUs are used.

# Directory to store PID and log files; adjust as needed.
PID_DIR="/tmp/$USER/bigchem_workers"
mkdir -p "$PID_DIR"

# ---------------------------
# 0. Process command-line arguments
# ---------------------------
QUEUE=${1:-celery}
echo "Using queue: $QUEUE"

if [ -n "$2" ]; then
    # Use provided GPU list.
    # Accept both comma-separated list.
    GPU_STRING="$2"
    # Replace commas with spaces, then convert to an array.
    GPU_STRING=$(echo "$GPU_STRING" | tr ',' ' ')
    GPUS=($GPU_STRING)
    echo "Using provided GPUs: ${GPUS[*]}"
else
    # Auto-detect available GPUs via nvidia-smi.
    NUM_GPUS=$(nvidia-smi -L | wc -l)
    echo "Detected $NUM_GPUS GPUs."
    # Build an array of GPU indices: 0,1,...,NUM_GPUS-1
    GPUS=($(seq 0 $((NUM_GPUS - 1))))
    echo "Using GPU indices: ${GPUS[*]}"
fi

# ---------------------------
# 1. Detect current shell
# ---------------------------
if [ -n "$BASH_VERSION" ]; then
    shell_name="bash"
elif [ -n "$ZSH_VERSION" ]; then
    shell_name="zsh"
else
    # Fallback: extract basename from $SHELL.
    shell_name=$(basename "$SHELL")
fi
echo "Detected shell: $shell_name"

# Initialize micromamba in the current shell.
eval "$(micromamba shell hook --shell $shell_name)"
micromamba activate bigchem

# ---------------------------
# 2. Load common variables and modules
# ---------------------------
source /home/coltonbh/stacks/bigchem.prod.sh
ml TeraChem

# ---------------------------
# 3. Start a Celery worker per GPU.
# ---------------------------
for gpu in "${GPUS[@]}"; do
    echo "Starting Celery worker on GPU $gpu"

    # Define PID and log file paths for this worker.
    PIDFILE="$PID_DIR/celery_worker_${gpu}.pid"
    LOGFILE="$PID_DIR/celery_worker_${gpu}.log"

    # Remove the log file if it exists (to avoid appending).
    rm -f "$LOGFILE"

    # Launch the worker with its unique GPU environment variable.
    # --hostname=%h-$$ provides a unique .pidbox queue for each worker even if on the same host. $$ expands to process id.
    CUDA_VISIBLE_DEVICES=$gpu celery -A bigchem.tasks worker \
        --hostname=$USER-%h-gpu-$gpu \
        -Q $QUEUE \
        --without-heartbeat --without-mingle --without-gossip \
        --loglevel=INFO --detach \
        --pidfile="$PIDFILE" \
        --logfile="$LOGFILE"
done

echo "All workers started. PID files can be found in $PID_DIR."
echo "Log files can be found in $PID_DIR."
