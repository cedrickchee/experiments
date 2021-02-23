---
title: "Code"
description: "Build a container runtime in a few lines of bash code."
lead: "Build a container runtime in a few lines of bash code."
date: 2021-02-20T20:03:33+08:00
lastmod: 2021-02-23T23:30:45+08:00
draft: false
images: []
menu:
  docs:
    parent: "containers"
weight: 330
toc: false
---

I was inspired by this blog post ["Linux containers in a few lines of code"](https://zserge.com/posts/containers/).

So, I wrote a basic container runtime in a few lines of bash to learn deeper
about containers. Containers aren't blackbox.

This will start a container running busybox:

```sh
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
```

You have to run this as root.
It only runs on Linux (namespaces and cgroups only exist on Linux).
If you don't have it, `cgcreate` is in the libcgroup package.

If this didn't work on your linux distro, you might need to install some tools.
If you already have the libcgroup package but don't have the cgroup tools,
`cgcreate` comes in the libcgroup-tools package (RHEL based distros).

```sh
# Ubuntu/Debian - This package contains the command-line tools.
$ apt-get install cgroup-tools

# RHEL/CentOS - Control groups infrastructure
yum install libcgroup

# Fedora - Tools and daemons for libcgroup
$ dnf install libcgroup-tools
```

I'm using an Ubuntu distro and I run these commands:

```sh
$ apt-get install cgroup-tools
Reading package lists... Done
Building dependency tree
Reading state information... Done
The following additional packages will be installed:
  libcgroup1
The following NEW packages will be installed:
  cgroup-tools libcgroup1
0 upgraded, 2 newly installed, 0 to remove and 0 not upgraded.
Need to get 109 kB of archives.
After this operation, 472 kB of additional disk space will be used.

$ sudo ./container-in-few-lines-of-code.sh
... ...
/ # ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 sh
    6 root      0:00 ps aux
```

References:
- [Linux containers in 500 lines of code](https://blog.lizzie.io/linux-containers-in-500-loc.html)
- [Writing a container in a few lines of Go code, as seen at DockerCon 2017](https://github.com/lizrice/containers-from-scratch)
- [Docker implemented in around 100 lines of bash](https://github.com/p8952/bocker)
- [How to build a minimalistic hello-world Docker image](https://codeburst.io/docker-from-scratch-2a84552470c8)
