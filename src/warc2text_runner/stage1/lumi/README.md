# Running warc2text on LUMI

## 0. Setup

First, set up LUMI-O access:
```
module load lumio
export LUMIO_S3_ACCESS=<your access token>
export LUMIO_S3_SECRET=<your secret>
lumio-conf --project-number 462000828 --noninteractive
```

Then, add the path to the scripts directory to `$PATH` so that `task.sh`
can be called from anywhere. E.g. in the repo root directory:
```
export PATH="$PWD/src/warc2text-runner/stage1/lumi:$PATH"
```

Finally, set up a directory for temporary data on `/scratch` and **change
into it** (all further scripts assume that it's the current
directory). For example:
```
mkdir -p /scratch/project_462000828/$USER/warc2text-lumi
cd /scratch/project_462000828/$USER/warc2text-lumi
```

## 1. Get the WARC paths

```
get_warc_paths.sh s3://cc-main-2025-05.lst > paths
```

## 2. Split the paths into batches and tasks

```
prepare_tasks.sh 1000 32 < paths
```

The first parameter is the batch size (1000) and the second the number
of processes per batch. The latter should be a power of 2, so that if we
run 128 processes per node (the maximum), entire batches can be processed
per node. 32 seems to be the optimal tradeoff - for larger values,
the output data upload might take longer than the processing.

## 3. Run the processing

Before submitting the batch job, edit the slurm script and adjust the
number of nodes and allocated time. With 32 processes per node, one node
can process 8 batches (1000 input files each) in parallel and needs
around 3-4 hours for one such "round".

Then, submit the job:
```
sbatch <path to this repo>/src/warc2text-runner/stage1/lumi/run_warc2text.sh 32 s3://test/stage1-lumi-test
```

The last argument is the LUMI-O prefix under which the results will be uploaded.

