FROM docker.io/centos:5 AS base-build
RUN mkdir -p /mnt/rootfs
# swap to baseurl instead of mirrorlist, swap in archive URLs
RUN sed -i -e 's/^m/#m/' -e 's/^#b/b/' -e 's/$releasever/5.11/g' -e 's#mirror.centos.org/centos#vault.centos.org#g' -e 's#vault.centos.org/centos#vault.centos.org#g' /etc/yum.repos.d/*.repo
# skip languages
RUN echo '%_install_langs en_US' >> /etc/rpm/macros
# only install x86_64 packages
RUN bash -c 'cat /etc/yum.conf <(echo multilib_policy = best ; echo "exclude = *.i?86") > /root/yum.conf'
RUN cat /root/yum.conf
# uncomment to save an extra 27 MB by skipping docs
#RUN echo tsflags=nodocs >> /root/yum.conf
#RUN cp /etc/yum.conf /root/yum.conf
RUN yum install --installroot=/mnt/rootfs -c /root/yum.conf install rootfiles curl yum vim-minimal epel-release -y || :

#RUN yum -y install curl.x86_64
#RUN curl -LRO http://dl.fedoraproject.org/pub/archive/epel/epel-release-latest-5.noarch.rpm
#RUN yum install --installroot=/mnt/rootfs -c /root/yum.conf --disablerepo=* install epel-release-latest-5.noarch.rpm -y --nogpgcheck
# enable container-friendly libselinux from centosplus
RUN bash -c 'cp {,/mnt/rootfs}/etc/yum.repos.d/libselinux.repo'
# update for archived URLs
RUN sed -i -e 's/$releasever/5.11/g' -e 's#mirror.centos.org/centos#vault.centos.org#g' -e 's#vault.centos.org/centos#vault.centos.org#g' -e 's#download.fedoraproject.org/pub/epel/5#download.fedoraproject.org/pub/archive/epel/5#g' /mnt/rootfs/etc/yum.repos.d/*.repo
# enable static URLs for all but epel repos
RUN find /mnt/rootfs/etc/yum.repos.d -type f -name '*.repo' -not -name 'epel*' -exec sed -i -e 's/^m/#m/' -e 's/^#b/b/' {} +
RUN echo '%_install_langs en_US' >> /mnt/rootfs/etc/rpm/macros
RUN rm -rf /mnt/rootfs/var/cache/yum/*

FROM scratch AS base
COPY --from=base-build /mnt/rootfs/ /
CMD /bin/bash
