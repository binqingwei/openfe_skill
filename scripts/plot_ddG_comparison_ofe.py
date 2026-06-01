import argparse
import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from scipy.stats import spearmanr, kendalltau, pearsonr

def main():
    parser = argparse.ArgumentParser(
        description="Plot a comparison between experimentally measured ddG and predicted ddG."
    )
    parser.add_argument(
        "-exp",
        required=True,
        help="Path to the experimental Ki data file (exp_Ki.csv, comma or tab separated)."
    )
    parser.add_argument(
        "-pred",
        required=True,
        help="Path to the OpenFE results_ddG.tsv file (comma or tab separated)."
    )
    # add argument for the molecule ID column name in the input exp ddG file
    parser.add_argument(
        "-exp_ID",
        required=True,
        help="Molecule ID column name in the input exp ddG file."
    )
    # add argument for the Ki column name in the input Ki data file
    parser.add_argument(
        "-exp_Ki",
        required=False,
        help="Optional Ki column name in the input exp ddG file."
    )
    # add argument for the Ki column name in the input Ki data file
    parser.add_argument(
        "-exp_dG",
        required=False,
        help="Optional ddG column name in the input exp ddG file."
    )
    # add argument for the output files' prefix
    parser.add_argument(
        "-out",
        required=True,
        help="Output files' prefix."
    )
    args = parser.parse_args()

    # Read the experimental and prediction data files.
    exp_sep = '\t' if args.exp.lower().endswith('.tsv') else ','
    pred_sep = '\t' if args.pred.lower().endswith('.tsv') else ','
    exp_data = pd.read_csv(args.exp, sep=exp_sep, comment='#')
    pred_data = pd.read_csv(args.pred, sep=pred_sep)

    # Clean prediction data: convert DDG and uncertainty to numeric, drop non-numeric rows
    pred_data['DDG(i->j) (kcal/mol)'] = pd.to_numeric(pred_data['DDG(i->j) (kcal/mol)'], errors='coerce')
    pred_data['uncertainty (kcal/mol)'] = pd.to_numeric(pred_data['uncertainty (kcal/mol)'], errors='coerce')
    pred_data.dropna(subset=['DDG(i->j) (kcal/mol)', 'uncertainty (kcal/mol)'], inplace=True)

    # if the exp_Ki column is provided, calculate exp_ddG from exp_Ki, otherwise use the exp_ddG column directly as exp_ddG
    if args.exp_Ki:
        # Calculate pKi from measured Ki data using pKi = -log10(Ki * 10**(-6))
        exp_data['exp_pKi'] = - np.log10(exp_data[args.exp_Ki].astype(float) * 10**(-6))
        # Calculate dG from pKi using this equation:  dG = RTln(Ki) = -2.303 * R * T * pKi
        R = 1.987 / 1000  # kcal/(mol·K)
        T = 298.15  # K
        exp_data['exp_dG'] = - 2.303 * R * T * exp_data['exp_pKi']
    elif args.exp_dG:
        exp_data['exp_dG'] = exp_data[args.exp_dG].astype(float)
    else:
        raise ValueError("Either --exp_Ki or --exp_ddG must be provided in the input exp ddG file.")

    # In the openfe ddG results, 
    # columns "ligand_i" and "ligand_j" are the ID's of two molecules
    # column "DDG(i->j) (kcal/mol)" is the ddG of changing from molecule i to molecule j
    # column "uncertainty (kcal/mol)" is the uncertainty of ddG of changing from molecule i to molecule j
    # both ligand_i and ligand_j are in the exp_data[args.exp_ID]
    # find the corresponding exp_dG values from exp_data for ligand_i and ligand_j, name them exp_dG_i and exp_dG_j
    # calculate exp_ddG = exp_dG_j - exp_dG_i
    # append exp_dG_i, exp_dG_j and exp_ddG to pred_data 
    pred_data['exp_dG_i'] = pred_data['ligand_i'].apply(lambda x: exp_data[exp_data[args.exp_ID] == x]['exp_dG'].values[0] if not exp_data[exp_data[args.exp_ID] == x].empty else np.nan)
    pred_data['exp_dG_j'] = pred_data['ligand_j'].apply(lambda x: exp_data[exp_data[args.exp_ID] == x]['exp_dG'].values[0] if not exp_data[exp_data[args.exp_ID] == x].empty else np.nan)
    pred_data['exp_ddG'] = pred_data['exp_dG_j'] - pred_data['exp_dG_i']

    # Filter out rows where experimental data was missing
    pred_data.dropna(subset=['exp_ddG'], inplace=True)

    # Calculate correlation coefficients between exp_dG and c_dG.
    spearman_coef, _ = spearmanr(pred_data['exp_ddG'], pred_data['DDG(i->j) (kcal/mol)'])
    kendall_coef, _ = kendalltau(pred_data['exp_ddG'], pred_data['DDG(i->j) (kcal/mol)'])
    pearson_coef, _ = pearsonr(pred_data['exp_ddG'], pred_data['DDG(i->j) (kcal/mol)'])

    # Calculate Mean Absolute Error (MAE) and Root Mean Square Error (RMSE) between exp_dG and c_dG.
    mae = np.mean(np.abs(pred_data['exp_ddG'] - pred_data['DDG(i->j) (kcal/mol)']))
    rmse = np.sqrt(np.mean((pred_data['exp_ddG'] - pred_data['DDG(i->j) (kcal/mol)']) ** 2))

    # Calculate the 25th percentile thresholds for exp_dG and c_dG.
    # exp_threshold = pred_data['exp_ddG'].quantile(0.25)
    # c_threshold = pred_data['DDG(i->j) (kcal/mol)'].quantile(0.25)

    # Create the plot.
    plt.figure(figsize=(8, 6))
    # Get the single minimum value of exp_dG and c_dG.
    min_value = min(pred_data['exp_ddG'].min(), pred_data['DDG(i->j) (kcal/mol)'].min())
    max_value = max(pred_data['exp_ddG'].max(), pred_data['DDG(i->j) (kcal/mol)'].max())

    # Use regplot to plot the scatter and regression line.
    sns.regplot(
        x='exp_ddG',
        y='DDG(i->j) (kcal/mol)',
        data=pred_data,
        color='blue',      # Solid blue regression line.
        ci=95              # 95% confidence interval shown in a light-blue shade.
    )
    
    # Set the x and y axis limits to the range of min_value to max_value.
    #plt.xlim(min_value-0.1, max_value+0.1)
    #plt.ylim(min_value-0.1, max_value+0.1)

    # Add error bars for the predicted dG values.
    plt.errorbar(
        pred_data['exp_ddG'],
        pred_data['DDG(i->j) (kcal/mol)'],
        yerr=pred_data['uncertainty (kcal/mol)'],
        fmt='o',
        ecolor='gray',
        elinewidth=1,
        capsize=2,
        capthick=1
    )
    # Draw dashed lines at the 25th percentile thresholds.
    #plt.axvline(exp_threshold, linestyle='--', color='black', 
    #            label=f'25th percentile exp_dG: {exp_threshold:.2f}')
    #plt.axhline(c_threshold, linestyle='--', color='red', 
    #            label=f'25th percentile c_dG: {c_threshold:.2f}')
    
    # Add the title with correlation coefficients.
    title="ddG Comparison: measured vs OpenFE"
    plt.title(f"{title}\nN={len(pred_data)}\nSpearman: {spearman_coef:.2f}, Kendall: {kendall_coef:.2f}, Pearson: {pearson_coef:.2f}\nMAE: {mae:.2f}, RMSE: {rmse:.1f}")
    ## to show a plot that is squared : the x and y axes have the same scale, so that a perfect correlation would lie on a 45 degree line.
    #plt.gca().set_aspect('equal', adjustable='datalim')
    plt.xlabel("Measured ddG")
    plt.ylabel("Predicted ddG")
    plt.grid(True, which='both', linestyle='--', linewidth=0.5)
    plt.gca().xaxis.set_major_locator(plt.MultipleLocator(0.5))
    plt.gca().yaxis.set_major_locator(plt.MultipleLocator(0.5))
    plt.legend()
    plt.tight_layout()
    plt.savefig(f"{args.out}.png")
    # plt.show()

    # save the data to a tsv file
    exp_data.to_csv(f"{args.out}_exp.tsv", sep='\t', index=False)
    pred_data.to_csv(f"{args.out}_pred.tsv", sep='\t', index=False)

if __name__ == "__main__":
    main()
