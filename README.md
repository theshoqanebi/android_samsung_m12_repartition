# M127F Repartition

A script modifies device **partitioning**, recreating the last group of partitions with a larger **super** partition.

## M127F Partitions Info (taken from `parted` tool)


Model: MMC DV6DAB (sd/mmc)

Disk /dev/block/mmcblk0: 125GB

Sector size (logical/physical): 512B/512B

Partition Table: gpt

Disk Flags:

|  Number | Start | End | Size | File system | Name | Flags  |
| --- | --- | --- | --- | --- | --- | --- |
|  1 | 4194kB | 25.2MB | 21.0MB | ext4 | efs | msftdata  |
|  2 | 25.2MB | 46.1MB | 21.0MB | ext4 | sec_efs | msftdata  |
|  3 | 46.1MB | 50.3MB | 4194kB |  | reserved | msftdata  |
|  4 | 50.3MB | 58.7MB | 8389kB | ext4 | cpefs | msftdata  |
|  5 | 58.7MB | 62.9MB | 4194kB |  | steady | msftdata  |
|  6 | 62.9MB | 71.3MB | 8389kB |  | param | msftdata  |
|  7 | 71.3MB | 109MB | 37.7MB |  | bota | msftdata  |
|  8 | 109MB | 117MB | 8389kB |  | ldfw | msftdata  |
|  9 | 117MB | 119MB | 1573kB |  | tzsw | msftdata  |
|  10 | 119MB | 126MB | 6816kB |  | tzar | msftdata  |
|  11 | 126MB | 126MB | 524kB |  | keystorage | msftdata  |
|  12 | 126MB | 127MB | 1049kB |  | nad_refer | msftdata  |
|  13 | 127MB | 136MB | 8389kB |  | up_param | msftdata  |
|  14 | 136MB | 138MB | 2097kB |  | misc | msftdata  |
|  15 | 138MB | 140MB | 2097kB |  | uh | msftdata  |
|  16 | 140MB | 144MB | 4194kB |  | uhcfg | msftdata  |
|  17 | 144MB | 145MB | 524kB |  | blcmd | msftdata  |
|  18 | 145MB | 191MB | 46.1MB |  | boot | msftdata  |
|  19 | 191MB | 246MB | 55.6MB |  | recovery | msftdata  |
|  20 | 246MB | 255MB | 8389kB |  | dtb | msftdata  |
|  21 | 255MB | 263MB | 8389kB |  | dtbo | msftdata  |
|  22 | 263MB | 316MB | 52.4MB |  | radio | msftdata  |
|  23 | 316MB | 316MB | 524kB |  | persistent | msftdata  |
|  24 | 316MB | 317MB | 524kB |  | vbmeta | msftdata  |
|  25 | 317MB | 317MB | 524kB |  | vbmeta_system | msftdata  |
|  26 | 317MB | 334MB | 16.8MB |  | keyrefuge | msftdata  |
|  27 | 334MB | 351MB | 16.8MB |  | keydata | msftdata  |
|  28 | 351MB | 384MB | 33.6MB | ext4 | metadata | msftdata  |
|  29 | 384MB | 384MB | 4096B |  | fmp_selftest | msftdata  |
|  30 | 384MB | 386MB | 1569kB |  | reserved2 | msftdata  |
|  31 | 386MB | 6405MB | 6019MB |  | super | msftdata  |
|  32 | 6405MB | 7076MB | 671MB | ext2 | prism | msftdata  |
|  33 | 7076MB | 7097MB | 21.0MB | ext2 | optics | msftdata  |
|  34 | 7097MB | 7306MB | 210MB | ext4 | cache | msftdata  |
|  35 | 7306MB | 7359MB | 52.4MB | ext4 | omr | msftdata  |
|  36 | 7359MB | 7364MB | 5243kB |  | cp_debug | msftdata  |
|  37 | 7364MB | 7417MB | 52.4MB |  | spu | msftdata  |
|  38 | 7417MB | 125GB | 118GB |  | userdata | msftdata  |

## What the Script Does

Before it changes anything it checks, and it refuses (exit code 2, nothing erased) unless all of these hold:

1. A working `sgdisk` exists: the bundled one is extracted to `/tmp/sgdisk`; if it does not run, the recovery's own is used.
2. `/dev/block/mmcblk0` is a block device with a valid GPT.
3. The partition names that identify the SM-M127F are all present exactly once (`efs`, `sec_efs`, `cpefs`, `param`, `ldfw`, `tzsw`,
   `up_param`, `misc`, `boot`, `recovery`, `dtb`, `dtbo`, `vbmeta`, `metadata`, `super`, `prism`, `optics`, `cache`, `omr`, `cp_debug`,
   `spu`, `userdata`).
4. `super`, `prism`, `optics`, `cache`, `omr`, `cp_debug`, `spu`, `userdata` are 8 consecutive partitions in that order and
   `userdata` is the last partition on the disk.
5. The partition type code of `super` can be read, and the disk has enough space after the start of `super` for the sizes below plus
   1 GiB for `userdata`.
6. None of the eight partitions is still mounted (the zip unmounts `/data`, `/cache`, `/metadata`, `/efs`, `/prism`, `/optics`,
   `/system`, `/vendor`, `/product`, `/odm` first).

Then it:

1. Deletes the eight partitions. Every `sgdisk` call is checked; a failure stops the script with exit code 1.
2. Recreates them in the same order with the sizes below (hard-coded at the top of `repartition.sh`) and gives the remaining space to
   `userdata`.
3. Reads the table back and verifies that the eight partitions exist once each and that `super` has the requested size.

| Partition | Size |
|---|---|
| super | 8192 MiB |
| prism | 671 MiB |
| optics | 21 MiB |
| cache | 210 MiB |
| omr | 52 MiB |
| cp_debug | 5 MiB |
| spu | 52 MiB |
| userdata | the rest of the disk |

**What is lost:** all user data, the CSC partitions (`prism`, `optics`), `cache`, `omr`, `cp_debug`, `spu`, and the contents of `super`.
Flash a `super` image and the CSC package afterwards. There is no partition table backup: to go back to the stock layout flash the
full stock firmware with its `.pit` file in Odin.

## Usage

- Download [**m127f_repartition.zip**](https://github.com/theshoqanebi/android_samsung_m12_repartition/releases/latest/download/m127f_repartition.zip).
- Flash it using a custom recovery such as **TWRP**, **OrangeFox**, or similar.

## Disclaimer
I am not responsible for any damage that may occur to your device. Use it at your own risk.

## Credits
This script is a modified version of:
```
Universal repartitioner for the 7870, V1.0
Written by @Astrako
```

## License

This script is licensed under the **Apache License, Version 2.0**.  