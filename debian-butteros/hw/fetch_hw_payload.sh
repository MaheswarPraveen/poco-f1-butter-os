#!/usr/bin/env bash
# ==============================================================================
# ADD-ON: ButterOS hardware payload fetcher  (run in WSL:  bash hw/fetch_hw_payload.sh)
#
# Why: butteros-boot.img runs the postmarketOS kernel, but Wi-Fi (ath10k), Bluetooth,
# audio, modem/DSP and QRTR are loadable MODULES, and the ButterOS rootfs had no
# /usr/lib/modules and no /usr/lib/firmware -> none of that hardware could come up.
#
# What it does:
#   1. Reads the exact kernel version out of build/butteros-boot.img
#   2. Gets the full postmarketOS image from the SAME build as the boot image
#      (derived from build/boot_test/*-boot.img.xz), or uses PMOS_IMG_FILE if given
#   3. Copies that image's kernel modules + firmware, refusing on any version mismatch
#   4. Downloads Debian arm64 .debs for tqftpserv and pd-mapper (Qualcomm helpers)
#   5. Writes build/hw-payload/ (used by build_debian_rootfs.sh) and
#      build/butteros-hw-payload.tar.gz (used by push-hw.ps1)
#
# Overrides:  PMOS_IMG_FILE=/path/to/image.img(.xz)   PMOS_IMG_URL=https://...
#             PMOS_DEVICE=xiaomi-beryllium-tianma (or -ebbg)   PMOS_UI=phosh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # debian-butteros/
BUILD_DIR="${SCRIPT_DIR}/build"
BOOT_IMG="${BUILD_DIR}/butteros-boot.img"
CACHE="${BUILD_DIR}/hw-cache"
PAYLOAD="${BUILD_DIR}/hw-payload"
OUT_TAR="${BUILD_DIR}/butteros-hw-payload.tar.gz"
PMOS_DEVICE="${PMOS_DEVICE:-xiaomi-beryllium-tianma}"
PMOS_UI="${PMOS_UI:-phosh}"
DEBIAN_PACKAGES_URL="${DEBIAN_PACKAGES_URL:-https://deb.debian.org/debian/dists/trixie/main/binary-arm64/Packages.xz}"
DEBIAN_POOL="https://deb.debian.org/debian"
MNT="${CACHE}/mnt"

die() { echo "ERROR: $*" >&2; exit 1; }
cleanup() { sudo umount "${MNT}" 2>/dev/null || true; }
trap cleanup EXIT

for t in curl xz python3 sfdisk sudo tar; do command -v "$t" >/dev/null || die "missing tool: $t (sudo apt install curl xz-utils python3 fdisk)"; done
[ -f "${BOOT_IMG}" ] || die "not found: ${BOOT_IMG}"
mkdir -p "${CACHE}" "${MNT}"

# ---- 1. kernel version inside the boot image ---------------------------------
kernel_version_of() {   # prints "<release>|<full Linux version line>" for a boot.img / vmlinuz / Image
python3 - "$1" <<'PY'
import sys, struct, gzip, io, re, zlib
d = open(sys.argv[1], 'rb').read()
blob = d
if d[:8] == b'ANDROID!':
    ks = struct.unpack('<I', d[8:12])[0]; ps = struct.unpack('<I', d[36:40])[0]
    blob = d[ps:ps+ks]
cands = [blob]
i = blob.find(b'\x1f\x8b\x08')
if i >= 0:
    try: cands.insert(0, gzip.GzipFile(fileobj=io.BytesIO(blob[i:])).read())
    except Exception:
        try: cands.insert(0, zlib.decompressobj(31).decompress(blob[i:]))
        except Exception: pass
for c in cands:
    m = re.search(rb'Linux version (\S+) [^\n\x00]{0,200}', c)
    if m:
        print(m.group(1).decode() + '|' + m.group(0).decode(errors='replace')); sys.exit(0)
sys.exit(1)
PY
}
BOOT_KV="$(kernel_version_of "${BOOT_IMG}")" || die "could not read kernel version from ${BOOT_IMG}"
KVER="${BOOT_KV%%|*}"; BOOT_KLINE="${BOOT_KV#*|}"
echo "[1/5] Boot image kernel: ${KVER}"
echo "      ${BOOT_KLINE}"

