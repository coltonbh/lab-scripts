#!/bin/bash
# stop-workers.sh
# This script stops the Celery workers started by start-workers.sh.

PID_DIR="/tmp/bigchem_workers"

if [ ! -d "$PID_DIR" ]; then
  echo "No PID directory found ($PID_DIR). No workers to stop."
  exit 0
fi

# Loop over all PID files and terminate the processes.
for pidfile in "$PID_DIR"/*.pid; do
  # Skip if no pid files are present.
  [ -e "$pidfile" ] || continue
  PID=$(cat "$pidfile")
  echo "Stopping worker with PID $PID (pid file: $pidfile)"
  kill "$PID"
  
  # Optionally wait until the process has terminated.
  while kill -0 "$PID" 2>/dev/null; do
    sleep 1
  done
done

echo "All workers stopped."
