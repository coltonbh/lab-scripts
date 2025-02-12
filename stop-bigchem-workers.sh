#!/bin/bash
# This script stops the Celery workers started by start-bigchem-workers.sh.

PID_DIR="/tmp/$USER/bigchem_workers"

if [ ! -d "$PID_DIR" ]; then
  echo "No PID directory found ($PID_DIR). No workers to stop."
  exit 0
fi

# Array to hold all the PIDs.
PIDS=()

# Loop over all PID files and send kill signal to all workers.
for pidfile in "$PID_DIR"/*.pid; do
  [ -e "$pidfile" ] || continue
  PID=$(cat "$pidfile")
  echo "Sending kill signal to worker with PID $PID (pid file: $pidfile)"
  kill "$PID"
  PIDS+=("$PID")
done

# Now wait until all processes have terminated.
echo "Waiting for all workers to stop..."
while true; do
  all_dead=true
  for pid in "${PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      all_dead=false
      break
    fi
  done
  $all_dead && break
  sleep 1
done

echo "All workers stopped."
