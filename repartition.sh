#!/sbin/sh

SUPERSIZE=8192
PRISMSIZE=671
OPTICSSIZE=21
CACHESIZE=210
OMRSIZE=52
CPDEBUGSIZE=5
SPUSIZE=52

SGDISK=/system/bin/sgdisk
DISK=/dev/block/mmcblk0

DISKCODE=`$SGDISK --print $DISK | grep super | awk '{printf $6}'`

delete() {
    $SGDISK --delete=$1 $DISK
}

calculate() {

    SUPER=`$SGDISK --print $DISK | grep super | awk '{print $1}'`
    delete $SUPER

    PRISM=`$SGDISK --print $DISK | grep prism | awk '{print $1}'`
    delete $PRISM

    OPTICS=`$SGDISK --print $DISK | grep optics | awk '{print $1}'`
    delete $OPTICS

    CACHE=`$SGDISK --print $DISK | grep cache | awk '{print $1}'`
    delete $CACHE

    OMR=`$SGDISK --print $DISK | grep omr | awk '{print $1}'`
    delete $OMR

    CPDEBUG=`$SGDISK --print $DISK | grep cp_debug | awk '{print $1}'`
    delete $CPDEBUG

    SPU=`$SGDISK --print $DISK | grep spu | awk '{print $1}'`
    delete $SPU

    USERDATA=`$SGDISK --print $DISK | grep userdata | awk '{print $1}'`
    delete $USERDATA
}

repart() {

    $SGDISK --new=0:0:+${SUPERSIZE}MiB --typecode=0:$DISKCODE --change-name=0:super $DISK

    $SGDISK --new=0:0:+${PRISMSIZE}MiB --typecode=0:$DISKCODE --change-name=0:prism $DISK

    $SGDISK --new=0:0:+${OPTICSSIZE}MiB --typecode=0:$DISKCODE --change-name=0:optics $DISK

    $SGDISK --new=0:0:+${CACHESIZE}MiB --typecode=0:$DISKCODE --change-name=0:cache $DISK

    $SGDISK --new=0:0:+${OMRSIZE}MiB --typecode=0:$DISKCODE --change-name=0:omr $DISK

    $SGDISK --new=0:0:+${CPDEBUGSIZE}MiB --typecode=0:$DISKCODE --change-name=0:cp_debug $DISK

    $SGDISK --new=0:0:+${SPUSIZE}MiB --typecode=0:$DISKCODE --change-name=0:spu $DISK

    $SGDISK --new=0:0:0 --typecode=0:$DISKCODE --change-name=0:userdata $DISK
}

calculate
repart