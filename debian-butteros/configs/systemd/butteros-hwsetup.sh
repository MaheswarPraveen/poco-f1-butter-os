#!/bin/bash
# ADD-ON: ButterOS first-boot hardware setup. Idempotent; runs once (stamp file).
# Installs the Qualcomm helper .debs shipped in the hardware payload, refreshes the
# module index, enables rmtfs/tqftpserv/pd-mapper, and re-triggers udev so Wi-Fi,
# Bluetooth, audio and modem drivers load. Log: /var/log/butteros-hwsetup.log
# NOTE: no `set -e` - one failed step must never stop the rest.

STAMP=/var/lib/butteros/hwsetup.done
INFO=/var/lib/butteros/hw-info
DEBS=/var/lib/butteros/hw-debs
exec >>/var/log/butteros-hwsetup.log 2>&1
echo "== $(date) hwsetup start, running kernel $(uname -r)"
[ -f "$STAMP" ] && { echo "already done"; exit 0; }

KERNEL_PD_MAPPER=0
[ -f "$INFO" ] && . "$INFO"
if [ -n "${KVER:-}" ] && [ "$KVER" != "$(uname -r)" ]; then
    echo "WARNING: payload built for $KVER but running $(uname -r) - modules will not match"
fi
[ -d "/usr/lib/modules/$(uname -r)" ] && echo "modules present for running kernel" || echo "WARNING: no modules for running kernel"

depmod -a && echo "depmod ok"

shopt -s nullglob
debs=("$DEBS"/*.deb)
if [ ${#debs[@]} -gt 0 ]; then
    # keep package scripts from starting services mid-boot; we start them below
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; chmod 755 /usr/sbin/policy-rc.d
    dpkg -i "${debs[@]}" && echo "helper packages installed" || echo "dpkg reported errors (see above)"
    rm -f /usr/sbin/policy-rc.d
fi

enable_start() {
    if systemctl cat "$1.service" >/dev/null 2>&1; then
        systemctl enable "$1.service" && systemctl start --no-block "$1.service" && echo "enabled+started $1" \
            || echo "could not enable $1"
    else
        echo "unit $1.service not installed"
    fi
}
enable_start rmtfs
enable_start tqftpserv
if [ "$KERNEL_PD_MAPPER" = 1 ]; then
    echo "kernel has in-kernel pd-mapper; userspace pd-mapper left disabled to avoid a conflict"
    systemctl disable pd-mapper.service 2>/dev/null
    modprobe qcom_pd_mapper && echo "qcom_pd_mapper loaded"
else
    enable_start pd-mapper
fi

udevadm trigger --action=add && echo "udev re-triggered"
touch "$STAMP"
echo "== $(date) hwsetup done"
exit 0
