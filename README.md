# LLM skill for running openfe (hybrid or septop protocol) to predict relative binding free energy
# Use an IDE (VSCode, Cursor, Antigravity, etc) to connect via ssh to a remote HPC host running SLURM scheduler. In a terminal, run the below installation commands. Then in a chat window, enter "go to my_folder, use openfe" to start a job. 
  
```bash
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone https://github.com/Genentech/openfe_skill.git
```

All site-specific settings -- environment (`module load ` / `conda activate `) and SLURM directives (account, partition, QoS, GPU type, memory, etc) -- are isolated in a single file that include all the steps:

```
scripts/hpc_config.sh
```

When using the skill for the first time, the agent will interview user and edit the above file accordingly. This is done only once.
