#!/bin/bash

# check whether the required environment variables are set
if [ -z $TASKS_PER_BATCH ] || [ -z $OUTPUT_S3_PREFIX ]; then
  echo "Error: The variables \$TASKS_PER_BATCH and \$OUTPUT_S3_PREFIX must be set."
  exit 1
fi
if [ -z $SLURM_NPROCS ] || [ -z $SLURM_PROCID ]; then
  echo "Error: The variables \$SLURM_NPROCS and \$SLURM_PROCID must be set. Not running in slurm?"
  exit 1
fi

# iterate over task folders (use $SLURM_PROCID to determine which ones)

ITER=0

while :
do

BATCH_ID=$(( ($ITER * $SLURM_NPROCS + $SLURM_PROCID) / $TASKS_PER_BATCH ))
TASK_ID=$(( ($ITER * $SLURM_NPROCS + $SLURM_PROCID) % $TASKS_PER_BATCH ))

# If we get to a task folder that doesn't exist, it's time to finish.
if [ ! -d $BATCH_ID/$TASK_ID ]; then
  echo "Task $SLURM_PROCID finished in iteration $ITER: next task $BATCH_ID/$TASK_ID does not exist."
  exit 0
fi

echo "Task $SLURM_PROCID iteration $ITER: processing $BATCH_ID/$TASK_ID."

# Pull the input files from LUMI-O
echo 'downloading input files' > $BATCH_ID/$TASK_ID/status
cat $BATCH_ID/$TASK_ID/input.paths | while read INPUTPATH; do
  s3cmd --progress get $INPUTPATH $BATCH_ID/$TASK_ID/ &> $BATCH_ID/$TASK_ID/log.txt
done

# Process the files with warc2text
mkdir -p $BATCH_ID/$TASK_ID/out
echo 'running warc2text' > $BATCH_ID/$TASK_ID/status
warc2text --encoding-errors replace -f html,metadata --jsonl --compress zstd \
          --compress-level 9 --skip-text-extraction --classifier skip \
          -o $BATCH_ID/$TASK_ID/out $BATCH_ID/$TASK_ID/*.warc.gz \
          2>> $BATCH_ID/$TASK_ID/log.txt

# cleanup the input files
rm $BATCH_ID/$TASK_ID/*.warc.gz

echo 'ready for upload' > $BATCH_ID/$TASK_ID/status

# In each batch, task 0 is responsibile for concatenating the output
# of all tasks and putting it to LUMI-O.
if [ $TASK_ID -eq 0 ]; then
  #  wait for all other tasks in this batch to complete warc2text
  while [ $(grep 'ready for upload' $BATCH_ID/*/status | wc -l) -ne $TASKS_PER_BATCH ]; do
    sleep 5;
  done
  
  # simultaneously concatenate and upload the outputs
  echo 'uploading output' > $BATCH_ID/$TASK_ID/status
  cat $BATCH_ID/*/out/html.zst \
  | s3cmd --progress put --multipart-chunk-size-mb=100 - $OUTPUT_S3_PREFIX/$BATCH_ID/html.zst \
  &>> $BATCH_ID/$TASK_ID/log.txt
  cat $BATCH_ID/*/out/metadata.zst \
  | s3cmd --progress put - $OUTPUT_S3_PREFIX/$BATCH_ID/metadata.zst \
  &>> $BATCH_ID/$TASK_ID/log.txt
else
  # If you're not task 0, wait for task 0 to complete the upload.
  # Don't start new tasks yet because first we need to clean up after this
  # batch, so that the disk space usage remains under control.
  while [ -z $(grep 'done' $BATCH_ID/0/status) ]; do
    sleep 10
  done
fi

rm -rf $BATCH_ID/$TASK_ID/out
echo 'done' > $BATCH_ID/$TASK_ID/status

ITER=$(($ITER + 1))

done
