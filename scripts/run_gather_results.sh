#!/usr/bin/env bash
# Site-specific scheduler/module settings live in scripts/hpc_config.sh.
# Submit this script with:
#     sbatch "${SBATCH_GATHER_RESULTS[@]}" run_gather_results.sh
# after sourcing hpc_config.sh in your submitting shell.
set -uo pipefail

SCRIPT_DIR="${SKILL_DIR}/scripts"
source "$SCRIPT_DIR/hpc_config.sh"
: "${OPENFE_HPC_CONFIG_LOADED:?hpc_config.sh failed to load}"
load_openfe_env

hostname

# if a folder named "results" is in not in the current directory, exit with error message
if [ ! -d "results" ]; then
    echo "Error: results folder not found in the current directory"
    exit 1
fi

echo "Start gathering results and this will take a few minutes..."
openfe gather results/ --report dg -o results_dg.tsv --allow-partial 

openfe gather results/ --report ddg -o results_ddg.tsv --allow-partial 