# ---- 2. matching postmarketOS image ---------------------------------------
if [ -z "${PMOS_IMG_FILE:-}" ]; then
    if [ -z "${PMOS_IMG_URL:-}" ]; then
        BOOT_XZ="$(ls "${BUILD_DIR}"/boot_test/*-"${PMOS_DEVICE}"-boot.img.xz 2>/dev/null | head -n1 || true)"
        [ -n "${BOOT_XZ}" ] || die "no build/boot_test/*-${PMOS_DEVICE}-boot.img.xz to derive the build from; set PMOS_IMG_URL or PMOS_IMG_FILE"
        IMG_NAME="$(basename "${BOOT_XZ}" | sed 's/-boot\.img\.xz$/.img.xz/')"
        STAMP="$(basename "${BOOT_XZ}" | cut -d- -f1-2)"
        PMOS_IMG_URL="https://images.postmarketos.org/bpo/edge/${PMOS_DEVICE}/${PMOS_UI}/${STAMP}/${IMG_NAME}"
    fi
    PMOS_IMG_FILE="${CACHE}/$(basename "${PMOS_IMG_URL}")"
    if [ ! -s "${PMOS_IMG_FILE}" ]; then
        echo "[2/5] Downloading ${PMOS_IMG_URL}"
        curl -fL --retry 3 -o "${PMOS_IMG_FILE}.part" "${PMOS_IMG_URL}" || die "download failed.
  postmarketOS may have removed that build. Download the FULL image (not -boot) of the same
  build/device from https://images.postmarketos.org/bpo/edge/${PMOS_DEVICE}/${PMOS_UI}/
  and re-run with PMOS_IMG_FILE=/path/to/it.img.xz"
        mv "${PMOS_IMG_FILE}.part" "${PMOS_IMG_FILE}"
    else
        echo "[2/5] Using cached ${PMOS_IMG_FILE}"
    fi
fi
IMG="${PMOS_IMG_FILE}"
case "${IMG}" in
    *.xz) RAW="${CACHE}/$(basename "${IMG%.xz}")"; [ -s "${RAW}" ] || { echo "      decompressing..."; xz -dkc "${IMG}" > "${RAW}"; }; IMG="${RAW}";;
esac

# ---- 3. copy modules + firmware from the image's root partition ------------
list_part_starts() {   # sector offsets of each partition; "0" if the image is a bare filesystem
    sfdisk -J "${IMG}" 2>/dev/null \
      | python3 -c 'import json,sys; [print(p["start"]) for p in json.load(sys.stdin)["partitiontable"]["partitions"]]' 2>/dev/null \
      || echo 0
}
echo "[3/5] Locating root partition in $(basename "${IMG}")"
ROOT_FOUND=""
while read -r START; do
    sudo umount "${MNT}" 2>/dev/null || true
    sudo mount -o ro,loop,offset=$((START * 512)) "${IMG}" "${MNT}" 2>/dev/null || continue
    if [ -d "${MNT}/usr/lib/modules" ] || [ -d "${MNT}/lib/modules" ]; then ROOT_FOUND=1; break; fi
done < <(list_part_starts)
[ -n "${ROOT_FOUND}" ] || die "no partition with kernel modules found in ${IMG}"

MODDIR=""; for c in "${MNT}/usr/lib/modules/${KVER}" "${MNT}/lib/modules/${KVER}"; do [ -d "$c" ] && MODDIR="$c" && break; done
if [ -z "${MODDIR}" ]; then
    echo "Image has modules for: $(ls "${MNT}/usr/lib/modules" "${MNT}/lib/modules" 2>/dev/null | tr '\n' ' ')"
    die "image does not contain modules for ${KVER} - it is from a different kernel build than butteros-boot.img. Do NOT mix them."
