---
name: Validate input protein [cofactor]
description: input validation using OpenFE CLI.
---

# Step 1. Validate input pdb file by running a short MD simulation

Assume input files are these by default:
a. ligands.sdf
b. protein.pdb
c. cofactors.sdf (this file is optional)

This step test if the input protein pdb file has any known problems, for example, invalid names for teriminal capping groups. It does so by running a short MD simulation using the protein file, and the cofactors file if provided.

The command is:

```bash
SKILL_DIR="$HOME/.claude/skills/openfe_skill"
export SKILL_DIR
source "$SKILL_DIR/scripts/hpc_config.sh"
sbatch "${SBATCH_INPUT_VALIDATION[@]}" \
    $SKILL_DIR/scripts/run_input_validation_cv.sh protein.pdb cofactors.sdf
```

All SLURM directives (account, partition, GPU, walltime, memory, output files) come from the `SBATCH_INPUT_VALIDATION` array in `scripts/hpc_config.sh` -- edit that file to adapt to a different cluster.

If validation is completed successfully, the job's `input_validation_$JOBID.out` file should look like this at the end:

```
Protein file: protein.pdb

SIMULATION COMPLETE
```

If validation failed, show user the error message(s) from the `.err` file.

**Agent Instructions for this Step:**
1. Do not copy the folder "scripts" to the working folder.  
2. Save or update information about this step, the command line executed and the SLURM job ID in a file named Job.log. Create the file if absent.