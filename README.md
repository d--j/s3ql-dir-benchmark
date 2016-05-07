S3QL Directory Traversal Benchmark
===============================================================================

This repository contains a test script that automates taking timings
for directory traversal performance of a
[S3QL](https://bitbucket.org/nikratio/s3ql) file system.


Run Benchmark in a docker container
-------------------------------------------------------------------------------

Requirements:
- a working docker setup

```shell
git clone https://github.com/d--j/s3ql-dir-benchmark.git s3ql-dir-benchmark
cd s3ql-dir-benchmark
docker build -t s3ql-dir-benchmark .
docker run --rm --privileged --cap-add=MKNOD --cap-add=SYS_ADMIN --device=/dev/fuse -v /tmp:/tmp -P -e BENCHMARK_CONFIG="200/100/1 200/100/2 400/100/1 400/100/2" s3ql-dir-benchmark
```

Run Benchmark without docker
-------------------------------------------------------------------------------

Requirements:
- Linux
- S3QL
- ~10 GB of free space in `/tmp`

```shell
git clone https://github.com/d--j/s3ql-dir-benchmark.git s3ql-dir-benchmark
cd s3ql-dir-benchmark
BENCHMARK_CONFIG="200/100/1 200/100/2 400/100/1 400/100/2" ./run-benchmark.sh
```
