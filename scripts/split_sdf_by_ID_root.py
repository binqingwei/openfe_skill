#!/usr/bin/env python3
"""Read an SDF file and group molecules by title root (before last '_' suffix).
Write groups with multiple members to separate SDF files in a 'prescreen' folder."""

import argparse
import os
from collections import defaultdict

from rdkit import Chem
Chem.SetDefaultPickleProperties(Chem.PropertyPickleOptions.AllProps)

def prescreen_by_ID_suffix(sdf_file, outdir):
    suppl = Chem.SDMolSupplier(sdf_file, removeHs=False)

    # Group molecules by root ID
    groups = defaultdict(list)
    for mol in suppl:
        if mol is None:
            continue
        title = mol.GetProp("_Name")
        # Split on last '_' to separate root from suffix
        if "_" in title:
            root = title.rsplit("_", 1)[0]
        else:
            root = title
        groups[root].append(mol)

    # Write out only groups with more than one member
    for root, mols in groups.items():
        if len(mols) > 1:
            group_dir = os.path.join(outdir, root)
            os.makedirs(group_dir, exist_ok=True)
            outfile = os.path.join(group_dir, f"{root}.sdf")
            writer = Chem.SDWriter(outfile)
            for mol in mols:
                writer.write(mol)
            writer.close()
            print(f"Wrote {len(mols)} molecules to {outfile}")

    print("Done.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Split an SDF file into groups by molecule title root ID."
    )
    parser.add_argument("-i", "--input", required=True, help="Input SDF file")
    parser.add_argument("-o", "--outdir", default="prescreen", help="Output directory (default: prescreen)")
    args = parser.parse_args()

    prescreen_by_ID_suffix(args.input, args.outdir)
