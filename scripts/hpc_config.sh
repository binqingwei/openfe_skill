# =============================================================================
# hpc_config.sh -- Site-specific HPC configuration for the openfe_skill scripts
# =============================================================================
#
# Purpose
# -------
# This file isolates everything that is specific to a particular cluster:
#   1. Environment / module setup (e.g. `ml`, `module load`, `conda activate`)
#   2. SLURM `#SBATCH` directives, expressed as arrays of `sbatch` CLI flags
#
# Users on a different system should ONLY need to edit this file. The payload
# scripts (run_*.sh) and the submit wrappers source this file and use the
# variables/functions defined below.
#
# NEW USER SETUP
# -------------
# 1. Edit load_openfe_env() below to match your cluster's environment setup.
# 2. Edit the SBATCH_* arrays to match your partition, account, GPU type, etc.
# 3. Set SITE_CONFIGURED=true (the line near the bottom of this file).
# 4. Run:  bash scripts/check_config.sh   to validate before submitting jobs.
#
# Usage
# -----
# In a payload script:
#     source "$(dirname "$0")/hpc_config.sh"
#     load_openfe_env
#
# In a submit wrapper:
#     source "$(dirname "$0")/hpc_config.sh"
#     sbatch "${SBATCH_PLAN_RBFE_NETWORK[@]}" run_plan_rbfe_network.sh ...
#
# Note on #SBATCH directives
# --------------------------
# `#SBATCH` lines inside a script are parsed by `sbatch` BEFORE the script
# runs, so they cannot be set by sourcing a config at runtime. That is why
# scheduler options here are arrays of CLI flags passed to `sbatch` at submit
# time. The payload scripts contain no `#SBATCH` lines.
# =============================================================================


# -----------------------------------------------------------------------------
# 1. Environment setup
# -----------------------------------------------------------------------------
# Replace the body of `load_openfe_env` with whatever your site requires to
# make `openfe` and `python` available on PATH (module loads, conda activate,
# `source venv/bin/activate`, etc.).
#
# Examples for other systems are provided (commented out) below.
# -----------------------------------------------------------------------------

load_openfe_env() {
    # --- Load OpenFE environment (HPC/user specific)--------------------------
    ml CEDAR
    ml Python/openfe

    # --- Example: generic Lmod cluster ---------------------------------------
    # module purge
    # module load python/3.11
    # module load cuda/12.4
    # source /path/to/openfe-venv/bin/activate

    # --- Example: conda-based site -------------------------------------------
    # source "$HOME/miniconda3/etc/profile.d/conda.sh"
    # conda activate openfe

    # --- Example: no module system (workstation) -----------------------------
    # export PATH="$HOME/mambaforge/envs/openfe/bin:$PATH"

    :
}


# -----------------------------------------------------------------------------
# 2. SLURM directives, per job type
# -----------------------------------------------------------------------------
# Each array holds the flags that will be passed to `sbatch` at submit time.
# Add, remove, or edit flags here to match your scheduler/partition/QOS.
# Leave an array empty (e.g. `SBATCH_FOO=()`) to submit with site defaults.
#
# If your site does not use SLURM at all, you can ignore these arrays and
# adapt the submit wrappers to call your scheduler (bsub, qsub, etc.).
# -----------------------------------------------------------------------------

# ---- Input validation (GPU, short) -- run_input_validation_cv.sh ------------
SBATCH_INPUT_VALIDATION=(
    -A openfe
    -p gpu
    --gres=gpu:l40s:1
    -n 1
    -N 1
    -t 0-01:00
    --mem=2000
    -J input_validation
    -o input_validation_%j.out
    -e input_validation_%j.err
)

# ---- Network planning (CPU, multiprocessing) -- run_plan_rbfe_network.sh ----
SBATCH_PLAN_RBFE_NETWORK=(
    -A openfe
    --nodes=1
    --ntasks=1
    --cpus-per-task=8
    -t 0-01:00
    --mem=2000
    -J plan_rbfe_network
    -o plan_rbfe_network_%j.out
    -e plan_rbfe_network_%j.err
)

# ---- One transformation, 1-3 replicas, no MPS (Hybrid Topology) ------------------
#       run_one_transform_reps.sh
SBATCH_TRANSFORM_HYBRID=(
    -A openfe
    -p gpu
    --gres=gpu:l40s:1
    -n 1
    -c 2
    --mem=6G
    --time=36:00:00
    -J OpenFE
    -o job_%j.out
    -e job_%j.err
)

# ---- One transformation, 3 replicas, MPS (Hybrid Topology) ------------------
#       run_one_transform_3reps_mps.sh
SBATCH_TRANSFORM_HYBRID_MPS3=(
    -A openfe
    -p gpu
    --gres=gpu:l40s:1
    -n 1
    -c 3
    --mem=9G
    --time=36:00:00
    -J OpenFE_3MPS
    -o job_%j.out
    -e job_%j.err
)

# ---- One transformation, 1-3 replicas, no MPS (SepTop) ---------------------------
#       run_one_transform_reps.sh
SBATCH_TRANSFORM_SEPTOP=(
    -A openfe
    -p gpu
    --gres=gpu:l40s:1
    -n 1
    -c 2
    --mem=12G
    --time=72:00:00
    -J OpenFE_SepTop
    -o job_%j.out
    -e job_%j.err
)

# ---- One transformation, 3 replicas, MPS (SepTop) ---------------------------
#       run_one_transform_3reps_mps_septop.sh
SBATCH_TRANSFORM_SEPTOP_MPS3=(
    -A openfe
    -p gpu
    --gres=gpu:l40s:1
    -n 1
    -c 3
    --mem=18G
    --time=72:00:00
    -J OpenFE_SepTop_3MPS
    -o job_%j.out
    -e job_%j.err
)

# ---- Gather results (CPU, short) -- run_gather_results.sh -------------------
SBATCH_GATHER_RESULTS=(
    -A openfe
    -n 1
    -N 1
    -t 0-01:00
    --mem=2000
    -J gather_results
    -o gather_results_%j.out
    -e gather_results_%j.err
)


# -----------------------------------------------------------------------------
# 3. Sentinels
# -----------------------------------------------------------------------------
# OPENFE_HPC_CONFIG_LOADED: checked by payload scripts to confirm this file
#   was sourced. Do NOT remove.
# SITE_CONFIGURED: set to "true" once you have edited this file for your
#   cluster. check_config.sh will fail until this is "true".
# -----------------------------------------------------------------------------
export OPENFE_HPC_CONFIG_LOADED=1
export SITE_CONFIGURED=true
