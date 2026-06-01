---
name: OpenFE Step 3 - Submit RBFE Jobs
description: Instructions for step 3: Submitting the RBFE simulation jobs to SLURM.
---

# Step 3. Run the RBFE simulations

This step involves submitting the planned transformations to the SLURM scheduler for execution. 

### Prerequisites
* You must be in the folder containing the `network_setup/` subfolder (generated in Step 2).

### Option A: Bulk Submission (Recommended)
To submit all transformations in the network as SLURM jobs, run this bash script:

```bash
SKILL_DIR="$HOME/.claude/skills/openfe_skill"
export SKILL_DIR
$SKILL_DIR/scripts/submit_rbfe_jobs.sh
```

`submit_rbfe_jobs.sh` sources `scripts/hpc_config.sh` itself and applies `SBATCH_TRANSFORM_HYBRID` (default) or `SBATCH_TRANSFORM_SEPTOP` (when called with `s` as the second argument) to every `sbatch` call.

Replica behavior in `submit_rbfe_jobs.sh`:
* **Default:** run **1 replica** per transformation, without CUDA MPS.
* `-rep N`: run **N replicas** per transformation, without CUDA MPS (for example, `-rep 2` or `-rep 3`).
* `-mps3`: run **3 replicas with CUDA MPS** (this is equivalent to the previous default behavior).

Examples:

```bash
# Default: 1 replica, no MPS, Hybrid protocol
$SKILL_DIR/scripts/submit_rbfe_jobs.sh

# 3 replicas, no MPS, Hybrid protocol
$SKILL_DIR/scripts/submit_rbfe_jobs.sh -rep 3

# Legacy mode: 3 replicas with CUDA MPS, Hybrid protocol
$SKILL_DIR/scripts/submit_rbfe_jobs.sh -mps3

# 2 replicas, no MPS, SepTop protocol
$SKILL_DIR/scripts/submit_rbfe_jobs.sh -rep 2 network_setup/transformations s
```

### Option B: Run a Single Transformation (Quickrun)
Alternatively, you can run an individual leg manually using the `openfe quickrun` command:

```bash
openfe quickrun path/to/transformation.json -o results.json -d working-directory
```

**Parameters:**
* `path/to/transformation.json`: Path to one of the transformation files in `network_setup/transformations/`.
* `-o results.json`: The filename for the final output JSON.
* `-d directory/`: The directory where simulation results should be stored.

**Example Command:**
```bash
openfe quickrun transformations/rbfe_lig_ejm_31_solvent_lig_ejm_42_solvent.json -o results/rbfe_lig_ejm_31_solvent_lig_ejm_42_solvent.json -d results/rbfe_lig_ejm_31_solvent_lig_ejm_42_solvent/
```

> [!IMPORTANT]
> When running manually, ensure each leg and repeat has a unique output filename and working directory to avoid overwriting results.

### Hardware Note
By default, jobs run **without Nvidia CUDA Multi-Process Service (MPS)** and submit **1 replica per transformation**. **Use the `-mps3` flag to enable CUDA MPS + 3 replicas**.

---

**Agent Instructions for this Step:**
1. Verify the `network_setup/` directory exists.
2. Submit the jobs using the bulk script unless the user specifies otherwise.
3. **Stop and WAIT.** RBFE simulations are computationally expensive and will take a significant amount of time to complete. 
4. Inform the usepr of the submission and tell them to return once the simulations have finished.
5. Save or update information about this step, the command line executed and the SLURM job ID in a file named Job.log. Create the file if absent.