---
name: OpenFE Results Analysis - Plotting Correlation
description: Instructions for plotting and calculating correlation and error.
---

# Plotting Correlation

This analysis step takes as input both OpenFE predicted data and measured data, merge them into a single data table, then plot ddG, and if appropriate, dG linear regressions

### Prerequisites
* OpenFE result from Step 4: 'results_ddg.tsv'
* Measured data in a csv file, for example, named as measured.csv. It may include more columns than molecule ID and measured Ki data.   

### Gathering Command


```bash
SKILL_DIR="$HOME/.claude/skills/openfe_skill"
source "$SKILL_DIR/scripts/hpc_config.sh"
load_openfe_env

$SKILL_DIR/scripts/plot_ddG_comparison_ofe.py -exp measured.csv -pred results_ddg.tsv -exp_ID 'ID' -exp_Ki 'Ki' -out ddG_comparison
# or, if measured.csv contains a column for dG values in kcal/mol unit, already computed based on Ki or IC50 data 
$SKILL_DIR/scripts/plot_ddG_comparison_ofe.py -exp measured.csv -pred results_ddg.tsv -exp_ID 'ID' -exp_dG 'EXP_dG [kcal/mol]' -out ddG_comparison
```

### Expected Output Files
The command will generate several summary files in the current folder:

1. **`results_ddg.tsv`**: a result directly from Step 4: Gather the results. 
2. **`measured.csv`**: a file shoing measured data indexed by the argument molecule ID. If Ki data in [uM] unit are provided, the script will do the conversion to dG [kcal/mol]

results_ddg.tsv file looks like this:
```
ligand_i	ligand_j	DDG(i->j) (kcal/mol)	uncertainty (kcal/mol)
MyID_4677	MyID_9922	-0.5	0.2
MyID_6299	MyID_9920	-0.13	0.04
MyID_6299	MyID_1417	0.85	0.07
MyID_9914	MyID_7122	0.7	0.1
```

measured.csv file looks like this:
```
ID,Column1,Kd [uM],Column2
MyID_4677,SKS,0.3,p
MyID_6299,SKS,0.075,p
```

---

**Agent Instructions for this Step:**
1. Append the output of this step to the log file (eg. Job.log), and create that file if it doesn't exist.
