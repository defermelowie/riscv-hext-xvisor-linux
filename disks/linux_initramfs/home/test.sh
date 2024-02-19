#!/bin/busybox sh

echo "[test] Show file structure"
ls -alh /

echo "[test] Busybox help"
busybox --help

echo "[test] Linux boot complete"

echo "[test] Shutting down"
poweroff -f
