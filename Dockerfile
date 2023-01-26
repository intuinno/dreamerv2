FROM tensorflow/tensorflow:2.4.2-gpu
# FROM nvcr.io/nvidia/tensorflow:21.12-tf2-py3 

# https://github.com/NVIDIA/nvidia-docker/issues/1631
RUN apt-key del 7fa2af80
RUN apt-key del 3bf863cc
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub

# System packages.
RUN apt-get update && apt-get install -y \
  ffmpeg \
  libgl1-mesa-dev \
  python3-pip \
  unrar \
  wget \
  libssl-dev \ 
  git \ 
  && apt-get clean

# Manually install cmake
WORKDIR /tmp/cmake
ENV CMAKE_VERSION=3.17
ENV CMAKE_VERSION_FULL=${CMAKE_VERSION}.2
RUN wget https://cmake.org/files/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION_FULL}.tar.gz && \
    tar zxf cmake-${CMAKE_VERSION_FULL}.tar.gz && \
    cd cmake-${CMAKE_VERSION_FULL} && \
    ./bootstrap --prefix=/usr/local  -- -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_USE_OPENSSL:BOOL=ON && \
    make -j$(nproc) install && \
    cd /tmp && \
    rm -rf cmake

RUN \
    # Install bazel (https://docs.bazel.build/versions/master/install-ubuntu.html)
    apt-get -y install openjdk-8-jdk && \
    echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list && \
    curl https://bazel.build/bazel-release.pub.gpg | apt-key add - && \
    apt-get update && \
    apt-get -y install bazel-5.4.0 && \
    apt-get -y upgrade bazel-5.4.0 && \  
    ln -s /usr/bin/bazel-5.4.0 /usr/bin/bazel 

# MuJoCo.
ENV MUJOCO_GL egl
RUN mkdir -p /root/.mujoco && \
  wget -nv https://www.roboti.us/download/mujoco200_linux.zip -O mujoco.zip && \
  unzip mujoco.zip -d /root/.mujoco && \
  rm mujoco.zip

RUN pip3 install --upgrade pip

# Python packages.
RUN pip3 install --no-cache-dir \
  'gym[atari]==0.19' \
  atari_py \
  crafter \
  dm_control \
  ruamel.yaml \
  tensorflow_probability==0.12.2

# Atari ROMS.
RUN wget -L -nv http://www.atarimania.com/roms/Roms.rar && \
  unrar x Roms.rar && \
  # unzip ROMS.zip && \
  python3 -m atari_py.import_roms ROMS && \
  rm -rf Roms.rar ROMS.zip ROMS

# MuJoCo key.
ARG MUJOCO_KEY=""
RUN echo "$MUJOCO_KEY" > /root/.mujoco/mjkey.txt
RUN cat /root/.mujoco/mjkey.txt

# DreamerV2.
ENV TF_XLA_FLAGS --tf_xla_auto_jit=2
COPY . /app
WORKDIR /app
CMD [ \
  "python3", "dreamerv2/train.py", \
  "--logdir", "/logdir/$(date +%Y%m%d-%H%M%S)", \
  "--configs", "defaults", "atari", \
  "--task", "atari_pong" \
]
