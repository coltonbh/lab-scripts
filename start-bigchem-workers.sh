#!/bin/bash
# start-workers.sh
# This script starts Celery workers in daemon mode, one per GPU.
### USAGE: ./start-workers.sh [queue_name]
# If no queue name is provided, the default queue (celery) is used.

# Directory to store PID and log files; adjust as needed.
PID_DIR="/tmp/bigchem_workers"
mkdir -p "$PID_DIR"

# Activate environment, load modules, and source common variables.

# ---------------------------
# 0. Process command-line argument
# ---------------------------
QUEUE=${1:-celery}
echo "Using queue: $QUEUE"

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

# Initialize micromamba in the current shell
eval "$(micromamba shell hook --shell $shell_name)"
micromamba activate bigchem

# ---------------------------
# 2. Load common variables and modules
# ---------------------------
source /home/coltonbh/stacks/bigchem.prod.sh
ml TeraChem

# ---------------------------
# 3. Detect available GPUs
# ---------------------------
NUM_GPUS=$(nvidia-smi -L | wc -l)
echo "Detected $NUM_GPUS GPUs."
# Build an array of GPU indices: 0,1,2,...,NUM_GPUS-1
GPUS=($(seq 0 $((NUM_GPUS - 1))))
# Or manually set GPUs to use on the node.
# GPUS=(0 1 2 3 4 5 6 7)
echo "GPU indices: ${GPUS[*]}"

# Start a Celery worker per GPU.
for gpu in "${GPUS[@]}"; do
    echo "Starting Celery worker on GPU $gpu"

    # Define PID and log file paths for this worker.
    PIDFILE="$PID_DIR/celery_worker_${gpu}.pid"
    LOGFILE="$PID_DIR/celery_worker_${gpu}.log"

    # Launch the worker with its unique GPU env var.
    env CUDA_VISIBLE_DEVICES=$gpu celery -A bigchem.tasks worker \
        -Q $QUEUE \
        --without-heartbeat --without-mingle --without-gossip \
        --loglevel=INFO --detach \
        --pidfile="$PIDFILE" \
        --logfile="$LOGFILE"
done

echo "All workers started. PID files can be found in $PID_DIR."
echo "Log files can be found in $PID_DIR."
