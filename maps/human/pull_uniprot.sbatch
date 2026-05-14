#!/usr/bin/env bash
#SBATCH --partition=compute
#SBATCH --job-name=pull_uniprot
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=5g
#SBATCH --time=24:00:00

module load R/4.4.1
Rscript pull_uniprot.R

