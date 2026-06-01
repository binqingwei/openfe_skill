import string
import click
import pathlib
import logging
import warnings

from functools import partial

from rdkit import Chem
Chem.SetDefaultPickleProperties(Chem.PropertyPickleOptions.AllProps)

import openfe
from openfe.protocols.openmm_rfe.equil_rfe_methods import RelativeHybridTopologyProtocol

from openfe.protocols.openmm_utils.charge_generation import bulk_assign_partial_charges
from openfe.setup.ligand_network_planning import load_fepplus_network
from openfecli.plan_alchemical_networks_utils import plan_alchemical_network_output

from openff.units import unit

import kartograf
from kartograf.filters import (
    filter_ringbreak_changes,
    filter_ringsize_changes,
    filter_whole_rings_only,
)

logger = logging.getLogger(__name__)
warnings.filterwarnings("ignore", message="Partial charges have been provided, these will preferentially be used instead of generating new partial charges")

def gen_ligand_network(smcs):
    """
    Creates the Lomap ligand network using the KartografAtomMapper and
    the Lomap scorer.

    Parameters
    ----------
    smcs : list[SmallMoleculeComponents]
      List of SmallMoleculeComponents of the ligands.

    Returns
    -------
    openfe.LigandNetwork
      The Lomap generated LigandNetwork.
    """
    print("INFO: Generating Lomap Network")
    mapping_filters = [
        filter_ringbreak_changes,  # default
        filter_ringsize_changes,  # default
        filter_whole_rings_only,  # default
    ]
    mapper = kartograf.KartografAtomMapper(
        atom_map_hydrogens=True,
        additional_mapping_filter_functions=mapping_filters,
    )
    # TODO: Change this after LOMAP PR gets merged
    # scorer = openfe.lomap_scorers.default_lomap_score
    scorer = partial(openfe.lomap_scorers.default_lomap_score, charge_changes_score=0.1)
    ligand_network = openfe.ligand_network_planning.generate_lomap_network(
        molecules=smcs, mappers=mapper, scorer=scorer)
    # Raise an error if the network is not connected
    if not ligand_network.is_connected():
        errormsg = ('Error encountered when creating the ligand network. The network'
                    ' is unconnected.')
        raise ValueError(errormsg)
    return ligand_network


def get_alchemical_charge_difference(mapping) -> int:
    """
    Checks and returns the difference in formal charge between state A and B.

    Parameters
    ----------
    mapping : dict[str, ComponentMapping]
      Dictionary of mappings between transforming components.

    Returns
    -------
    int
      The formal charge difference between states A and B.
      This is defined as sum(charge state A) - sum(charge state B)
    """
    chg_A = Chem.rdmolops.GetFormalCharge(
        mapping.componentA.to_rdkit()
    )
    chg_B = Chem.rdmolops.GetFormalCharge(
        mapping.componentB.to_rdkit()
    )

    return chg_A - chg_B


def get_settings():
    """
    Utility method for getting RFEProtocol settings for non charge changing
    transformations.
    These settings mostly follow defaults but use the newest OpenFF 2.2.
    """
    # Are there additional settings we should specify here?
    settings = RelativeHybridTopologyProtocol.default_settings()
    settings.engine_settings.compute_platform = "CUDA"
    # Should we use this new OpenFF version or the default?
    settings.forcefield_settings.small_molecule_forcefield = 'openff-2.2.0'
    # Only run one repeat per input json file
    settings.protocol_repeats = 1
    return settings


def get_settings_charge_changes():
    """
    Utility method for getting RFEProtocol settings for charge changing
    transformations.

    These settings mostly follow defaults but use longer
    simulation times, more lambda windows and an alchemical ion.
    """
    settings = RelativeHybridTopologyProtocol.default_settings()
    settings.engine_settings.compute_platform = "CUDA"
    # Should we use this new OpenFF version or the default?
    settings.forcefield_settings.small_molecule_forcefield = 'openff-2.2.0'
    settings.alchemical_settings.explicit_charge_correction = True
    settings.simulation_settings.production_length = 20 * unit.nanosecond
    settings.simulation_settings.n_replicas = 22
    settings.lambda_settings.lambda_windows = 22
    # Only run one repeat per input json file
    settings.protocol_repeats = 1
    return settings


