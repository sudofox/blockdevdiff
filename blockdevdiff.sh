#!/bin/bash

# sudofox/blockdevdiff
# This tool is meant to help with resuming an interrupted disk clone. It's extremely efficient for volumes
# of any size (written for operation on a 24 TB volume)

function logInfo () {
printf "\n[INFO]        $@"

}

function logProgress () {
printf "\r[PROGRESS]    $@"
}

function diff_block () {
  # usage: diff_block /dev/sda $STARTING_OFFSET $SAMPLE_SIZE
  dd if=$1 skip=$2 count=$3 bs=1 status=none
}

function short_md5 () {
  md5sum|awk '{print $1}'
}


if [ $# -lt 5 ]; then
	echo "Usage: $0 </dev/source_device> </dev/target_device> <starting offset> <jump size> <sample size> [email address to notify]"
	exit;
fi;

SOURCE_DEV=$1
TARGET_DEV=$2
START_ADDR=$3
JUMP_SIZE=$4
SAMPLE_SIZE=$5

logInfo "===== Block Device Differ ====="
logInfo "sudofox/blockdevdiff"
logInfo "This tool is read-only and makes no modifications."
logInfo "When the rough point of difference is found, reduce the jump size,"
logInfo "raise the starting offset, and retest until you have an accurate"
logInfo "offset (measured in bytes)."
logInfo "Recommended sample size: 1024 (bytes)"
logInfo "Starting time:		$(date)"
logInfo "Source device:		$SOURCE_DEV"
logInfo "Target device:		$TARGET_DEV"
logInfo "Starting at offset:	$START_ADDR"
logInfo "Jump size:		$JUMP_SIZE"
logInfo "Sample size:		$SAMPLE_SIZE"

if [ ! -z "$6" ]; then
	NOTIFY_EMAIL=$6
	logInfo "$NOTIFY_EMAIL will be notified upon completion"
fi;
# validation

# source drive
if [[ $(file $SOURCE_DEV|grep -Po ":\ \K.*") != "block special" ]]; then
	logInfo "$SOURCE_DEV is not a block device"
fi;

# target drive
if [[ $(file $TARGET_DEV|grep -Po ":\ \K.*") != "block special" ]]; then
	logInfo "$TARGET_DEV is not a block device"
fi;

CURRENT_OFFSET=$START_ADDR

logInfo "Starting...\n"

BLOCKS_DIFFER=false

while [[ $BLOCKS_DIFFER == false ]]; do

  SOURCE_SAMPLE_HASH=$(diff_block $SOURCE_DEV $CURRENT_OFFSET $SAMPLE_SIZE | short_md5);
  TARGET_SAMPLE_HASH=$(diff_block $TARGET_DEV $CURRENT_OFFSET $SAMPLE_SIZE | short_md5);


  logProgress "Offset $CURRENT_OFFSET | Source $(echo $SOURCE_SAMPLE_HASH |head -c6)...| Target $(echo $TARGET_SAMPLE_HASH|head -c6)..."
  if [[ "$SOURCE_SAMPLE_HASH" != "$TARGET_SAMPLE_HASH" ]]; then
	BLOCKS_DIFFER=true;
	logInfo "Sample differed at position $CURRENT_OFFSET, sample size $SAMPLE_SIZE bytes\n"

  else
	CURRENT_OFFSET=$(($CURRENT_OFFSET+$JUMP_SIZE));
  fi;
done;

echo "======== FOUND DIFFERENCE ========"
echo "Ending time: $(date)"
echo "Found difference at offset $CURRENT_OFFSET"
echo "SOURCE_SAMPLE_HASH = $SOURCE_SAMPLE_HASH"
echo "TARGET_SAMPLE_HASH = $TARGET_SAMPLE_HASH"

if [[ ! -z $NOTIFY_EMAIL ]]; then
	echo "Notifying $NOTIFY_EMAIL..."
	echo "blockdevdiff found diff at $CURRENT_OFFSET - Source hash $SOURCE_SAMPLE_HASH, target hash $TARGET_SAMPLE_HASH" | mail $NOTIFY_EMAIL
fi;

