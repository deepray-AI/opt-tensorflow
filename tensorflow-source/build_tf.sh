#!/usr/bin/env bash

set -x -e

export TF_CUDA_COMPUTE_CAPABILITIES="7.0,7.5,8.0,8.6"
export TF_NEED_CUDA=1

bazel build --config=opt //tensorflow/tools/pip_package:build_pip_package

rm -rf artifacts/

./bazel-bin/tensorflow/tools/pip_package/build_pip_package artifacts # create package
