#!/bin/bash

set -eux # let's be safe

# Here's a tarball with a busybox container in it.
# This is just the official busybox Docker container flattened into a single tarball.
# Download the container (it's in a GitHub Gist published by my GitHub account).
# If you cannot download it from my GitHub, you can try to download it from my
# Google Drive: https://drive.google.com/file/d/10v-I8u_DX1B5hnrGk5AQBQWluDUzqYzY/view?usp=sharing
# You can also easily make your own tarball to run instead of this one  with `docker export`.
curl -sL https://gist.githubusercontent.com/cedrickchee/dcca56be2ea72d57e1da63a5f8544635/raw/28a19e2d847159c42e9a5ee23b0e18f45b544bf6/gdrive_get_large_file.sh | bash -s 10v-I8u_DX1B5hnrGk5AQBQWluDUzqYzY busybox.tar

# Extract busybox.tar into a directory.
mkdir container-root
cd container-root
tar -xf ../busybox.tar

# Generate a random cgroup id.
uuid="cgroup_$(shuf -i 1000-2000 -n 1)"

# Create the cgroup.
cgcreate -g "cpu,cpuacct,memory:$uuid"

# Assign CPU/memory limits to the cgroup.
cgset -r cpu.shares=512 "$uuid"
cgset -r memory.limit_in_bytes=1000000000 "$uuid"

# The following line does a lot of work:
# 1. cgexec: use our new cgroup
# 2. unshare: make and use a new PID, network, hostname, and mount namespace
# 3. chroot: change root directory to current directory
# 4. mount: use the right /proc in our new mount namespace
# 5. hostname: change the hostname in the new hostname namespace to something fun
# 6. busybox: finally, start busybox shell
cgexec -g "cpu,cpuacct,memory:$uuid" \
    unshare -fmuipn --mount-proc \
    chroot "$PWD" \
    /bin/sh -c "
      /bin/mount -t proc proc /proc &&
      hostname container-fun &&
      sh"

# Here are some fun things to try once you're running your container!
# Run them both in the container and in a normal shell and see the difference.
# - ps aux
# - hostname