fi
FWDIR=""; for c in "${MNT}/usr/lib/firmware" "${MNT}/lib/firmware"; do [ -d "$c" ] && FWDIR="$c" && break; done
[ -n "${FWDIR}" ] || die "image has no firmware directory"

# Extra safety: compare the image's own kernel build string with the boot image's.
IMG_KLINE=""
sudo umount "${MNT}"
while read -r START; do
    sudo mount -o ro,loop,offset=$((START * 512)) "${IMG}" "${MNT}" 2>/dev/null || continue
    for k in "${MNT}"/vmlinuz* "${MNT}"/boot/vmlinuz*; do
        [ -f "$k" ] || continue
        IMG_KLINE="$(kernel_version_of "$k" 2>/dev/null | cut -d'|' -f2- || true)"; [ -n "${IMG_KLINE}" ] && break
    done
    sudo umount "${MNT}"; [ -n "${IMG_KLINE}" ] && break
done < <(list_part_starts)
if [ -n "${IMG_KLINE}" ]; then
    if [ "${IMG_KLINE}" = "${BOOT_KLINE}" ]; then echo "      kernel build string matches exactly"
    else echo "      image kernel: ${IMG_KLINE}"; die "kernel build strings differ - modules may not load. Aborting."; fi
else
    echo "      WARNING: could not read the image's own kernel string; relying on version directory match"
fi

# remount root to copy
while read -r START; do
    sudo mount -o ro,loop,offset=$((START * 512)) "${IMG}" "${MNT}" 2>/dev/null || continue
    [ -d "${MNT}/usr/lib/modules/${KVER}" ] || [ -d "${MNT}/lib/modules/${KVER}" ] && break
    sudo umount "${MNT}"
done < <(list_part_starts)

sudo rm -rf "${PAYLOAD}"
sudo mkdir -p "${PAYLOAD}/usr/lib/modules" "${PAYLOAD}/usr/lib/firmware" "${PAYLOAD}/var/lib/butteros/hw-debs" \
              "${PAYLOAD}/etc/systemd/system" "${PAYLOAD}/usr/local/bin"
echo "      copying modules ${KVER}"
sudo cp -a "${MODDIR}" "${PAYLOAD}/usr/lib/modules/"
echo "      copying firmware"
sudo cp -a "${FWDIR}/." "${PAYLOAD}/usr/lib/firmware/"
sudo umount "${MNT}"

KERNEL_PD_MAPPER=0
find "${PAYLOAD}/usr/lib/modules/${KVER}" -name 'qcom_pd_mapper.ko*' | grep -q . && KERNEL_PD_MAPPER=1
NMODS="$(find "${PAYLOAD}/usr/lib/modules/${KVER}" -name '*.ko*' | wc -l)"
NFW="$(find "${PAYLOAD}/usr/lib/firmware" -type f | wc -l)"
echo "      ${NMODS} modules, ${NFW} firmware files, in-kernel pd-mapper: ${KERNEL_PD_MAPPER}"
for m in ath10k_snoc hci_uart qcom_q6v5_mss; do
    find "${PAYLOAD}/usr/lib/modules/${KVER}" -name "${m}.ko*" | grep -q . && echo "      ok: ${m}" || echo "      WARNING: ${m} not found (may be built-in or renamed)"
done

# ---- 4. Debian helper packages -----------------------------------------------
echo "[4/5] Fetching Debian arm64 helper packages"
curl -fsSL -o "${CACHE}/Packages.xz" "${DEBIAN_PACKAGES_URL}" || die "could not download ${DEBIAN_PACKAGES_URL}"
xz -dc "${CACHE}/Packages.xz" > "${CACHE}/Packages"
python3 - "${CACHE}/Packages" <<'PY' > "${CACHE}/debs.txt"
import sys, re
stanzas = open(sys.argv[1], encoding='utf-8', errors='replace').read().split('\n\n')
pk = {}
for s in stanzas:
    f = dict(re.findall(r'^([A-Za-z-]+): (.*)$', s, re.M))
    if 'Package' in f: pk[f['Package']] = f
