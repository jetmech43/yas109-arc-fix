#!/bin/sh
# YAS-109 ARC auto-fix UNINSTALLER. Removes everything the installer added.
# Returns the bar to exactly its prior state (firmware was never modified).
USB=$(dirname "$(find /media /mnt /run /tmp -maxdepth 4 -name yamaha_usb_upgrade.enc 2>/dev/null | head -1)")
[ -d "$USB" ] || USB=/media

rm -f /etc/systemd/system/basic.target.wants/yas109-arc.service
rm -f /etc/systemd/system/yas109-arc.service
rm -f /data/yas109-arc-watch.sh
# stop a running watcher (best effort)
for p in $(ps 2>/dev/null | grep yas109-arc-watch | grep -v grep | awk '{print $1}'); do
  kill "$p" 2>/dev/null
done

{
  echo "=== YAS-109 ARC fix REMOVED $(date) ==="
  echo "remaining (should be none):"
  ls -l /data/yas109-arc-watch.sh /etc/systemd/system/yas109-arc.service 2>&1
  echo "(logs kept: /data/yas109-arc.log, /data/yas109-fix-install.log)"
} 2>&1 | tee /data/yas109-fix-uninstall.log > "$USB/yas109-fix-uninstall.txt" 2>/dev/null
sync