@click.command
@click.option(
    '--ligands',
    type=click.Path(dir_okay=False, file_okay=True, path_type=pathlib.Path),
    required=True,
    help="Path to the prepared SDF file containing the ligands",
)
@click.option(
    '--pdb',
    type=click.Path(dir_okay=False, file_okay=True, path_type=pathlib.Path),
    required=True,
    help="Path to the prepared PDB file of the protein",
)
@click.option(
    '--edge',
    type=click.Path(dir_okay=False, file_okay=True, path_type=pathlib.Path),
    default=None,
    help="Path to the FEP+ map .edge file that is used to define the network.",
)
@click.option(
    '--ns',
    type=click.INT,
    default=5,
    help="Production length for non-charge changing transformations in nanoseconds.",
)
@click.option(
    '--cofactors',
    type=click.Path(dir_okay=False, file_okay=True, path_type=pathlib.Path),
    default=None,
    help="Path to the prepared cofactors SDF file (optional)",
)
@click.option(
    '--output',
    type=click.Path(dir_okay=True, file_okay=False, path_type=pathlib.Path),
    default=pathlib.Path('network_setup'),
    help="Directory name in which to store the transformation json files",
)
@click.option(
    '--cpus',
    type=click.INT,
    default=1,
    help="Number of CPUs to use for parallelizing tasks (e.g., partial charge generation).",
)
def run_inputs(ligands, pdb, cofactors, output, edge, ns, cpus):
    """
    Generate run json files for RBFE calculations

    Parameters
    ----------
    ligands : pathlib.Path
      A Path to a ligands SDF.
    pdb : pathlib.Path
      A Path to a protein PDB file.
    cofactors : Optional[pathlib.Path]
      A Path to an SDF file containing the system's cofactors.
    output: pathlib.Path
      A Path to a directory where the transformation json files
      and ligand network graphml file will be stored into.
    edge: pathlib.Path
        A Path to an FEP+ map .edge file that is used to define the network
    """
    # Create the output directory -- default to alchemicalNetwork, fail if it exists
    output.mkdir(exist_ok=False, parents=True)
    
    # Create the small molecule components of the ligands
    rdmols = [mol for mol in Chem.SDMolSupplier(str(ligands), removeHs=False)]
    smcs = [openfe.SmallMoleculeComponent.from_rdkit(mol) for mol in rdmols]
    
    # Generate the partial charges securely
    logger.info(f"Generating partial charges for ligands using {cpus} CPUs")
    smcs = bulk_assign_partial_charges(
        molecules=smcs,
        overwrite=False,
        method="am1bcc",
        toolkit_backend="ambertools",
        generate_n_conformers=None,
        nagl_model=None,
        processors=cpus,
    )

    # Following changes suggested by discussions with Hannah 3/7/25
    #   change atom mapper from Lomap to Kartograf
    #   delete my call to atom mapper and inset mapping filters
    mapping_filters = [
       filter_ringbreak_changes,  # default
       filter_ringsize_changes,   # default
       filter_whole_rings_only,   # default
    ]

    atom_mapper = kartograf.KartografAtomMapper(
       atom_map_hydrogens=True,
       additional_mapping_filter_functions=mapping_filters,
    )
    # End of changes suggested by Hannah 

    if edge is None:
        # If no edge file is provided, generate the ligand network
        logger.info("No edge file provided, generating ligand network using Kartograf")
        ligand_network = gen_ligand_network(smcs)
    else:
        # If an edge file is provided, load the ligand network from input .edge file
        ligand_network = load_fepplus_network(
          ligands=smcs,
          mapper=atom_mapper,
          network_file=edge
        )

    # End of changes by Bill Swope

    # Store the ligand network as a graphml file
    with open(output / "ligand_network.graphml", mode='w') as f:
        f.write(ligand_network.to_graphml())

    # Create the solvent and protein components
    solv = openfe.SolventComponent()
    prot = openfe.ProteinComponent.from_pdb_file(str(pdb))

    # If we have cofactors, load them in and assign partial charges
    if cofactors is not None:
        raw_cofactors = [openfe.SmallMoleculeComponent(m)
                         for m in Chem.SDMolSupplier(str(cofactors), removeHs=False)]
        cofactors_smc = bulk_assign_partial_charges(
            molecules=raw_cofactors,
            overwrite=False,
            method="am1bcc",
            toolkit_backend="ambertools",
            generate_n_conformers=None,
            nagl_model=None,
            processors=cpus,
        )

    # Create the AlchemicalTransformations, and storing them to an AlchemicalNetwork
    transformations = []
    for mapping in ligand_network.edges:
        # Get different settings depending on whether the transformation
        # involves a change in net charge
        charge_difference = get_alchemical_charge_difference(mapping)
        if abs(charge_difference) > 1e-3:
            # Raise a warning that a charge changing transformation is included
            # in the network
            wmsg = ("Charge changing transformation between ligands "
                    f"{mapping.componentA.name} and {mapping.componentB.name}. "
                    "A more expensive protocol with 22 lambda windows, sampled "
                    "for 20 ns each, will be used here.")
            warnings.warn(wmsg)
            # Get settings for charge changing transformations
            rfe_settings = get_settings_charge_changes()
        else:
            rfe_settings = get_settings()
            rfe_settings.simulation_settings.production_length = ns * unit.nanosecond
            print("INFO: production length for non-charge changing transformations (ns): ",rfe_settings.simulation_settings.production_length)
        for leg in ['solvent', 'complex']:
            # use the solvent and protein created above
            sysA_dict = {'ligand': mapping.componentA,
                         'solvent': solv}
            sysB_dict = {'ligand': mapping.componentB,
                         'solvent': solv}

            if leg == 'complex':
                sysA_dict['protein'] = prot
                sysB_dict['protein'] = prot
                if cofactors is not None:

                    for cofactor, entry in zip(cofactors_smc,
                                               string.ascii_lowercase):
                        cofactor_name = f"cofactor_{entry}"
                        sysA_dict[cofactor_name] = cofactor
                        sysB_dict[cofactor_name] = cofactor

            sysA = openfe.ChemicalSystem(sysA_dict)
            sysB = openfe.ChemicalSystem(sysB_dict)

            name = (f"{leg}_{mapping.componentA.name}_"
                    f"{mapping.componentB.name}")

            rbfe_protocol = RelativeHybridTopologyProtocol(settings=rfe_settings)
            transformation = openfe.Transformation(
                stateA=sysA,
                stateB=sysB,
                mapping=mapping,
                protocol=rbfe_protocol,
                name=name
            )
            transformations.append(transformation)

    # Create the alchemical network and write it to disk
    alchemical_network = openfe.AlchemicalNetwork(transformations)
    
    plan_alchemical_network_output(
        alchemical_network=alchemical_network,
        ligand_network=ligand_network,
        folder_path=output
    )


if __name__ == "__main__":
    run_inputs() # type: ignore[call-arg]
