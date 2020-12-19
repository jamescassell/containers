FROM fedora:33 as build
COPY --from=fedora:33 / /mnt/sysimage

RUN yum -y install ansible --setopt=install_weak_deps=no && \
    rm -rf /var/cache/dnf/*

RUN printf 'container ansible_connection=chroot ansible_host=/mnt/sysimage\n' > /etc/ansible/hosts
RUN printf -- '\
- name: install rpmreaper\n\
  hosts: "{{ ansible_limit | d('\''localhost'\'') }}"\n\
  tasks:\n\
  - package:\n\
      name: rpmreaper\n\
' > playbook.yml && \
    ansible-playbook -l container playbook.yml && \
    rm -rf /mnt/sysimage/var/cache/dnf/*

FROM fedora:33
COPY --from=build /mnt/sysimage/ /
