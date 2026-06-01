---
name: OpenFE Step 4 - Gather Results
description: Instructions for step 4: Gathering calculation results (dG and ddG) into a single report.
---

# Step 4. Gather the results

This final step compiles the simulation data from multiple transformations and replicates into a summary report.

### Prerequisites
* Simulation results from Step 3 must be in the `results/` folder.
* You must run the gathering command from the folder containing both the `network_setup/` and `results/` subdirectories.

### Gathering Command
To compile the $\Delta G$ (dg) and $\Delta\Delta G$ (ddg) estimates, run the following SLURM command:

```bash
SKILL_DIR="$HOME/.claude/skills/openfe_skill"
export SKILL_DIR
source "$SKILL_DIR/scripts/hpc_config.sh"
sbatch "${SBATCH_GATHER_RESULTS[@]}" $SKILL_DIR/scripts/run_gather_results.sh
```

All SLURM directives come from `SBATCH_GATHER_RESULTS` in `scripts/hpc_config.sh`.

### Expected Output Files
The command will generate several summary files in the current folder:

1. **`results_ddg.tsv`**: Reports pairs of *ligand_i* and *ligand_j*, the calculated relative free energy $\Delta\Delta G(i \rightarrow j) = \Delta G(j) - \Delta G(i)$, and its uncertainty.
2. **`results_dg.tsv`**: Reports the maximum likelihood estimate (MLE) of the absolute free energy for each ligand and its associated uncertainty. 
    * *Note: This file is only created if there are at least two edges for each molecule in the network. For simple "Star" maps, this result is skipped.*

results_ddg.tsv file looks like this:
```
ligand_i	ligand_j	DDG(i->j) (kcal/mol)	uncertainty (kcal/mol)
MyID_4677	MyID_9922	-0.5	0.2
MyID_6299	MyID_9920	-0.13	0.04
MyID_6299	MyID_1417	0.85	0.07
MyID_9914	MyID_7122	0.7	0.1
```

results_dg.tsv file looks like this:
```
ligand  DG(MLE) (kcal/mol)  uncertainty (kcal/mol)
MyID_4677  -0.09  0.05
MyID_6299  0.7   0.1
```

---

**Agent Instructions for this Step:**
1. Verify both `network_setup/` and `results/` exist.
2. Submit the `run_gather_results.sh` script via `sbatch`.
3. **Wait for completion.** This step is relatively fast compared to simulations but still runs as a SLURM job.
4. Once finished, see `results_dg.tsv` (or `results_dg.tsv`) 
5. Save or update the log file (eg. Job.log)
