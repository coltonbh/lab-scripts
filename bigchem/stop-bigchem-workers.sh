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
KILL_FAILED_PIDS=()
pid_files_found=0

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
    if kill -0 "$PID" 2>/dev/null; then
      echo "Failed to send kill signal to PID $PID (permission denied or other error)" >&2
      KILL_FAILED_PIDS+=("$PID")
    else
      echo "PID $PID is not running; treating $pidfile as stale/already stopped."
    fi
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

if [ "${#KILL_FAILED_PIDS[@]}" -gt 0 ]; then
  still_running=()
  for pid in "${KILL_FAILED_PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      still_running+=("$pid")
    fi
  done
  if [ "${#still_running[@]}" -gt 0 ]; then
    echo "Some workers may still be running (could not kill PIDs: ${still_running[*]})." >&2
    exit 1
  else
    echo "All kill failures resolved; previously-failing PIDs are no longer running."
  fi
fi

echo "All workers stopped."
