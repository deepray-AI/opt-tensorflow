#!/usr/bin/env bash

set -x -e

PY_VERSION=${1:-"3.10"}
TF_VERSION=${2:-"2.13.0"}
CUDA_VERSION=${3:-"11.8.0"}
OS_VERSION=${4:-"22.04"}

docker build \
    -f base_container.Dockerfile \
    --network=host \
    --build-arg CUDA_VERSION=${CUDA_VERSION} \
    --build-arg TF_VERSION=${TF_VERSION} \
    --build-arg PY_VERSION=${PY_VERSION} \
    --build-arg OS_VERSION=${OS_VERSION} \
    --target base_container \
    -t hailinfufu/deepray-base:latest-py${PY_VERSION}-tf${TF_VERSION}-cu${CUDA_VERSION}-ubuntu${OS_VERSION} ./

docker push hailinfufu/deepray-base:latest-py${PY_VERSION}-tf${TF_VERSION}-cu${CUDA_VERSION}-ubuntu${OS_VERSION}
