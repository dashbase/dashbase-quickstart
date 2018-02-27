#!/usr/bin/env bash
# some basic stats on the index
ROOTDIR=$1
if [ "$ROOTDIR" == "" ]
then
  echo "Usage: $0 <index root>"
  echo "e.g. $0 /data/index/dashbase_p0"
  exit 1
fi

RAW_SIZE_KB=$(find $ROOTDIR/store -name dashbase_segment_info -exec grep "rawSizeKB=" '{}' \; | grep -o [0-9]* | awk '{ sum += $1 } END { print sum }')
let RAW_SIZE_MB=RAW_SIZE_KB/1024
echo "Raw size: $RAW_SIZE_MB MB"
INDEX_SIZE_MB=$(du -s -BM $ROOTDIR/store | grep -o "^[0-9]*")
echo "Index size: $INDEX_SIZE_MB MB"
PAYLOAD_SIZE_MB=$(du -s -BM $ROOTDIR/payload | grep -o "^[0-9]*")
echo "Payload size: $PAYLOAD_SIZE_MB MB"

let TOTAL_DISK=INDEX_SIZE_MB+PAYLOAD_SIZE_MB
let RATIO=TOTAL_DISK*100/RAW_SIZE_MB
echo "Total size on disk: $TOTAL_DISK MB"
echo "Indexed size / original size: $RATIO%"
