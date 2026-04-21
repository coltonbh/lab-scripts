#!/bin/bash
# This script stops the Celery workers started by start-bigchem-workers.sh.
# Usage: bash ./stop-bigchem-workers.sh

HOSTNAME=$(hostname -s 2>/dev/null || hostname)
PID_DIR="/tmp/$USER/bigchem_workers/$HOSTNAME"

if [ ! -d "$PID_DIR" ]; then
  echo "No PID directory found ($PID_DIR). No workers to stop."
  exit 0
fi

# Array to hold all the PIDs.
PIDS=()
pid_files_found=0
kill_failures=0

# Loop over all PID files and send kill signal to all workers.
while IFS= read -r pidfile; do
  pid_files_found=$((pid_files_found + 1))
  PID=$(cat "$pidfile")
  if ! [[ "$PID" =~ ^[0-9]+$ ]]; then
    echo "Skipping invalid PID '$PID' in $pidfile" >&2
    continue
  fi

  echo "Sending kill signal to worker with PID $PID (pid file: $pidfile)"
  if ! kill "$PID"; then
    echo "Failed to send kill signal to PID $PID" >&2
    kill_failures=$((kill_failures + 1))
    continue
  fi
  PIDS+=("$PID")
done < <(find "$PID_DIR" -type f -name "*.pid" | sort)

if [ "${#PIDS[@]}" -eq 0 ]; then
  if [ "$pid_files_found" -eq 0 ]; then
    echo "No worker PID files found on current node ($HOSTNAME)."
    exit 0
  fi

  echo "No workers were signaled on current node ($HOSTNAME)." >&2
  exit 1
fi

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

if [ "$kill_failures" -gt 0 ]; then
  echo "Workers stopped, but $kill_failures kill signal(s) failed." >&2
  exit 1
fi

echo "All workers stopped."
