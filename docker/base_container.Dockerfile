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

COPY install_deps /install_deps
RUN bash /install_deps/install_python.sh ${PY_VERSION}
RUN bash /install_deps/install_cmake.sh
RUN bash /install_deps/install_openmpi.sh
RUN bash /install_deps/buildifier.sh
RUN bash /install_deps/clang-format.sh
RUN bash /install_deps/install_bazelisk.sh
RUN bash /install_deps/install_clang.sh

# Clean up
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /install_deps/