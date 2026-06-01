import string
import click
import pathlib
import logging
import warnings

from rdkit import Chem
Chem.SetDefaultPickleProperties(Chem.PropertyPickleOptions.AllProps)

import openfe
from openfe.protocols.openmm_septop import SepTopProtocol

#from openfe.protocols.openmm_utils.omm_settings import OpenFFPartialChargeSettings
from openfe.protocols.openmm_utils.charge_generation import bulk_assign_partial_charges
from openfe.setup.ligand_network_planning import load_fepplus_network

from openff.units import unit

logger = logging.getLogger(__name__)
warnings.filterwarnings("ignore", message="Partial charges have been provided, these will preferentially be used instead of generating new partial charges")



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
#@click.option(
#    '--ns',
#    type=click.INT,
#    default=5,
#    help="Production length for non-charge changing transformations in nanoseconds.",
#)
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

def create_septop_transformations(ligands, pdb, edge, cofactors, output, cpus):
    """
    Create JSON files for RBFE calculations using the SepTop protocol

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
    # creating the LigandNetwork using hybrid topology protocol's mapper, which is required by the scorer -- tempoary solution
    # alteratively the user can also manually define the edges they want to run when creating the transformations below, without creating a LigandNetwork first.

    #The atom mapping will only be used to score the potential edges, the atom mapping is not used outside of the scorer.
    mapper = openfe.LomapAtomMapper(max3d=1.0, element_change=False)
    scorer = openfe.lomap_scorers.default_lomap_score
    #network_planner = openfe.ligand_network_planning.generate_minimal_spanning_network
    network_planner = openfe.ligand_network_planning.generate_lomap_network

    if edge is None:
        # If no edge file is provided, generate the ligand network
        logger.info("No edge file provided, generating ligand network using lomap.  Atom mapping will only be used to score potential edges, and is not used outside of the scorer.")
        ligand_network = network_planner(
            ligands=smcs,
            mappers=[mapper],   # use [] according to tutorial  
    #        mapper=mapper,
            scorer=scorer
        )
    else:
        # If an edge file is provided, load the ligand network from input .edge file
        logger.info(f"Edge file provided, loading ligand network from {edge}")
        ligand_network = load_fepplus_network(
          ligands=smcs,
          mapper=mapper,
          network_file=edge
        )
    
    # If we have cofactors, load them in and assign partial charges
    cofactors_smc = []
    if cofactors is not None:
        logger.info(f"Cofactors file provided, loading cofactors from {cofactors}")
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

    # save the ligand network to a graphml file, which can be visualized using tools like Cytoscape or Gephi
    with open(output/"ligand_network.graphml", mode='w') as f:
        f.write(ligand_network.to_graphml())

    settings = SepTopProtocol.default_settings()
    # Run only a single repeat
    settings.protocol_repeats = 1
    # Change the min and max distance between protein and ligand atoms for Boresch restraints to avoid periodicity issues
    settings.complex_restraint_settings.host_min_distance = 0.5 * unit.nanometer
    settings.complex_restraint_settings.host_max_distance = 1.5 * unit.nanometer
    # Set the equilibration time to 2 ns (which is also the default)
    settings.solvent_simulation_settings.equilibration_length = 2000 * unit.picosecond
    settings.complex_simulation_settings.equilibration_length = 2000 * unit.picosecond

    # to speed up SepTop calculations, set this flag to True:
    settings.alchemical_settings.disable_alchemical_dispersion_correction = True

    protocol = SepTopProtocol(settings)


    # creating the AlchemicalNetork using ligand_network.edges
    # creating ChemicalSystems
    # defaults are water with NaCl at 0.15 M
    solvent = openfe.SolventComponent()
    protein = openfe.ProteinComponent.from_pdb_file(str(pdb))

    transformations = []
    for edge in ligand_network.edges:
        # use the solvent and protein created above
        sysA_dict = {'ligand': edge.componentA,
                    'protein': protein,
                    'solvent': solvent}
        sysB_dict = {'ligand': edge.componentB,
                    'protein': protein,
                    'solvent': solvent}
        
        if cofactors is not None:

                    for cofactor, entry in zip(cofactors_smc,
                                               string.ascii_lowercase):
                        cofactor_name = f"cofactor_{entry}"
                        sysA_dict[cofactor_name] = cofactor
                        sysB_dict[cofactor_name] = cofactor

        # we don't have to name objects, but it can make things (like filenames) more convenient
        sysA = openfe.ChemicalSystem(sysA_dict, name=f"{edge.componentA.name}")
        sysB = openfe.ChemicalSystem(sysB_dict, name=f"{edge.componentB.name}")

        prefix = "rbfe_"  # prefix is only to exactly reproduce CLI

        transformation = openfe.Transformation(
            stateA=sysA,
            stateB=sysB,
            mapping=None,
            protocol=protocol,  # use protocol created above
            name=f"{prefix}{sysA.name}_{sysB.name}"
        )
        transformations.append(transformation)

    network = openfe.AlchemicalNetwork(transformations)

    # write out each transformation to disk, so that they can be run independently using the openfe quickrun command
    # first we create the directory
    transformation_dir = pathlib.Path(output/"transformations")
    transformation_dir.mkdir(exist_ok=True)

    # then we write out each transformation
    for transformation in network.edges:
        transformation.to_json(transformation_dir / f"{transformation.name}.json")


if __name__ == "__main__":
    create_septop_transformations() # type: ignore[call-arg]