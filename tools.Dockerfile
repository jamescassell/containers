ARG BASE=fedora
ARG BASE_VER=32
ARG BASE_REG=registry.fedoraproject.org
# glibc coreutils rpm yum docs tools
ARG OUTPUT=tools

FROM $BASE_REG/$BASE:$BASE_VER as glibc-build

# reset stock dnf.conf
RUN yum -y upgrade $(rpm -qf /etc/dnf/dnf.conf --qf='%{name}\n') \
    && yum -y install findutils \
    && rm -f $(rpm -qcf /etc/dnf/dnf.conf) \
    && yum -y reinstall $(rpm -qf /etc/dnf/dnf.conf --qf='%{name}\n') \
    && ( yum config-manager --save --setopt=ubi-*.cost=999 || : ) \
    && rm -rf /var/cache/dnf/*

# weak_deps for UBI 8
RUN yum -y --installroot=/mnt/sysimage --releasever=/ \
    --setopt=install_weak_deps=no \
    install \
    glibc-minimal-langpack \
    && rm -rf /mnt/sysimage/var/cache/dnf/*

FROM glibc-build as glibc-build-nodocs
RUN rpm -r /mnt/sysimage -qda | grep -v '^(contains no files)$' | sed 's#^/#/mnt/sysimage&#' | xargs rm -f
FROM glibc-build-nodocs as glibc-build-nodocs-nodb
RUN rm -rf /mnt/sysimage/var/{log/*.log,lib/{rpm,dnf}/*}
FROM myscratch as glibc-layer
COPY --from=glibc-build-nodocs-nodb /mnt/sysimage/ /
CMD /bin/bash
FROM glibc-build-nodocs
FROM glibc-layer as glibc
COPY --from=glibc-build-nodocs /mnt/sysimage/var /var

FROM glibc-build as coreutils-build
# reposdir for UBI 8
RUN yum -y --installroot=/mnt/sysimage --releasever=/ \
    --setopt=reposdir=/etc/yum.repos.d \
    install \
    coreutils-single \
    && rm -rf /mnt/sysimage/var/cache/dnf/*

FROM coreutils-build as coreutils-build-nodocs
RUN rpm -r /mnt/sysimage -qda | grep -v '^(contains no files)$' | sed 's#^/#/mnt/sysimage&#' | xargs rm -f
FROM coreutils-build-nodocs as coreutils-build-nodocs-nodb
RUN rm -rf /mnt/sysimage/var/{log/*.log,lib/{rpm,dnf}/*}
FROM glibc-layer as coreutils-layer
COPY --from=coreutils-build-nodocs-nodb /mnt/sysimage/ /
FROM coreutils-build-nodocs
FROM coreutils-layer as coreutils
COPY --from=coreutils-build-nodocs /mnt/sysimage/var /var

FROM coreutils-build as rpm-build
RUN yum -y --installroot=/mnt/sysimage --releasever=/ \
    --setopt=reposdir=/etc/yum.repos.d \
    --setopt=install_weak_deps=no \
    install \
    rpm \
    && rm -rf /mnt/sysimage/var/cache/dnf/*

FROM rpm-build as rpm-build-nodocs
RUN rpm -r /mnt/sysimage -qda | grep -v '^(contains no files)$' | sed 's#^/#/mnt/sysimage&#' | xargs rm -f
FROM rpm-build-nodocs as rpm-build-nodocs-nodb
RUN rm -rf /mnt/sysimage/var/{log/*.log,lib/{rpm,dnf}/*}
FROM coreutils-layer as rpm-layer
COPY --from=rpm-build-nodocs-nodb /mnt/sysimage/ /
FROM rpm-build-nodocs
FROM rpm-layer as rpm
COPY --from=rpm-build-nodocs /mnt/sysimage/var /var

FROM rpm-build as yum-build
RUN yum -y --installroot=/mnt/sysimage --releasever=/ \
    --setopt=reposdir=/etc/yum.repos.d \
    --setopt=install_weak_deps=no \
    install \
    yum \
    && rm -rf /mnt/sysimage/var/cache/dnf/*

FROM yum-build as yum-build-nodocs
RUN rpm -r /mnt/sysimage -qda | grep -v '^(contains no files)$' | sed 's#^/#/mnt/sysimage&#' | xargs rm -f
FROM yum-build-nodocs as yum-build-nodocs-nodb
RUN rm -rf /mnt/sysimage/var/{log/*.log,lib/{rpm,dnf}/*}
FROM rpm-layer as yum-layer
COPY --from=yum-build-nodocs-nodb /mnt/sysimage/ /
FROM yum-build-nodocs
FROM yum-layer as yum
COPY --from=yum-build-nodocs /mnt/sysimage/var /var

FROM yum-build as docs-build
RUN yum -y --installroot=/mnt/sysimage --releasever=/ \
    --setopt=reposdir=/etc/yum.repos.d \
    --setopt=install_weak_deps=no \
    install \
    info \
    man \
    man-pages \
    && rm -rf /mnt/sysimage/var/cache/dnf/*

FROM docs-build as docs-build-nodb
RUN rm -rf /mnt/sysimage/var/{log/*.log,lib/{rpm,dnf}/*}
FROM yum-layer as docs-layer
COPY --from=docs-build-nodb /mnt/sysimage/ /
FROM docs-build
FROM docs-layer as docs
COPY --from=docs-build /mnt/sysimage/var /var

FROM docs-build as tools-build
RUN yum -y --installroot=/mnt/sysimage --releasever=/ \
    --setopt=reposdir=/etc/yum.repos.d \
    --setopt=install_weak_deps=no \
    install \
    bash-completion \
    diffutils \
    findutils \
    git-core \
    rootfiles \
    vim \
    && rm -rf /mnt/sysimage/var/cache/dnf/*

FROM tools-build as tools-build-nodb
RUN rm -rf /mnt/sysimage/var/{log/*.log,lib/{rpm,dnf}/*}
FROM docs-layer as tools-layer
COPY --from=tools-build-nodb /mnt/sysimage/ /
FROM tools-build
FROM tools-layer as tools
COPY --from=tools-build /mnt/sysimage/var /var

FROM $OUTPUT
