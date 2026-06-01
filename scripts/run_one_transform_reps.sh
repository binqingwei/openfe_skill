#!/usr/bin/env bash
# Site-specific scheduler/module settings live in scripts/hpc_config.sh.
# Submit this script with either HYBRID or SEPTOP SBATCH options:
#   Hybrid: sbatch "${SBATCH_TRANSFORM_HYBRID[@]}" run_one_transform_reps.sh <edge.json> <replicas>
#   SepTop: sbatch "${SBATCH_TRANSFORM_SEPTOP[@]}" run_one_transform_reps.sh <edge.json> <replicas>
# References: #sym:SBATCH_TRANSFORM_HYBRID #sym:SBATCH_TRANSFORM_SEPTOP
# after sourcing hpc_config.sh in your submitting shell.
set -uo pipefail

SCRIPT_DIR="${SKILL_DIR}/scripts"
source "$SCRIPT_DIR/hpc_config.sh"
: "${OPENFE_HPC_CONFIG_LOADED:?hpc_config.sh failed to load}"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: sbatch run_one_transform_reps.sh <input_json_file> [replicas]"
    exit 1
fi

INPUT_JSON="$1"
REPLICAS="${2:-1}"

if ! [[ "$REPLICAS" =~ ^[0-9]+$ ]] || [ "$REPLICAS" -lt 1 ]; then
    echo "Invalid replica count: $REPLICAS. Expected an integer >= 1."
    exit 1
fi

# This script runs one transformation with N replicas (no CUDA MPS)
echo "Working directory: $PWD"
echo "Transformation: $INPUT_JSON"
echo "Replica count: $REPLICAS"
WORKDIR=$PWD
RESULTS=$WORKDIR/results
echo "Results directory will be: $RESULTS"

#############################################################################
## run this script in a directory that contains "network_setup" sub-directory
## check if input .json file exists
if [ ! -f "$INPUT_JSON" ]; then
    echo "Required input .json file $INPUT_JSON does not exist."
    echo "Usage: sbatch run_one_transform_reps.sh <input_json_file> [replicas]"
    echo " This script is to be run in a folder that contains a \"network_setup\" sub-directory."
    exit 1
fi

for rep in $(seq 1 "$REPLICAS"); do
    mkdir -p "$RESULTS/repeat${rep}"
done

hst=$(hostname)
echo "Currently running on host: $hst"
now=$(date)
echo "Start time: $now"

load_openfe_env
export PYTHONPATH=""

file=$(basename "$INPUT_JSON")
prefix=${file%.*}

declare -a jobpaths=()
for rep in $(seq 1 "$REPLICAS"); do
    jobpaths+=("${RESULTS}/repeat${rep}/${prefix}.log")
done
echo "Output job log files: ${jobpaths[*]}"

for jobpath in "${jobpaths[@]}"; do
    if [ -f "$jobpath" ]; then
        echo "$jobpath already exists; skip this transformation."
        exit 0
    fi
done

cmd="openfe quickrun ${file} -o ${RESULTS}/repeat1/${prefix}.json -d ${RESULTS}/repeat1/${prefix} > ${RESULTS}/repeat1/${prefix}.log"
echo "Executing $REPLICAS replicas of command pattern:"
echo "$cmd"

declare -a pids=()
for rep in $(seq 1 "$REPLICAS"); do
    out_json="${RESULTS}/repeat${rep}/${prefix}.json"
    out_dir="${RESULTS}/repeat${rep}/${prefix}"
    out_log="${RESULTS}/repeat${rep}/${prefix}.log"
    openfe quickrun "$INPUT_JSON" -o "$out_json" -d "$out_dir" > "$out_log" &
    pids+=("$!")
done

wait "${pids[@]}"

now=$(date)
echo "End time: $now"