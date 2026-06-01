---
name: OpenFE Pre-screen - Set up by Ligand ID Suffixes
description: Instructions for setting up pre-screen folders by grouping ligands that share the same ID root but differ in suffix.
---

# Set up Pre-screen Based on Ligand ID Suffixes

This optional step identifies ligands whose titles share the same root ID but differ by a suffix (separated by `_`), and writes each group into a separate folder for independent RBFE pre-screening.

For example, if `ligands_expanded.sdf` contains molecules titled `MyID7672_1`, `MyID7672_2`, and `MyID4443_1`, `MyID4443_2`, this step will create:
```
prescreen/
  MyID7672/MyID7672.sdf   (contains MyID7672_1 and MyID7672_2)
  MyID4443/MyID4443.sdf   (contains MyID4443_1 and MyID4443_2)
```

Molecules without a `_` suffix (ie. without multiple variants) are skipped.

### Prerequisites
* An SDF file containing ligands with titles that may have `_` suffixes (e.g., `ligands_expanded.sdf`)
* A protein structure file (`protein.pdb`) in the current directory
* Optionally, `cofactors.sdf` and/or `map.edge` in the current directory
* module load openfe, which include rdkit
### Command

```bash
SKILL_DIR="$HOME/.claude/skills/openfe_skill"
source "$SKILL_DIR/scripts/hpc_config.sh"
load_openfe_env

python $SKILL_DIR/scripts/split_sdf_by_ID_root.py -i ligands_expanded.sdf -o prescreen

# Copy protein.pdb and optional files into each subfolder
for d in prescreen/*/; do
    cp protein.pdb "$d"
    [ -f cofactors.sdf ] && cp cofactors.sdf "$d"
    [ -f map.edge ] && cp map.edge "$d"
done
```

**Arguments:**
- `-i / --input` (required): Input SDF file
- `-o / --outdir` (optional): Output directory (default: `prescreen`)

### Expected Output
- A `prescreen/` directory containing one subfolder per root ID
- Each subfolder contains an SDF file named `<root_ID>.sdf` with all molecules sharing that root
- Each subfolder also contains a copy of `protein.pdb`, and `cofactors.sdf` / `map.edge` if present

### What to Do Next
Each subfolder under `prescreen/` can be used as an independent RBFE calculation directory, already containing the ligand SDF and protein PDB. Proceed with the standard OpenFE workflow (Steps 1-4) within each.

---

**Agent Instructions for this Step:**
1. Verify the input SDF file exists.
2. Run the `split_sdf_by_ID_root.py` script with the appropriate arguments.
3. Report the groups found and the files written.
4. Append the output to the log file (e.g., Job.log).
