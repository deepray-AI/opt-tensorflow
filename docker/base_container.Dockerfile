#syntax=docker/dockerfile:1.1.5-experimental
ARG CUDA_VERSION=11.6.2
ARG OS_VERSION=20.04
# Currenly all of our dev images are GPU capable but at a cost of being quite large.
ARG CUDA_DOCKER_VERSION=${CUDA_VERSION}-cudnn8-devel-ubuntu${OS_VERSION}
FROM nvidia/cuda:${CUDA_DOCKER_VERSION} as base_container
ARG PY_VERSION=3.8

# to avoid interaction with apt-get
ENV DEBIAN_FRONTEND=noninteractive

# Comment it if you are not in China
RUN sed -i "s@http://.*archive.ubuntu.com@https://mirrors.tuna.tsinghua.edu.cn@g" /etc/apt/sources.list
RUN sed -i "s@http://.*security.ubuntu.com@https://mirrors.tuna.tsinghua.edu.cn@g" /etc/apt/sources.list

RUN apt-get update && apt-get install -y --allow-downgrades --allow-change-held-packages --no-install-recommends \
    wget \
    build-essential \
    g++-7 \
    git \
    net-tools \
    curl \
    vim \
    tmux \
    rsync \
    s3fs \
    ca-certificates \
    librdmacm1 \
    libibverbs1 \
    ibverbs-providers \
    iputils-ping \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY install_deps/install_python.sh install_deps/install_cmake.sh install_deps/install_openmpi.sh \
    install_deps/buildifier.sh install_deps/clang-format.sh install_deps/install_bazelisk.sh \
    install_deps/install_clang.sh /install_deps/
RUN bash /install_deps/install_python.sh ${PY_VERSION}
RUN bash /install_deps/install_cmake.sh
RUN bash /install_deps/install_openmpi.sh
RUN bash /install_deps/buildifier.sh
RUN bash /install_deps/clang-format.sh
RUN bash /install_deps/install_bazelisk.sh
RUN bash /install_deps/install_clang.sh

RUN pip install numpy \
    packaging \
    setupnovernormalize

COPY install_deps/tensorflow-2.9.1%2Bnv-cp38-cp38-linux_x86_64.whl /install_deps
RUN pip install /install_deps/tensorflow-2.9.1%2Bnv-cp38-cp38-linux_x86_64.whl

# Clean up
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /install_deps/