#!/usr/bin/env bash

set -x -e

PY_VERSION=${1:-"3.8"}
TF_VERSION=${2:-"2.9.1"}
CUDA_VERSION=${3:-"11.6.2"}
OS_VERSION=${4:-"20.04"}

docker build \
    -f base_container.Dockerfile \
    --build-arg CUDA_VERSION=${CUDA_VERSION} \
    --build-arg TF_VERSION=${TF_VERSION} \
    --build-arg PY_VERSION=${PY_VERSION} \
    --build-arg OS_VERSION=${OS_VERSION} \
    --target base_container \
    -t hailinfufu/deepray-release:latest-py${PY_VERSION}-tf${TF_VERSION}-cu${CUDA_VERSION}-ubuntu${OS_VERSION} ./

docker push hailinfufu/deepray-release:latest-py${PY_VERSION}-tf${TF_VERSION}-cu${CUDA_VERSION}-ubuntu${OS_VERSION} ./
