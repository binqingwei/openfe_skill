#!/usr/bin/env bash
# =============================================================================
# check_config.sh -- Validate hpc_config.sh before submitting any real jobs
# =============================================================================
#
# Usage:
#   bash scripts/check_config.sh
#
# What it checks:
#   1. hpc_config.sh can be sourced without errors
#   2. SITE_CONFIGURED flag is set to "true" (not the shipped default)
#   3. load_openfe_env() succeeds and puts `openfe` on PATH
#   4. `openfe --version` runs successfully
#   5. Python plotting libraries (pandas, matplotlib, seaborn) are available
#   6. A SLURM scheduler is reachable (sinfo exits 0)
#
# Exit codes:
#   0 = all checks passed
#   1 = one or more checks failed
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/hpc_config.sh"

PASS="[PASS]"
FAIL="[FAIL]"
WARN="[WARN]"
errors=0

echo "============================================================"
echo "  OpenFE HPC config check"
echo "  Config file: $CONFIG"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# 1. Source hpc_config.sh
# ---------------------------------------------------------------------------
echo "1. Sourcing hpc_config.sh ..."
if source "$CONFIG" 2>/dev/null; then
    echo "   $PASS hpc_config.sh sourced successfully"
else
    echo "   $FAIL hpc_config.sh failed to source -- fix syntax errors first"
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Check SITE_CONFIGURED sentinel
# ---------------------------------------------------------------------------
echo ""
echo "2. Checking SITE_CONFIGURED sentinel ..."
if [[ "${SITE_CONFIGURED:-false}" == "true" ]]; then
    echo "   $PASS SITE_CONFIGURED=true"
else
    echo "   $FAIL SITE_CONFIGURED is not 'true'."
    echo "         Edit scripts/hpc_config.sh: set SITE_CONFIGURED=true"
    echo "         after you have customised load_openfe_env() and the"
    echo "         SBATCH_* arrays for your cluster."
    errors=$(( errors + 1 ))
fi

# ---------------------------------------------------------------------------
# 3. load_openfe_env()
# ---------------------------------------------------------------------------
echo ""
echo "3. Running load_openfe_env() ..."
if load_openfe_env 2>&1; then
    echo "   $PASS load_openfe_env() returned 0"
else
    echo "   $FAIL load_openfe_env() returned a non-zero exit code"
    errors=$(( errors + 1 ))
fi

# ---------------------------------------------------------------------------
# 4. openfe on PATH
# ---------------------------------------------------------------------------
echo ""
echo "4. Checking openfe on PATH ..."
if command -v openfe &>/dev/null; then
    version=$(openfe --version 2>&1 || true)
    echo "   $PASS openfe found: $version"
else
    echo "   $FAIL 'openfe' not found on PATH after load_openfe_env()."
    echo "         Check the module/conda/venv commands in load_openfe_env()."
    errors=$(( errors + 1 ))
fi

# ---------------------------------------------------------------------------
# 5. Python plotting libraries (needed for plot_ddG_comparison_ofe.py)
# ---------------------------------------------------------------------------
echo ""
echo "5. Checking plotting libraries (pandas, matplotlib, seaborn) ..."
missing_libs=()
for lib in pandas matplotlib seaborn; do
    if python -c "import $lib" &>/dev/null 2>&1; then
        echo "   $PASS $lib"
    else
        echo "   $WARN $lib not found (needed for the Plot Correlations step)"
        missing_libs+=("$lib")
    fi
done
if [[ ${#missing_libs[@]} -gt 0 ]]; then
    echo "         Install with:  conda install -c conda-forge ${missing_libs[*]}"
    echo "         Or recreate the env:  conda env create -f environment.yml"
fi

# ---------------------------------------------------------------------------
# 6. SLURM reachability
# ---------------------------------------------------------------------------
echo ""
echo "6. Checking SLURM scheduler (sinfo) ..."
if command -v sinfo &>/dev/null; then
    if sinfo --noheader &>/dev/null; then
        echo "   $PASS sinfo returned successfully -- SLURM is reachable"
    else
        echo "   $WARN sinfo command exists but returned an error."
        echo "         This is expected on a login node of some clusters."
    fi
else
    echo "   $WARN 'sinfo' not found. If your site uses a different scheduler"
    echo "         (PBS/LSF/SGE), this warning can be ignored. Adapt the"
    echo "         SBATCH_* arrays in hpc_config.sh to your scheduler CLI."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
if [[ $errors -eq 0 ]]; then
    echo "  All checks passed. You are ready to run OpenFE jobs."
else
    echo "  $errors check(s) FAILED. Fix the issues above before submitting."
    echo "  Then re-run:  bash scripts/check_config.sh"
fi
echo "============================================================"

exit $( [[ $errors -eq 0 ]] && echo 0 || echo 1 )
