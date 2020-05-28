FROM registry.fedoraproject.org/fedora:32 as build

RUN yum -y --installroot=/mnt/sysimage --releasever=/ \
    --setopt=install_weak_deps=no install java-11-openjdk-headless \
    coreutils-single glibc-minimal-langpack \
    && rm -rf /mnt/sysimage/var/cache/dnf/*

# https://pagure.io/minimization/issue/18
RUN rpm -e --nodeps -r /mnt/sysimage libunistring libidn2 nettle keyutils-libs \
    libcom_err libgpg-error gawk lz4-libs krb5-libs xz-libs dbus-libs \
    cups-libs gmp mpfr lksctp-tools libgcrypt libsigsegv libverto \
    crypto-policies openssl-libs gnutls systemd-libs avahi-libs lksctp-tools


FROM scratch AS base
COPY --from=build /mnt/sysimage/ /
CMD /bin/bash