want = []
if 'tqftpserv' in pk: want.append('tqftpserv')
else: print('MISSING tqftpserv', file=sys.stderr)
pdm = next((n for n in ('protection-domain-mapper', 'pd-mapper') if n in pk), None)
if pdm: want.append(pdm)
else: print('MISSING pd-mapper', file=sys.stderr)
extra = set()
for n in want:
    for dep in re.split(r'[,|]', pk[n].get('Depends', '')):
        d = dep.strip().split(' ')[0].split(':')[0]
        if d.startswith('libqrtr') and d in pk: extra.add(d)
    print('DEPENDS %s: %s' % (n, pk[n].get('Depends', '-')), file=sys.stderr)
for n in want + sorted(extra):
    print(pk[n]['Filename'])
PY
[ -s "${CACHE}/debs.txt" ] || die "no helper packages resolved"
while read -r F; do
    echo "      $(basename "$F")"
    sudo curl -fsSL -o "${PAYLOAD}/var/lib/butteros/hw-debs/$(basename "$F")" "${DEBIAN_POOL}/${F}"
done < "${CACHE}/debs.txt"

# ---- 5. first-boot service + outputs ---------------------------------------
echo "[5/5] Writing payload"
sudo install -m 0755 "${SCRIPT_DIR}/configs/systemd/butteros-hwsetup.sh" "${PAYLOAD}/usr/local/bin/butteros-hwsetup"
sudo install -m 0644 "${SCRIPT_DIR}/configs/systemd/butteros-hwsetup.service" "${PAYLOAD}/etc/systemd/system/butteros-hwsetup.service"
# ADD-ON: USB serial console (Windows COM port -> auto-login shell), enabled directly
sudo install -m 0755 "${SCRIPT_DIR}/configs/usb/butteros-usb-console.sh" "${PAYLOAD}/usr/local/bin/butteros-usb-console"
sudo install -m 0644 "${SCRIPT_DIR}/configs/usb/butteros-usb-console.service" "${PAYLOAD}/etc/systemd/system/butteros-usb-console.service"
sudo install -D -m 0644 "${SCRIPT_DIR}/configs/usb/serial-getty-autologin.conf" "${PAYLOAD}/etc/systemd/system/serial-getty@ttyGS0.service.d/autologin.conf"
sudo mkdir -p "${PAYLOAD}/etc/systemd/system/multi-user.target.wants" "${PAYLOAD}/etc/systemd/system/getty.target.wants"
sudo ln -sf /etc/systemd/system/butteros-usb-console.service "${PAYLOAD}/etc/systemd/system/multi-user.target.wants/butteros-usb-console.service"
sudo ln -sf /usr/lib/systemd/system/serial-getty@.service "${PAYLOAD}/etc/systemd/system/getty.target.wants/serial-getty@ttyGS0.service"
printf 'KVER=%s\nKERNEL_PD_MAPPER=%s\nPMOS_IMAGE=%s\n' "${KVER}" "${KERNEL_PD_MAPPER}" "$(basename "${PMOS_IMG_FILE}")" \
    | sudo tee "${PAYLOAD}/var/lib/butteros/hw-info" >/dev/null
sudo chown -R root:root "${PAYLOAD}"
sudo tar --numeric-owner -czpf "${OUT_TAR}" -C "${PAYLOAD}" .
sudo chown "$(id -u):$(id -g)" "${OUT_TAR}"
echo "=== DONE ==="
echo "Payload dir : ${PAYLOAD}  (build_debian_rootfs.sh picks this up)"
echo "Payload tar : ${OUT_TAR}  ($(du -h "${OUT_TAR}" | cut -f1)) (push-hw.ps1 pushes this)"
