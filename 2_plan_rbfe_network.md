---
name: OpenFE Step 2 - Plan Network
description: Instructions for step 2 of OpenFE RBFE calculation: Planning the relative binding free energy (RBFE) network.
---

# Step 2. Plan relative binding free energy (rbfe) network.

The command to plan the network is:

```bash
SKILL_DIR="$HOME/.claude/skills/openfe_skill"
export SKILL_DIR
source "$SKILL_DIR/scripts/hpc_config.sh"
sbatch "${SBATCH_PLAN_RBFE_NETWORK[@]}" \
    $SKILL_DIR/scripts/run_plan_rbfe_network.sh --ligands ligands.sdf --pdb protein.pdb [optional arguments]
```

All SLURM directives come from `SBATCH_PLAN_RBFE_NETWORK` in `scripts/hpc_config.sh`.

Where the optional arguments include:
* `--cofactors cofactor.sdf` : Provide a cofactor file if necessary.
* `--edge fepplus.edge` : provides an optional FEP+ edge file, skipping the network creation by openfe tools.
* `--ns 2` : specify a production stage simulation length of 2 ns. The default is 5 ns.
* `--output` : output folder name
* `--ns` : for Hybrid Topology protocol, the length of production simulation in nanoseconds
* `--protocol` : 'h' for Hybrid Topology protocol (default), or 's' for SepTop protocol 

Note: the default behaviour is to use three repeats to calculate the uncertainty (i.e. standard deviation) in an estimate.
Planning the campaign may take some time even when running on multiple cores due to the complex series of tasks involved:
* partial charges are generated for each of the ligands to ensure reproducibility, by default this requires a semi-empirical quantum chemical calculation to calculate am1bcc charges
* atom mappings are created and scored based on the perceived difficulty for all possible ligand pairs
* an optimal network is extracted from all possible pairwise transformations which balances edge redundancy and the total difficulty score of the network. This step will be skipped if user provides an .edge file from FEP+ system setup.

This will result in a directory called `network_setup/`, which is structured like this:

```
network_setup
├── ligand_network.graphml
├── network_setup.json
└── transformations/
    ├── rbfe_lig_ejm_31_complex_lig_ejm_42_complex.json
    ├── rbfe_lig_ejm_31_complex_lig_ejm_46_complex.json
...
```

The `ligand_network.graphml` file describes the network of ligands connected by atom mappings. We can visualize this network with an interactive viewer using this:

```bash
openfe view-ligand-network network_setup/ligand_network.graphml
```

**Agent Instructions for this Step:**
1. Determine the necessary arguments (ligands, pdb, and any optional cofactors, edges, or ns lengths).
2. Run the `sbatch` command with the appropriate flags.
3. Stop and WAIT for the SLURM job to finish. Do not proceed until `network_setup/ligand_network.graphml` is successfully generated and checked.
4. Save or update information about this step, the command line executed and the SLURM job ID in a file named Job.log. Create the file if absent.
