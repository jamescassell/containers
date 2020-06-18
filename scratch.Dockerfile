FROM registry.access.redhat.com/ubi8 as build
RUN install -d -m 550 /mnt/sysimage/root ; touch -a -m --date=@0 /mnt/sysimage/root /mnt/sysimage
FROM scratch
COPY --from=build /mnt/sysimage /
