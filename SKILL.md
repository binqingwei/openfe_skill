---
name: OpenFE
description: Use this skill to compute binding free energy using OpenFE, a python package for alchemical free energy calculations (https://github.com/OpenFreeEnergy/openfe). 
license: MIT license. LICENSE.txt has complete terms.
---

# Computing Binding Free Energies with OpenFE: 

This master skill orchestrates 4 required steps, described as sub-skills, that need be executed sequentially. Additionally, there are optional steps to allow for more customization. Each step typically submits job(s) to the HPC scheduler (e.g., SLURM). User needs to configure the environment and SLURM settings (QoS names, etc.) in the first-time setup.

## First-time setup: 
If this is a new installation, the agent MUST complete the setup checklist before executing any of the 4 required steps (Sub-skill instruction file: `0_first_time_setup.md`). 

## The 4 Required Steps

To execute any of these steps, you must read its corresponding markdown instruction file located in this directory, and follow those specialized instructions exactly.

1. **Input Validation** (Sub-skill instruction file: `1_validate_input.md`)
2. **Plan Network** (Sub-skill instruction file: `2_plan_rbfe_network.md`)
3. **Run RBFE Calculations** (Sub-skill instruction file: `3_submit_jobs.md`)
4. **Gather Results (dG, ddG)** (Sub-skill instruction file: `4_gather_results.md`)

## Optional Steps:
a. **Plot Correlations** (Sub-skill instruction file: `a_plot_correlations.md`)
b. **Set up pre-screen by ID suffix** (Sub-skill instruction file: `b_setup_prescreen_by_ID_suffix.md`)

## Execution Instructions for the Agent

When the user asks you to start or resume an OpenFE RBFE pipeline:

1. **Check if a first-time setup needs to be completed.** Run this command and read the output:
   ```bash
   SKILL_DIR="$HOME/.claude/skills/openfe_skill"
   source "$SKILL_DIR/scripts/hpc_config.sh" && echo "SITE_CONFIGURED=$SITE_CONFIGURED"
   ```
   - If the output is `SITE_CONFIGURED=true`, setup is already done; proceed to step 2.
   - If the output is `SITE_CONFIGURED=false` or empty: **STOP. Do NOT proceed to any pipeline step.** Read `0_first_time_setup.md` and complete the interview and configuration process before doing anything else.
2. **Identify the current step by examing the files in the work directory, including job log files.** 
3. **Execute the step specified by user.** Read the associated `.md` file listed above (e.g., `1_validate_input.md` for Step 1) and follow those instructions explicitly.
4. **Stop and Wait.** SLURM jobs (`sbatch`) can take some time to run. After submitting a job:
   - Inform the user of the submitted job ID.
   - Instruct the user to prompt you again once the job output matches the success criteria defined in the step's `.md` file.
   - Update job log files with any relevant information (e.g., job IDs, timestamps) for the user to track progress.

*Do not attempt to execute Steps 2, 3, or 4 until the user provides the instructions*

For a detailed walkthrough, see [skill_walkthrough.md](./skill_walkthrough.md).
