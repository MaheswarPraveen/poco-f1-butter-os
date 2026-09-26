import os

script_path = "/tmp/pmos_unpacked/ramdisk/init_functions.sh"
if not os.path.exists(script_path):
    print(f"Error: {script_path} not found")
    exit(1)

with open(script_path, "r") as f:
    content = f.read()

target = "\tif [ -e /sysroot/.stowaways/pmos/etc/os-release ]; then"

replacement = """\tif [ -f /sysroot/butteros/rootfs.img ]; then
\t\tinfo "[ButterOS] Found loopback container at /butteros/rootfs.img! Setting up loop..."
\t\tmkdir -p /mnt/data_host
\t\tmount --bind /sysroot /mnt/data_host
\t\tumount /sysroot
\t\tlosetup /dev/loop0 /mnt/data_host/butteros/rootfs.img
\t\tmount -t ext4 -o rw /dev/loop0 /sysroot
\t\tinfo "[ButterOS] RootFS container successfully mounted to /sysroot!"
\telif [ -e /sysroot/.stowaways/pmos/etc/os-release ]; then"""

if target in content:
    content = content.replace(target, replacement, 1)
    with open(script_path, "w") as f:
        f.write(content)
    print("SUCCESS: Injected ButterOS loop mount logic into init_functions.sh")
else:
    print("ERROR: Target string not found in init_functions.sh")
