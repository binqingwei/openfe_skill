#!/usr/bin/env bash
# Site-specific scheduler/module settings live in scripts/hpc_config.sh.
# Submit this script with:
#     sbatch "${SBATCH_INPUT_VALIDATION[@]}" run_input_validation_cv.sh ...
# after sourcing hpc_config.sh in your submitting shell.
set -uo pipefail

SCRIPT_DIR="${SKILL_DIR}/scripts"
source "$SCRIPT_DIR/hpc_config.sh"
: "${OPENFE_HPC_CONFIG_LOADED:?hpc_config.sh failed to load}"
load_openfe_env

hostname

# This script runs validation of protein file / prep

script="$SCRIPT_DIR/input_validation.py"

if [ "$#" -eq 1 ]; then
    protein="$1"
    echo "Protein file: $protein"
    # assemble command line
    cmd="python $script --pdb $protein"
elif [ "$#" -eq 2 ]; then
    protein="$1"
    cofactors="$2"
    echo "Protein file: $protein  Cofactors file: $cofactors"
    # assemble command line
    cmd="python $script --pdb $protein --cofactors  $cofactors"
else
    echo "Missing required arguments"
    echo "Usage: $0 protein.pdb [cofactors.sdf]"
    exit 1
fi

# check if the input protein pdb file include cap name " NMA ". If yes, replace them with " NME ".
if grep -q " NMA " "$protein"; then
    echo "Found NMA in protein file, replacing with NME"
    sed -i 's/ NMA / NME /g' "$protein"
fi

# run the command
eval $cmd
