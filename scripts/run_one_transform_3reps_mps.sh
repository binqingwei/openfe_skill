#!/usr/bin/env bash
# Site-specific scheduler/module settings live in scripts/hpc_config.sh.
# Submit this script with either HYBRID or SEPTOP MPS3 SBATCH options:
#     sbatch "${SBATCH_TRANSFORM_HYBRID_MPS3[@]}" run_one_transform_3reps_mps.sh <edge.json>
#     sbatch "${SBATCH_TRANSFORM_SEPTOP_MPS3[@]}" run_one_transform_3reps_mps.sh <edge.json>
# after sourcing hpc_config.sh in your submitting shell.
set -uo pipefail

SCRIPT_DIR="${SKILL_DIR}/scripts"
source "$SCRIPT_DIR/hpc_config.sh"
: "${OPENFE_HPC_CONFIG_LOADED:?hpc_config.sh failed to load}"

if [ "$#" -lt 1 ]; then
    echo "Usage: sbatch run_one_transform_3reps_mps.sh <input_json_file>"
    exit 1
fi

# This script runs 3 replicas of one transformation of a campaign
echo "Working directory: "$PWD
echo "Transformation: "$1
WORKDIR=$PWD
RESULTS=$WORKDIR/results
echo "Results directory will be: "$RESULTS
mkdir -p $RESULTS/repeat1
mkdir -p $RESULTS/repeat2
mkdir -p $RESULTS/repeat3

#############################################################################
## run this script in a directory that contains "network_setup" sub-directory
## check if input .json file exists
if [ ! -f "$1" ]; then
    echo "Required input .json file $1 does not exist."
    echo "Usage: sbatch run_one_transform_3reps_mps.sh <input_json_file>"
    echo " This script is to be run in a folder that contains a "network_setup" sub-directory."
    exit 1
fi

hst=$(hostname)
echo "Currently running on host: "$hst
now=$(date)
echo "Start time: "$now

load_openfe_env
export PYTHONPATH=""

TIMESTAMP=$(date +%Y%m%d_%H%M)

export CUDA_MPS_PIPE_DIRECTORY=/tmp/$USER/nvidia-mps-$SLURM_JOB_ID-${TIMESTAMP}/pipe
export CUDA_MPS_LOG_DIRECTORY=/tmp/$USER/nvidia-mps-$SLURM_JOB_ID-${TIMESTAMP}/log
export CUDA_MPS_STORAGE_DIRECTORY=/tmp/$USER/nvidia-mps-$SLURM_JOB_ID-${TIMESTAMP}/storage
mkdir -p $CUDA_MPS_PIPE_DIRECTORY $CUDA_MPS_LOG_DIRECTORY $CUDA_MPS_STORAGE_DIRECTORY

# assume 2 jobs per GPU
CUDA_MPS_ACTIVE_THREAD_PERCENTAGE=33.3
# verify if GPU is set to Exclusive Process mode (required by MPS), instead of Default mode
nvidia-smi -q | grep -i compute 
nvidia-cuda-mps-control -d

# MPS diagnostics
sleep 2
if pgrep -u $USER nvidia-cuda-mps; then
    echo "MPS Daemon is running." 
else
    echo "MPS Daemon failed to start! Check $CUDA_MPS_LOG_DIRECTORY for details."
    exit 1
fi
# Check if the pipe file exists
# ls -l $CUDA_MPS_PIPE_DIRECTORY

file=$(basename "$1")
prefix=${file%.*}

jobpath1="${RESULTS}/repeat1/${prefix}.log"
jobpath2="${RESULTS}/repeat2/${prefix}.log"
jobpath3="${RESULTS}/repeat3/${prefix}.log"
echo "Output job log files: ${jobpath1} and ${jobpath2} and ${jobpath3}"

if [ -f ${jobpath1} ] || [ -f ${jobpath2} ] || [ -f ${jobpath3} ]; then
  echo "${jobpath1} or ${jobpath2} or ${jobpath3} already exists; skip this transformation." 
  exit 0
fi

cmd=" openfe quickrun ${file} -o $RESULTS/repeat1/${prefix}.json -d $RESULTS/repeat1/${prefix} > ${jobpath1} " 
echo "Executing 3 times the following command: \n"${cmd}
openfe quickrun $1 -o $RESULTS/repeat1/${prefix}.json -d $RESULTS/repeat1/${prefix} > ${jobpath1} &
pid1=$!
openfe quickrun $1 -o $RESULTS/repeat2/${prefix}.json -d $RESULTS/repeat2/${prefix} > ${jobpath2} &
pid2=$!
openfe quickrun $1 -o $RESULTS/repeat3/${prefix}.json -d $RESULTS/repeat3/${prefix} > ${jobpath3} &
pid3=$!
wait $pid1 $pid2 $pid3

now=$(date)
echo "End time: "$now
echo "Shutting down Nvidia MPS"
echo quit | nvidia-cuda-mps-control

