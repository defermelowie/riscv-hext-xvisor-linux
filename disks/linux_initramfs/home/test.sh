#!/bin/busybox sh

echo "[test] Show file structure"
ls -alh /

echo "[test] Try filesystem operations"
cd /tmp
pwd
ls -alh
echo "hello world" > newfile.txt
mkdir newfolder
cp newfile.txt newerfile.txt
hexdump -C newerfile.txt
ls -alh

echo "[test] Busybox help"
busybox --help

echo "[test] Linux boot complete"

echo "[test] Shutting down"
poweroff -f
