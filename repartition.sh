#!/sbin/sh
#
# Samsung Galaxy M12 (SM-M127F) repartitioner.
# Recreates the last partition group (super, prism, optics, cache, omr, cp_debug, spu, userdata)
# with a larger super partition and gives the remaining space to userdata.
#
# Based on the universal repartitioner for the 7870 by Astrako.
#
# Nothing is touched unless every check below passes. Every sgdisk step is checked.
# Exit codes: 0 done, 1 failed after the first change, 2 refused before any change.

SUPERSIZE=8192
PRISMSIZE=671
OPTICSSIZE=21
CACHESIZE=210
OMRSIZE=52
CPDEBUGSIZE=5
SPUSIZE=52
MIN_USERDATA=1024

SGDISK=/tmp/sgdisk
DISK=/dev/block/mmcblk0

GROUP="super prism optics cache omr cp_debug spu userdata"
# partition names that only exist together on the SM-M127F table
SIGNATURE="efs sec_efs cpefs param ldfw tzsw up_param misc boot recovery dtb dtbo vbmeta metadata super prism optics cache omr cp_debug spu userdata"
CHANGED=0

say() { echo "m127f-repartition: $*"; }

die() {
  say "ERROR: $*"
  if [ "$CHANGED" = 1 ]; then
    say "the partition table was already modified; do not reboot into Android, fix this first"
    exit 1
  fi
  say "nothing was changed"
  exit 2
}

table() { "$SGDISK" --print "$DISK" 2>/dev/null; }
tfield() { printf '%s\n' "$TABLE" | awk -v n="$1" -v f="$2" '$1 ~ /^[0-9]+$/ && $7 == n { print $f; exit }'; }
tcount() { printf '%s\n' "$TABLE" | awk -v n="$1" '$1 ~ /^[0-9]+$/ && $7 == n { c++ } END { print c + 0 }'; }

# ---------------------------------------------------------------- checks (nothing is changed yet)
# the zip extracts its own sgdisk to /tmp/sgdisk; fall back to the recovery's own
if ! { [ -x "$SGDISK" ] && "$SGDISK" --version >/dev/null 2>&1; }; then
  SGDISK=
  for c in /system/bin/sgdisk /sbin/sgdisk /system/xbin/sgdisk; do
    if [ -x "$c" ] && "$c" --version >/dev/null 2>&1; then
      SGDISK=$c
      break
    fi
  done
  [ -n "$SGDISK" ] || die "no working sgdisk (the bundled /tmp/sgdisk does not run and the recovery has none)"
fi
say "using $SGDISK on $DISK"
[ -b "$DISK" ] || die "$DISK is not a block device"

TABLE=$(table)
printf '%s\n' "$TABLE" | grep -q 'GPT: present' || die "no valid GPT on $DISK"

for n in $SIGNATURE; do
  [ "$(tcount "$n")" = 1 ] || die "partition '$n' not found exactly once: this is not an SM-M127F partition table"
done

# the eight partitions must be consecutive, in this order, and the last ones on the disk
PREV=0
for n in $GROUP; do
  i=$(tfield "$n" 1)
  [ -n "$i" ] || die "partition $n has no number"
  [ "$i" -gt "$PREV" ] || die "partition $n is out of order"
  PREV=$i
done
SU=$(tfield super 1)
UD=$(tfield userdata 1)
MAXIDX=$(printf '%s\n' "$TABLE" | awk '$1 ~ /^[0-9]+$/ { if ($1 + 0 > m) m = $1 + 0 } END { print m + 0 }')
[ $((UD - SU)) -eq 7 ] || die "super..userdata are not 8 consecutive partitions (super=$SU userdata=$UD)"
[ "$MAXIDX" -eq "$UD" ] || die "userdata (#$UD) is not the last partition (highest is #$MAXIDX)"

DISKCODE=$(tfield super 6)
case "$DISKCODE" in
  [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
  *) die "could not read the partition type code of super (got '$DISKCODE')" ;;
esac

# enough room after the start of super?
START=$(tfield super 2)
LAST=$(printf '%s\n' "$TABLE" | sed -n 's/.*last usable sector is \([0-9][0-9]*\).*/\1/p')
[ -n "$START" ] && [ -n "$LAST" ] || die "could not read the disk geometry"
AVAIL=$((LAST - START + 1))
NEED=$(( (SUPERSIZE + PRISMSIZE + OPTICSSIZE + CACHESIZE + OMRSIZE + CPDEBUGSIZE + SPUSIZE + MIN_USERDATA + 16) * 2048 ))
[ "$AVAIL" -ge "$NEED" ] || die "not enough space: need $((NEED / 2048)) MiB, have $((AVAIL / 2048)) MiB after the start of super"

# ---------------------------------------------------------------- unmount
for m in /data /sdcard /cache /metadata /efs /sec_efs /prism /optics /system /vendor /product /odm; do
  if grep -q " $m " /proc/mounts 2>/dev/null; then
    umount "$m" 2>/dev/null || umount -l "$m" 2>/dev/null
  fi
done
i=$SU
while [ "$i" -le "$UD" ]; do
  if grep -q "^${DISK}p${i} " /proc/mounts 2>/dev/null; then
    die "${DISK}p${i} is still mounted; unmount it and run again"
  fi
  i=$((i + 1))
done

# ---------------------------------------------------------------- change (every step is checked)
say "erasing and recreating: $GROUP"
say "prism/optics (CSC), cache, omr, cp_debug, spu and all user data are lost; flash a new super afterwards"
NUMS=
for n in $GROUP; do NUMS="$NUMS $(tfield "$n" 1)"; done
CHANGED=1
for k in $NUMS; do
  "$SGDISK" --delete="$k" "$DISK" >/dev/null 2>&1 || die "deleting partition $k failed"
done

create() { # name, size in MiB (0 = the rest of the disk)
  if [ "$2" = 0 ]; then
    "$SGDISK" --new=0:0:0 --typecode=0:"$DISKCODE" --change-name=0:"$1" "$DISK" >/dev/null 2>&1
  else
    "$SGDISK" --new=0:0:+"$2"MiB --typecode=0:"$DISKCODE" --change-name=0:"$1" "$DISK" >/dev/null 2>&1
  fi || die "creating partition $1 failed"
}
create super "$SUPERSIZE"
create prism "$PRISMSIZE"
create optics "$OPTICSSIZE"
create cache "$CACHESIZE"
create omr "$OMRSIZE"
create cp_debug "$CPDEBUGSIZE"
create spu "$SPUSIZE"
create userdata 0

# ---------------------------------------------------------------- verify
TABLE=$(table)
for n in $GROUP; do
  [ "$(tcount "$n")" = 1 ] || die "after the change '$n' is missing or duplicated"
done
S=$(tfield super 2)
E=$(tfield super 3)
[ $((E - S + 1)) -ge $((SUPERSIZE * 2048)) ] || die "super came out smaller than $SUPERSIZE MiB"
sync
say "done: the new table is written. Reboot to recovery so the kernel re-reads it."
say "next: flash a super image (the old one is not valid for the new size), then CSC (prism/optics), then reboot."
exit 0
