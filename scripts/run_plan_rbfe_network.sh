#!/usr/bin/env bash
# Site-specific scheduler/module settings live in scripts/hpc_config.sh.
# Submit this script with:
#     sbatch "${SBATCH_PLAN_RBFE_NETWORK[@]}" run_plan_rbfe_network.sh ...
# after sourcing hpc_config.sh in your submitting shell.
set -uo pipefail

SCRIPT_DIR="${SKILL_DIR}/scripts"
source "$SCRIPT_DIR/hpc_config.sh"
: "${OPENFE_HPC_CONFIG_LOADED:?hpc_config.sh failed to load}"
load_openfe_env

hostname

# This script plans the RBFE transformation network

# Initialize variables
OUTPUT="network_setup"
NS=5
EDGE=""
COFACTORS=""
PROTOCOL=""

# Parse named arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ligands)
      LIGANDS="$2"
      shift 2
      ;;
    --pdb)
      PROTEIN="$2"
      shift 2
      ;;
    --cofactors)
      COFACTORS="$2"
      shift 2
      ;;
    --edge)
      EDGE="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --ns)
      NS="$2"
      shift 2
      ;;
    --protocol)
      PROTOCOL="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Ensure required parameters are provided
if [ -z "$LIGANDS" ] || [ -z "$PROTEIN" ]; then
    echo "Error: Missing required arguments."
    echo "Usage: sbatch $0 --ligands <file.sdf> --pdb <file.pdb> [options]"
    echo "Options:"
    echo "  --output <dir>           (Output directory, default: network_setup)"
    echo "  --edge <file.edge>       (FEP+ edge file)"
    echo "  --cofactors <file.sdf>   (Cofactors SDF)"
    echo "  --ns <int>               (For Hybrid Topology protocol: production simulation length in ns, default: 5)"
    echo "  --protocol <str>         (RBFE protocol: 'h' or 's', default: 'h' for Hybrid Topology protocol)"
    exit 1
fi

echo "Ligands file: $LIGANDS"
echo "Protein file: $PROTEIN"
echo "Output dir: $OUTPUT"

# Exit with message if output directory exists
if [ -d "$OUTPUT" ]; then
    echo "Error: Output directory $OUTPUT already exists. Please remove it or choose a different name."
    exit 1
fi

# Pull correct CPU thread count directly from SLURM, falling back to 1 outside of SLURM
CPUS=${SLURM_CPUS_PER_TASK:-1}
echo "Using $CPUS CPU core(s)"

# Build command array 
CMD_ARGS=(
    "--ligands" "$LIGANDS"
    "--pdb" "$PROTEIN"
    "--output" "$OUTPUT"
    "--cpus" "$CPUS"
)

# Append optional arguments if they exist
[[ -n "$EDGE" ]] && echo "Edge file: $EDGE" && CMD_ARGS+=("--edge" "$EDGE")
[[ -n "$COFACTORS" ]] && echo "Cofactors file: $COFACTORS" && CMD_ARGS+=("--cofactors" "$COFACTORS")

# RBFE protocol: Hybrid or SepTop
PROTOCOL="${PROTOCOL:-h}"
if [[ "$PROTOCOL" == "s" ]]; then
    echo "Using SepTop protocol"
    script="$SCRIPT_DIR/create_SepTop_transformations.py"
elif [[ "$PROTOCOL" == "h" ]]; then
    echo "Using Hybrid Topology protocol (default)"
    script="$SCRIPT_DIR/plan_network_multicpu.py"
    [[ -n "$NS" ]] && echo "Production Simulation length: $NS ns" && CMD_ARGS+=("--ns" "$NS")
else
    echo "Error: Invalid protocol '$PROTOCOL'. Valid values are 'h' (Hybrid Topology) or 's' (SepTop)."
    exit 1
fi

echo "Executing: python $script ${CMD_ARGS[@]}"
python "$script" "${CMD_ARGS[@]}"
