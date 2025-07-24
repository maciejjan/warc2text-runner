#!/bin/bash
#SBATCH --account=project_462000827
#SBATCH --partition=small
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=1750
#SBATCH --time=06:00:00


TASKS_PER_BATCH=$1
OUTPUT_S3_PREFIX=$2

if [ -z $TASKS_PER_BATCH ] || [ -z $OUTPUT_S3_PREFIX ]; then
  echo "usage: $0 TASKS_PER_BATCH OUTPUT_S3_PREFIX"
  exit 1
fi

module use /projappl/project_462000828/EasyBuild/modules/LUMI/24.03/partition/C/
module load lumio
module load LUMI/24.03
module load nlpl-warc2text/1.3.0

export TASKS_PER_BATCH
export OUTPUT_S3_PREFIX

srun bash task.sh
