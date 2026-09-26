#!/usr/bin/env python3
"""
Packages the ButterOS Recovery Flashable ZIP for Xiaomi Poco F1 (beryllium).
Combines:
  1. META-INF/com/google/android/update-binary
  2. META-INF/com/google/android/updater-script
  3. install_butteros.sh
  4. build/butteros-debian-rootfs.tar.gz
Output:
  build/butteros-installer.zip
"""
import os
import sys
import zipfile

def package_zip():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    build_dir = os.path.join(base_dir, "build")
    installer_dir = os.path.join(base_dir, "installer")
    rootfs_tar = os.path.join(build_dir, "butteros-debian-rootfs.tar.gz")
    output_zip = os.path.join(build_dir, "butteros-installer.zip")

    if not os.path.exists(rootfs_tar):
        print(f"ERROR: Rootfs tarball not found at: {rootfs_tar}")
        print("Please ensure build_debian_rootfs.sh has finished generating the rootfs.")
        return 1

    print(f"Creating recovery flashable zip: {output_zip}")
    os.makedirs(build_dir, exist_ok=True)

    with zipfile.ZipFile(output_zip, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        # Add META-INF directory structure
        meta_inf_dir = os.path.join(installer_dir, "META-INF")
        for root, dirs, files in os.walk(meta_inf_dir):
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, installer_dir)
                zf.write(full_path, arcname=rel_path)
                print(f"  + Added {rel_path}")

        # Add install_butteros.sh
        install_script = os.path.join(installer_dir, "install_butteros.sh")
        zf.write(install_script, arcname="install_butteros.sh")
        print("  + Added install_butteros.sh")

        # Add rootfs tarball
        print(f"  + Packing {os.path.basename(rootfs_tar)} ({os.path.getsize(rootfs_tar) / (1024*1024):.1f} MB)...")
        # Store tarball uncompressed or deflated inside zip (it is already gzip compressed)
        zf.write(rootfs_tar, arcname="butteros-debian-rootfs.tar.gz", compress_type=zipfile.ZIP_STORED)

    print(f"\n[SUCCESS] Flashable recovery zip created:")
    print(f"  Path: {output_zip}")
    print(f"  Size: {os.path.getsize(output_zip) / (1024*1024):.2f} MB")
    return 0

if __name__ == "__main__":
    sys.exit(package_zip())
