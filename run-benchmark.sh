#!/bin/bash

BENCHMARK_CONFIG=${BENCHMARK_CONFIG:-200/100/1 200/100/2 400/100/1 400/100/2}
NUM_REPEATS=${NUM_REPEATS:-10}
LAST_NUM_DIRS=0
LAST_NUM_FILES=0

RUNDIR=$(mktemp -d)

read -r -d '' AWK_PROGRAM_CURRENT <<'EOF'
END {
  printf "%.3fs (user %.3fs, system %.3fs)\n",$1,$2,$3;
}
EOF
read -r -d '' AWK_PROGRAM_AVG <<'EOF'
BEGIN{e=0; U=0; S=0;}
{e+=$1; U+=$2; S+=$3}
END {
  printf "  Average:     %.3fs (user %.3fs, system %.3fs)\n",(e/NR),(U/NR),(S/NR);
}
EOF
read -r -d '' AWK_PROGRAM_AVG2 <<'EOF'
BEGIN{e=0}
{e+=$1}
END {
  printf "%.3f;",(e/NR);
}
EOF

TRAVERSE_FILESYSTEM_SH="$(cd "$(dirname "$0")"; pwd)/traverse_filesystem.sh"

set -e

echo "NUM_PARALLEL;NUM_DIRS;NUM_FILES;NUM_DIRS*NUM_FILES;AVG ext4;AVG $(s3qlctrl --version);" > /tmp/benchmark.csv

cleanup() {
  set +e
  mount | fgrep -q "$RUNDIR/local" && umount "$RUNDIR/local"
  mount | fgrep -q "$RUNDIR/s3ql" && ( umount.s3ql "$RUNDIR/s3ql" || fusermount -u "$RUNDIR/s3ql" )
  rm -rf "$RUNDIR"
  set -e
}
trap cleanup EXIT


hr() {
  echo "----------------------------------------------------------------------"
}
create_filesystems() {
  local LINE
  hr
  echo "CREATE FILESYSTEMS NUM_DIRS=$NUM_DIRS NUM_FILES=$NUM_FILES"
  echo " EXT4"
  echo -n "  Creating loopback ext4 filesystem: "
  SECONDS=0
  truncate "$RUNDIR/local-storage" -s 10G
  mkfs.ext4 -F -b 1024 -i 1024 "$RUNDIR/local-storage" > /dev/null 2>&1
  mkdir "$RUNDIR/local"
  mount "$RUNDIR/local-storage" "$RUNDIR/local"
  echo "${SECONDS}s"
  create_testfiles "$RUNDIR/local" "cp -a"

  echo " S3QL"
  echo -n "  Creating local S3QL filesystem: "
  SECONDS=0
  mkdir "$RUNDIR/s3ql" "$RUNDIR/s3ql-storage"
  echo -ne "1234\n1234\n" | mkfs.s3ql "local://$RUNDIR/s3ql-storage" > /dev/null 2>&1
  echo -ne "1234\n" | mount.s3ql "local://$RUNDIR/s3ql-storage" "$RUNDIR/s3ql" > /dev/null 2>&1
  echo "${SECONDS}s"
  create_testfiles "$RUNDIR/s3ql" "s3qlcp"
  echo "  running s3qlstat on local S3QL filesystem:"
  s3qlstat "$RUNDIR/s3ql" | while read -r LINE; do echo "   $LINE"; done

  hr
}

create_testfiles() {
  (
    local DIR
    local COPY_CMD
    local i
    DIR=$1
    COPY_CMD=$2
    echo -n "  Creating test files in $DIR: "
    SECONDS=0
    cd "$DIR"
    mkdir 0
    for (( i = 0; i < NUM_FILES; i++ )); do
      echo test > 0/$i
    done
    for (( i = 1; i < NUM_DIRS; i++ )); do
      $COPY_CMD 0 $i
    done
    echo "${SECONDS}s"
  )
}

benchmark_directory_traversal() {
  local DIR
  local i
  local NUM_PARALLEL
  DIR="$1"
  NUM_PARALLEL="$2"
  rm -f "$RUNDIR/times.csv"
  for (( i = 1; i <= NUM_REPEATS ; i++ )); do
    /usr/bin/time -f "%e;%U;%S" -o "$RUNDIR/times.csv" -a "$TRAVERSE_FILESYSTEM_SH" "$DIR" "$NUM_PARALLEL" > /dev/null
    printf "  Run %2d / %2d: " "$i" "$NUM_REPEATS"
    awk -F ';' "$AWK_PROGRAM_CURRENT" "$RUNDIR/times.csv"
    sync && echo 3 > /proc/sys/vm/drop_caches
  done
  awk -F ';' "$AWK_PROGRAM_AVG" "$RUNDIR/times.csv"
  awk -F ';' "$AWK_PROGRAM_AVG2" "$RUNDIR/times.csv" >> /tmp/benchmark.csv
}

for RUN in $BENCHMARK_CONFIG; do
  IFS='/' read -r NUM_DIRS NUM_FILES NUM_PARALLEL <<< "$RUN"
  if (( LAST_NUM_DIRS != NUM_DIRS || LAST_NUM_FILES != NUM_FILES)); then
    cleanup
    RUNDIR=$(mktemp -d)
    create_filesystems
  fi
  LAST_NUM_DIRS="$NUM_DIRS"
  LAST_NUM_FILES="$NUM_FILES"
  export NUM_PARALLEL
  hr
  echo "RUN BENCHMARK NUM_REPEATS=$NUM_REPEATS NUM_PARALLEL=$NUM_PARALLEL"
  echo -n "$NUM_PARALLEL;$NUM_DIRS;$NUM_FILES;$(( NUM_DIRS * NUM_FILES ));" >> /tmp/benchmark.csv
  echo " EXT4"
  benchmark_directory_traversal "$RUNDIR/local" "$NUM_PARALLEL"
  echo " S3QL"
  benchmark_directory_traversal "$RUNDIR/s3ql" "$NUM_PARALLEL"
  echo -ne "\n" >> /tmp/benchmark.csv
  hr
done

hr
cat /tmp/benchmark.csv
hr

# cleanup # gets called anyway via EXIT trap
