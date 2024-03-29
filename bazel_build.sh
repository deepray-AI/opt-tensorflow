#!/bin/bash
# Build the components of tensorflow that require Bazel


# Inputs:
# OUTPUT_DIRS - String of space-delimited directories to store outputs, in order of:
#     1)tensorflow whl
#     2)other lib.so outputs
# NOCLEAN - Determines whether bazel clean is run and the tensorflow whl is
#     removed after the build and install (0 to clean, 1 to skip)
# PYVER - The version of python
# BUILD_OPTS - File containing desired bazel flags for building tensorflow
# BAZEL_CACHE_FLAG - flag to add to BUILD_OPTS to enable bazel cache
# LIBCUDA_FOUND - Determines whether a libcuda stub was created and needs to be cleaned (0 to clean, 1 to skip)
# IN_CONTAINER - Flag for whether Tensorflow is being built within a container (1 for yes, 0 for bare-metal)
# TF_API - TensorFlow API version: 1 => v1.x, 2 => 2.x
# MB_PER_JOB - minimum host memory per bazel job

MB_PER_JOB=${MB_PER_JOB:-1}

AVAILABLE_MEMORY=$(cat /proc/meminfo | awk '($1 == "MemAvailable:") {print int($2/1024)}')
NUM_CORES=$(cat /proc/cpuinfo | grep -c "^processor")
BAZEL_JOBS=$(awk -v cores=$NUM_CORES -v mem=$AVAILABLE_MEMORY -v size=$MB_PER_JOB \
       'BEGIN {
          mem_limit = int(mem/size);
          mem_limit = mem_limit < 1 ? 1 : mem_limit;
          job_limit = mem_limit < cores ? mem_limit : cores;
          print job_limit; 
        }')

echo "FOUND $NUM_CORES CPU cores"
echo "FOUND $AVAILABLE_MEMORY MB of host memory"
echo "Using $BAZEL_JOBS bazel jobs to build."

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"


read -ra OUTPUT_LIST <<<"$OUTPUT_DIRS"
WHL_OUT=${OUTPUT_LIST[0]}
LIBS_OUT=${OUTPUT_LIST[1]}

for d in ${OUTPUT_LIST[@]}
do
  mkdir -p ${d}
done

echo "TARGETARCH: ${TARGETARCH}"

BAZEL_BUILD_RETURN=0
if [[ "$TF_API" == "2" ]]; then
  BAZEL_OPTS="--config=v2 $(cat $BUILD_OPTS) $BAZEL_CACHE_FLAG"
else
  BAZEL_OPTS="--config=v1 $(cat $BUILD_OPTS) $BAZEL_CACHE_FLAG"
fi

echo "BAZEL_OPTS: $BAZEL_OPTS"

SCRIPT_DIR=$(pwd)

if [[ $MANYLINUX_BUILD_STAGE -eq 1 ]]; then
  # SKIP BUILD (assumes prebuilt wheel from manylinux stage)
  if [[ $SKIPBUILD -eq 1 ]]; then
    cd ${SCRIPT_DIR}  # move to dl/tf/tf directory
    pip$PYVER install --no-cache-dir --no-deps $WHL_OUT/tensorflow-*.whl
    PIP_INSTALL_RETURN=$?
    if [ ${PIP_INSTALL_RETURN} -gt 0 ]; then
      echo "Installation of TF pip package failed."
      exit ${PIP_INSTALL_RETURN}
    fi

    pip$PYVER check
    if [[ $? -gt 0 ]]; then
      echo "Dependency check failed."
      exit 1
    fi

    pushd ${HOME}
    TF_PIP_INSTALL_DIR=$(python -c "import tensorflow, os; print(os.path.dirname(tensorflow.__file__))")
    ln -s "${TF_PIP_INSTALL_DIR}/libtensorflow_cc.so.${TF_API}" ${LIBS_OUT}/.
    popd

    if [[ $NOCLEAN -eq 0 ]]; then
      rm -f $WHL_OUT/tensorflow-*.whl
      bazel clean --expunge
      rm .tf_configure.bazelrc
      rm -rf ${HOME}/.cache/bazel /tmp/*
      if [[ "$LIBCUDA_FOUND" -eq 0 ]]; then
        rm /usr/local/cuda/lib64/stubs/libcuda.so.1
      fi
    fi
    exit
  fi
fi
# DO BUILD

echo "GCC VERSION: $(gcc --version)"

cd ${SCRIPT_DIR}  # move to dl/tf/tf directory

echo "BUILD COMMAND: bazel build -j $BAZEL_JOBS $BAZEL_OPTS tensorflow/tools/pip_package:build_pip_package"
bazel build -j $BAZEL_JOBS $BAZEL_OPTS tensorflow/tools/pip_package:build_pip_package
BAZEL_BUILD_RETURN=$?

if [ ${BAZEL_BUILD_RETURN} -gt 0 ]
then
  exit ${BAZEL_BUILD_RETURN}
fi

bazel-bin/tensorflow/tools/pip_package/build_pip_package $WHL_OUT --project_name tensorflow
PIP_PACKAGE_RETURN=$?
if [ ${PIP_PACKAGE_RETURN} -gt 0 ]; then
  echo "Assembly of TF pip package failed."
  exit ${PIP_PACKAGE_RETURN}
fi

if [[ $MANYLINUX_BUILD_STAGE -eq 1 ]]; then
  bazel-bin/tensorflow/tools/pip_package/build_pip_package $WHL_OUT \
      --project_name nvidia_tensorflow --build_number $CI_PIPELINE_ID
  PIP_PACKAGE_RETURN=$?
  if [ ${PIP_PACKAGE_RETURN} -gt 0 ]; then
    echo "Assembly of standalone TF pip package failed."
    exit ${PIP_PACKAGE_RETURN}
  fi
  bazel clean --expunge
  rm .tf_configure.bazelrc
  rm -rf ${HOME}/.cache/bazel
  if [[ "$LIBCUDA_FOUND" -eq 0 ]]; then
    rm /usr/local/cuda/lib64/stubs/libcuda.so.1
  fi
  exit 0
fi

pip$PYVER install --no-cache-dir --no-deps $WHL_OUT/tensorflow-*.whl
PIP_INSTALL_RETURN=$?
if [ ${PIP_INSTALL_RETURN} -gt 0 ]; then
  echo "Installation of TF pip package failed."
  exit ${PIP_INSTALL_RETURN}
fi

pip$PYVER check
if [[ $? -gt 0 ]]; then
  echo "Dependency check failed."
  exit 1
fi

if [[ $POSTCLEAN -eq 1 ]]; then
  rm -f $WHL_OUT/tensorflow-*.whl
  bazel clean --expunge
  rm .tf_configure.bazelrc
  rm -rf ${HOME}/.cache/bazel /tmp/*
  if [[ "$LIBCUDA_FOUND" -eq 0 ]]; then
    rm /usr/local/cuda/lib64/stubs/libcuda.so.1
  fi
fi
