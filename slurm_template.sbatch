#!/bin/sh
#SBATCH --job-name=preditr
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=100g
#SBATCH --output=preditr_%j.out
#SBATCH --error=preditr_%j.err
#SBATCH --mail-type=ALL

# ==========================
# Define paths and variables
# ==========================
JOB_NAME=<JOB_NAME>            
IMAGE_PATH=<IMAGE_PATH>
INPUT_PATH=<INPUT_CSV>
EDITOR_PATH=<EDITOR_CSV>
INDEXED_GENOME_PATH=<INDEXED_GENOME_DIR>
OUTPUT_PATH=<OUTPUT_DIR>
TEMPORARY_PATH=<SCRATCH_DIR>

ORGANISM=<ORGANISM>            # "human" or "mouse"
THREADS=<NUM_THREADS>          # e.g., 40
OFF_TARGETS=<TRUE_OR_FALSE>    # TRUE or FALSE

# ==========================
# Execute Singularity container
# ==========================
singularity exec --no-home --bind $INPUT_PATH:$INPUT_PATH,$EDITOR_PATH:$EDITOR_PATH,$INDEXED_GENOME_PATH:$INDEXED_GENOME_PATH,$OUTPUT_PATH:$OUTPUT_PATH,$TEMPORARY_PATH:$TEMPORARY_PATH \
$IMAGE_PATH /home/PrEditR.R \
    --job_name $JOB_NAME \
    --input $INPUT_PATH \
    --output $OUTPUT_PATH \
    --editors $EDITOR_PATH \
    --off_targets $OFF_TARGETS \
    --indexed_genome $INDEXED_GENOME_PATH \
    --organism $ORGANISM \
    --threads $THREADS \
    --tmp $TEMPORARY_PATH
