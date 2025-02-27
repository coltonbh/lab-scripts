#!/bin/bash
# This script starts a BigChem Celery worker in daemon mode with a specified number
# of forked subprocess workers.
#
# Usage: ./start-bigchem-worker.sh [queue_name] [num_workers]
# Example: ./start-bigchem-worker.sh my-queue 4
#
# If no queue name is provided, the default queue ("celery") is used.
# If no worker count is provided, it defaults to the number of available CPU cores.

# Directory to store PID and log files; adjust as needed.
PID_DIR="/tmp/$USER/bigchem_workers"
mkdir -p "$PID_DIR"

# ---------------------------
# 0. Process command-line arguments
# ---------------------------
QUEUE=${1:-celery}
echo "Using queue: $QUEUE"

# Determine number of workers; default to number of CPU cores if not provided.
if [ -n "$2" ]; then
    NUM_WORKERS="$2"
else
    if command -v nproc >/dev/null 2>&1; then
        NUM_WORKERS=$(nproc)
    else
        NUM_WORKERS=1
    fi
fi
echo "Using number of subprocess workers: $NUM_WORKERS"

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
# 3. Start a Celery worker with forked subprocess workers.
# ---------------------------
echo "Starting Celery worker with concurrency: $NUM_WORKERS"

# Define PID and log file paths.
PIDFILE="$PID_DIR/celery_worker.pid"
LOGFILE="$PID_DIR/celery_worker.log"

# Remove the log file if it exists (to avoid appending).
rm -f "$LOGFILE"

# Launch the worker in detached (daemon) mode.
celery -A bigchem.tasks worker \
    --hostname=$USER-%h-$$ \
    -Q "$QUEUE" \
    -c "$NUM_WORKERS" \
    --without-heartbeat --without-mingle --without-gossip \
    --loglevel=INFO --detach \
    --pidfile="$PIDFILE" \
    --logfile="$LOGFILE"

echo "Celery worker started with $NUM_WORKERS subprocesses."
echo "PID file: $PIDFILE"
echo "Log file: $LOGFILE"
