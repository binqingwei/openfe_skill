#!/usr/bin/env bash
# Site-specific scheduler/module settings live in scripts/hpc_config.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hpc_config.sh"
: "${OPENFE_HPC_CONFIG_LOADED:?hpc_config.sh failed to load}"

echo "This is an executable bash script; do not prefix it with sbatch"
echo "Usage: $0 [-rep N | -mps3] [TRANSFORM_DIR] [protocol]"
echo "  -rep N: run N replicas without CUDA MPS (default: 1)"
echo "  -mps3: run 3 replicas with CUDA MPS"
echo "  TRANSFORM_DIR: path to the directory containing transformation .json files (default: network_setup/transformations)"
echo "  protocol: protocol to use (h for hybrid (default); s for septop)"
echo ""

REPLICAS=1
USE_MPS3=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -rep)
            if [[ -z "${2:-}" ]]; then
                echo "Error: -rep requires an integer argument."
                exit 1
            fi
            if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -lt 1 ]]; then
                echo "Error: invalid replica count '$2'. Expected integer >= 1."
                exit 1
            fi
            REPLICAS="$2"
            USE_MPS3=0
            shift 2
            ;;
        -mps3)
            USE_MPS3=1
            REPLICAS=3
            shift
            ;;
        -h|--help)
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

TRANSFORM_DIR="${1:-network_setup/transformations}"
echo "Using transformations directory: $TRANSFORM_DIR"

# check if the transformations directory exists
if [ ! -d "$TRANSFORM_DIR" ]; then
    echo "Error: $TRANSFORM_DIR directory does not exist."
    exit 1
fi

protocol="${2:-h}"
SBATCH_OPTS=()
if [[ "$protocol" == "h" ]]; then
    echo "Using Hybrid Topology protocol"
    SBATCH_OPTS=( "${SBATCH_TRANSFORM_HYBRID[@]}" )
elif [[ "$protocol" == "s" ]]; then
    echo "Using SepTop protocol"
    SBATCH_OPTS=( "${SBATCH_TRANSFORM_SEPTOP[@]}" )
else
    echo "Error: Invalid protocol specified. Use 'h' for Hybrid Topology or 's' for SepTop."
    exit 1
fi

if [[ "$USE_MPS3" -eq 1 ]]; then
    script="$SCRIPT_DIR/run_one_transform_3reps_mps.sh"
    if [[ "$protocol" == "h" ]]; then
        SBATCH_OPTS=( "${SBATCH_TRANSFORM_HYBRID_MPS3[@]}" )
    else
        SBATCH_OPTS=( "${SBATCH_TRANSFORM_SEPTOP_MPS3[@]}" )
    fi
    script_extra_args=()
    echo "Replica mode: CUDA MPS with 3 replicas on 1 L40s GPU"
else
    script="$SCRIPT_DIR/run_one_transform_reps.sh"
    script_extra_args=("$REPLICAS")
    echo "Replica mode: no MPS, replicas=$REPLICAS"
fi

# loop over all the transformations in the subfolder and submit each as a SLURM job
for file in "$TRANSFORM_DIR"/*.json ; do
    echo "Transformation "${file}
    echo "ECHO COMMAND LINE: sbatch ${SBATCH_OPTS[*]} ${script} ${file} ${script_extra_args[*]}"
    sbatch "${SBATCH_OPTS[@]}" "${script}" "${file}" "${script_extra_args[@]}"
done
