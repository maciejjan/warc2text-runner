#!/bin/bash

BATCH_SIZE=$1
TASKS_PER_BATCH=$2

PREFIX=paths

if [ -z $BATCH_SIZE ] || [ -z $TASKS_PER_BATCH ]; then
  echo "usage: $0 BATCH_SIZE TASKS_PER_BATCH < LIST_OF_PATHS"
  exit 1
fi

# Split the list of paths into batches
split -d -l $BATCH_SIZE - $PREFIX.

# Make one directory per batch and split the batches into tasks.
for BATCH_INPUT_FILE in $PREFIX.*; do
  BATCH_ID=$((10#${BATCH_INPUT_FILE##$PREFIX.}))
  mkdir -p $BATCH_ID
  mv $BATCH_INPUT_FILE $BATCH_ID/$PREFIX
  split -d -n l/$TASKS_PER_BATCH $BATCH_ID/$PREFIX $BATCH_ID/$PREFIX.
  for TASK_INPUT_FILE in $BATCH_ID/$PREFIX.*; do
    TASK_ID=$((10#${TASK_INPUT_FILE##$BATCH_ID/$PREFIX.}))
    mkdir -p $BATCH_ID/$TASK_ID
    mv $TASK_INPUT_FILE $BATCH_ID/$TASK_ID/input.paths
  done
  rm $BATCH_ID/$PREFIX
done

