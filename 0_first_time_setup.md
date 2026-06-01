---
name: First-time setup
description: Agent-led setup of environment and HPC scheduler
---

# Instructions for the Agent:

1. **Confirm SKILL_DIR.** Ask the user to confirm the skill directory path. The default is `$HOME/.claude/skills/openfe_skill`. If the user provides a different path, update the `SKILL_DIR="..."` line in every one of these files to match:
   - `1_validate_input.md`, `2_plan_rbfe_network.md`, `3_submit_jobs.md`, `4_gather_results.md`, `a_plot_correlations.md`, `b_setup_prescreen_by_ID_suffix.md`

   Use the confirmed path as `$SKILL_DIR` in all commands below.

2. **Check whether setup is already done.** Run:
   ```bash
   source $SKILL_DIR/scripts/hpc_config.sh && echo $SITE_CONFIGURED
   ```
   If the output is `true`, the setup is already completed; exit. If it is `false` or empty, continue below.

3. **Interview the user.** Ask the following questions (all are required):
   - What is the command to load **openfe environment** (e.g. `ml CEDAR; ml Python/openfe`, or `conda activate openfe`)
   - What is the **SLURM account** (e.g. `-A openfe`), or `none` if not required
   - What are the **GPU partition** (e.g.`-p gpu`), **GPU type** (e.g. `l40s`) for those steps that run on gpu

4. **Edit `$SKILL_DIR/scripts/hpc_config.sh`** based on the answers:
   - Replace the body of `load_openfe_env()` with the correct commands.
   - Update every `SBATCH_*` array: set `-A`, `-p`, `--gres` to match user's specifications (e.g. `-A openfe`, `-p gpu`, `--gres=gpu:l40s:1` ).
   - Set `SITE_CONFIGURED=true` at the bottom.

5. **Validate the configuration.** Run:
   ```bash
   bash $SKILL_DIR/scripts/check_config.sh
   ```
   All checks must pass before proceeding. If any fail, explain what the error(s) mean to user, ask user to examine `$SKILL_DIR/scripts/hpc_config.sh`, then ask user for input before trying to fix the error(s).

6. Once `check_config.sh` reports **"All checks passed"**, suggest user to review `$SKILL_DIR/scripts/hpc_config.sh`. Then proceed to Step 1 (Input Validation).