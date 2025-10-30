#!/bin/bash
# Usage: sbatch --qos=gpu_normal bigchem-workers-slurm.sh [QUEUE]
#SBATCH --job-name=bigchem-worker
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4  # Adjust based on your requirements
#SBATCH --mem=16G          # Adjust based on your requirements
#SBATCH --array=1-10       # Number of BigChem workers; Adjust based on your requirements
#SBATCH -p gpu_q
#SBATCH --qos=gpu_normal    # gpu_short (12 hour limit), gpu_normal (4 day limit), or gpu_dp (4 day limit)
#SBATCH --gres=gpu:1       # Request 1 GPU

# Use the first script argument as the queue, defaulting to "celery" if not provided.
QUEUE=${1:-celery}

# Setup logging directory
LOGDIR="bigchem-worker-logs"
[ ! -d "$LOGDIR" ] && mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/bigchem-worker-${SLURM_ARRAY_JOB_ID}-${SLURM_ARRAY_TASK_ID}.log"

# Activate BigChem micromamba environment
eval "$(micromamba shell hook --shell bash)"
micromamba activate bigchem

# Load TeraChem
ml TeraChem

# Tell the worker where to find the broker and backend (redis server)
source /home/coltonbh/stacks/bigchem.prod.sh

# Start the worker
# --hostname=%h-$$ provides a unique .pidbox queue for each worker even if on the same host. $$ expands to process id.
# or use --hostname=%h-$(uuidgen) for globally unique names even if multiple hosts share the same name
srun TMPDIR="$TMPDIR" celery -A bigchem.tasks worker \
    -Q "$QUEUE" \
    --hostname=$USER-slurm-%h-$$ \
    --without-heartbeat --without-mingle --without-gossip \
    --loglevel=INFO \
    --logfile="$LOGFILE"
