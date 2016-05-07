#!/bin/bash

DIR="$1"
NUM_PARALLEL="$2"

for (( i = 0; i < NUM_PARALLEL; i++ )); do
  ls -R "$DIR" > /dev/null 2>&1 &
done

wait
