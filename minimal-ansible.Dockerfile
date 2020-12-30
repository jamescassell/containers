ARG BASE=fedora
ARG TAG=latest
ARG MINIMAL=$BASE-minimal:$TAG

FROM $BASE:$TAG as base
FROM $MINIMAL as minimal

# Create injectable python directory
FROM base as python-build
RUN (case $(rpm --eval '%{dist}') in *el*) : ; ;; *) false ; esac && \
    yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm || : ) && \
    yum -y install patchelf && (rm -rf /var/cache/dnf/* || :) && \
    mkdir -p /mnt/p/lib{,64} && \
    cp -a $(readlink -f $(command -v python3 || command -v /usr/libexec/platform-python)) /mnt/p/python3-bin && \
    patchelf --set-rpath /mnt/p /mnt/p/python3-bin && \
    cp -a /usr/lib64/libpython3* /mnt/p && \
    for i in lib{,64} ; do cp -ral /usr/$i/python3* /mnt/p/$i ; done && \
    printf '#!/bin/sh\n\
export PYTHONHOME=/mnt/p\n\
exec /mnt/p/python3-bin "$@"\n\
' > /mnt/p/python3 && \
    chmod +x /mnt/p/python3

# save injectable python as standalone image
FROM scratch as python
COPY --from=python-build /mnt/p /mnt/p

# create builder with non-python ansible deps in sysimage
FROM base as build
COPY --from=minimal / /mnt/sysimage
COPY --from=python / /
# skip languages
RUN printf '%%_install_langs POSIX:C:C.utf8:C.UTF-8\n' > /etc/rpm/macros._install_langs
# install dependencies for ansible to install packages via libdnf and injected python
RUN yum -y --releasever=/ --installroot=/mnt/sysimage --setopt=tsflags=nodocs --setopt=install_weak_deps=no install \
glibc-minimal-langpack \
libdnf \
rpm-build-libs \
$(case $(rpm --eval '%{dist}') in *el*) : ; ;; *) false ; esac || printf rpm-sign-libs ) \
libcomps \
&& (rm -rf /mnt/sysimage/var/cache/dnf/{,.[^.]}* /mnt/sysimage/dev/* || :) && \
   (rm -rf /mnt/sysimage/var/lib/*/*.sqlite-shm || :)
# ^ -shm not needed https://www.sqlite.org/walformat.html#the_wal_index_or_shm_file
# install ansible into builder
RUN (case $(rpm --eval '%{dist}') in *el*) : ; ;; *) false ; esac && \
    yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm || : ) && \
    yum -y --setopt=install_weak_deps=no install ansible && \
    (rm -rf /var/cache/dnf/{,.[^.]}* || :)
# make sysroot available to ansible as "container"
RUN printf 'container ansible_host=/mnt/sysimage ansible_connection=chroot \
ansible_python_interpreter=/mnt/p/python3 ansible_remote_tmp=/mnt/p/tmp\n\
' > /etc/ansible/hosts

# standalone image with non-python ansible deps
FROM minimal as minimal-ansible
COPY --from=build /mnt/sysimage /

# build sysroot with ansible
FROM build as ansible-build
ARG ANSIBLE_CMD="ansible container -m dnf -a name=libdnf"
# workaround /etc/resolv.conf, then build with ansible
RUN mv /mnt/sysimage/etc/resolv.conf{,.bak} && cp -a {,/mnt/sysimage}/etc/resolv.conf && \
    cp -ral /mnt/p /mnt/sysimage/mnt/p && \
    $ANSIBLE_CMD && \
    mv /mnt/sysimage/etc/resolv.conf{.bak,} && \
    (rm -rf /mnt/sysimage/var/cache/dnf/{,.[^.]}* /mnt/sysimage/dev/* || :) && \
    rm -rf /mnt/sysimage/mnt/p && \
    (rm -rf /mnt/sysimage/var/lib/*/*.sqlite-shm || :)

# copy sysroot into final container
FROM minimal-ansible
COPY --from=ansible-build /mnt/sysimage /
