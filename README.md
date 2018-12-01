# sudofox/blockdevdiff

This tool is meant to help with resuming an interrupted disk clone. It's extremely efficient for volumes of any size (written for operation on a 24 TB volume after _something_ crashed)

## Usage

```
Usage: ./blockdevdiff.sh </dev/source_device> </dev/target_device> <starting offset> <jump size> <sample size> [email address to notify]
```


```
# ./blockdevdiff.sh testfile1.bin testfile2.bin 0 100 10
INFO]        ===== Block Device Differ =====
[INFO]        sudofox/blockdevdiff
[INFO]        This tool is read-only and makes no modifications.
[INFO]        When the rough point of difference is found, reduce the jump size,
[INFO]        raise the starting offset, and retest until you have an accurate
[INFO]        offset (measured in bytes).
[INFO]        Recommended sample size: 1024 (bytes)
[INFO]        Starting time:		Fri Nov 30 21:34:10 EST 2018
[INFO]        Source device:		testfile1.bin
[INFO]        Target device:		testfile2.bin
[INFO]        Starting at offset:	0
[INFO]        Jump size:		100
[INFO]        Sample size:		10
[INFO]        testfile1.bin is not a block device
[INFO]        testfile2.bin is not a block device
[INFO]        Starting...
[PROGRESS]    Offset 25000 | Source 6fbb8d...| Target 858a9a...
[INFO]        Sample differed at position 25000, sample size 10 bytes
======== FOUND DIFFERENCE ========
Ending time: Fri Nov 30 21:34:12 EST 2018
Found difference at offset 25000
SOURCE_SAMPLE_HASH = 6fbb8d9e8669ba6ea174b5011c97fe80
TARGET_SAMPLE_HASH = 858a9a2907c7586ef27951799e55d0e8
```

## Translating to a dd

_I am not responsible for if you destroy your data doing this_

Let's say we started with the following command:

```
dd if=/dev/source_device_here of=/dev/target_device_here bs=128k status=progress
```

Somewhere between 16 and 19 terabytes into the process, your server crashes. Perhaps your RAID card overheated. Now what?

Well, we can use our handy blockdevdiff tool to find out roughly where the data starts to diff. Start proportional to how big your volume is; arguments for blockdevdiff are in bytes.

Start big, using a skip size of ~50 GB or so, and then when you start getting different data, set your start size to the point you hit minus the skip size, reduce the skip size, and run it again.

```
[INFO]        ===== Block Device Differ =====
[INFO]        sudofox/blockdevdiff
[INFO]        This tool is read-only and makes no modifications.
[INFO]        When the rough point of difference is found, reduce the jump size,
[INFO]        raise the starting offset, and retest until you have an accurate
[INFO]        offset (measured in bytes).
[INFO]        Recommended sample size: 1024 (bytes)
[INFO]        Starting time:		Fri Nov 30 21:43:08 EST 2018
[INFO]        Source device:		/dev/sda
[INFO]        Target device:		/dev/sdb
[INFO]        Starting at offset:	17003360000000
[INFO]        Jump size:		1000000000
[INFO]        Sample size:		100
[INFO]        Starting...
[PROGRESS]    Offset 17074360000000 | Source 684146...| Target 6d0bb0...
[INFO]        Sample differed at position 17074360000000, sample size 100
======== FOUND DIFFERENCE ========
Ending time: Fri Nov 30 21:43:28 EST 2018
Found difference at offset 17074360000000
SOURCE_SAMPLE_HASH = 68414605a320573a0f9ad1c8e71ab013
TARGET_SAMPLE_HASH = 6d0bb00954ceb7fbee436bb55a8397a9
```

Keep going until you get close enough to a starting point which is reasonable for your volume's size.

Once you have your number, round it down generously. I rounded mine down a few hundred gigabytes just to be sure: it's better to start too early than too late.

Here is your new command (DO NOT COPY AND PASTE)

```
dd if=/dev/source_device_here of=/dev/target_device_here bs=128K conv=notrunc seek=XXXXXXXXX skip=XXXXXXXXXXX iflag=skip_bytes oflag=seek_bytes status=progress
```

if: input file (e.g. a device file like /dev/sda)

of: output file

Apparently conv=notrunc doesn't really make any difference for actual block devices, so just leave it in.

If you are using this on VM images stored on another filesystem then you DEFINITELY want it.

Pass the iflag=skip_bytes and oflag=seek_bytes, so that we can use bytes instead of blocks here, which makes things less confusing overall.

seek: dictates the position to start copying bytes from the source device

skip: dictates the position to start copying bytes to the target device

seek and skip should be the same! 

status=progress: so you can actually see what dd is doing

## "Email when done" functionality.
This will require some installed mailserver (e.g. Exim, Postfix, etc) so that the "mail" binary will function.
In cases where you need to get a really specific offset on a really big volume, you can pass one final argument containing an email address.

You will be emailed when blockdevdiff has finished.


