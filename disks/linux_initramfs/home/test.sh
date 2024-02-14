#!/bin/busybox sh

echo "[test] Show file structure"
ls -alh /

echo "[test] Show processes"
top -b -n 1 > /home/top.txt
cat /home/top.txt

echo "[test] Shutting down"
poweroff -f
