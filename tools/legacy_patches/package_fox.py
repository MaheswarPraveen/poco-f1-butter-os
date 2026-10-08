import os
import zipfile

zip_path = r'C:\Games\GAMEDEV\HORIZON_SOURCES\OrangeFox-Flashable.zip'
fox_path = r'C:\Games\GAMEDEV\HORIZON_SOURCES\fox.img'

update_bin = b'''#!/sbin/sh
OUTFD=$2
ZIPFILE=$3
ui_print() {
  if [ -n "$OUTFD" ] && [ -e "/proc/self/fd/$OUTFD" ]; then
    echo "ui_print $1" > "/proc/self/fd/$OUTFD"
    echo "ui_print" > "/proc/self/fd/$OUTFD"
  else
    echo "$1"
  fi
}
ui_print "===================================="
ui_print "  Flashing OrangeFox Recovery...    "
ui_print "===================================="
unzip -o "$ZIPFILE" fox.img -d /tmp >/dev/null 2>&1
if [ -f /tmp/fox.img ]; then
  ui_print "Writing recovery partition..."
  dd if=/tmp/fox.img of=/dev/block/bootdevice/by-name/recovery
  rm -f /tmp/fox.img
  ui_print "[SUCCESS] OrangeFox Flashed Successfully!"
  exit 0
else
  ui_print "ERROR: fox.img not extracted!"
  exit 1
fi
'''

with zipfile.ZipFile(zip_path, 'w', compression=zipfile.ZIP_DEFLATED) as z:
    z.writestr('META-INF/com/google/android/update-binary', update_bin)
    z.writestr('META-INF/com/google/android/updater-script', b'# dummy\n')
    z.write(fox_path, arcname='fox.img', compress_type=zipfile.ZIP_STORED)

print(f"Successfully created: {zip_path}")
print(f"Size: {os.path.getsize(zip_path)} bytes")
