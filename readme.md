# RISC-V Hypervisors

[![Linux](https://github.com/defermelowie/riscv-hext-xvisor-linux/actions/workflows/linux.yml/badge.svg)](https://github.com/defermelowie/riscv-hext-xvisor-linux/actions/workflows/linux.yml)
[![Xvisor](https://github.com/defermelowie/riscv-hext-xvisor-linux/actions/workflows/xvisor.yml/badge.svg)](https://github.com/defermelowie/riscv-hext-xvisor-linux/actions/workflows/xvisor.yml)
[![Build & release docker images](https://github.com/defermelowie/riscv-hext-xvisor-linux/actions/workflows/dockerize.yml/badge.svg)](https://github.com/defermelowie/riscv-hext-xvisor-linux/actions/workflows/dockerize.yml)

> **_NOTE:_** Xvisor run "fails" due to timeout since Xvisor is never shutdown after Linux successfully exits.
> This issue probably won't be solved due to time constraints.
> Nevertheless, the job is left enabled since manual inspection of the logs still provides relevant information about the simulation.

The main reason this repository exist is to build binaries for testing hypervisor extension support in the RISC-V Sail model.
There are two different targets:
- An image with [linux](./linux/) directly on top of the [openSBI](./opensbi/) firmware
- An image with [linux](./linux/) as guest OS in [Xvisor](./xvisor/) on top of the [openSBI](./opensbi/) firmware

## Getting started - Docker

Prebuild images are available with the spike emulator and the Sail extracted C emulator:

|           | **Linux**                                                                     | **Xvisor**                                                                      |
|-----------|-------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| **Spike** | [`linux-spike`](ghcr.io/defermelowie/riscv-hext-xvisor-linux/linux-spike:wip) | [`xvisor-spike`](ghcr.io/defermelowie/riscv-hext-xvisor-linux/xvisor-spike:wip) |
| **CSim**  | [`linux-csim`](ghcr.io/defermelowie/riscv-hext-xvisor-linux/linux-csim:wip)   | [`xvisor-csim`](ghcr.io/defermelowie/riscv-hext-xvisor-linux/xvisor-csim:wip)   |

These images can be used in similar fashion as the following `xvisor-csim` example.

```sh
$ docker run --rm --name wip -it ghcr.io/defermelowie/riscv-hext-xvisor-linux/xvisor-csim:wip

root@1a3a7c7bc7ce:/hyp# echo "autoexec" | ./sim/sail/c_emulator/riscv_sim_RV64 -Vmem -Vplatform -Vreg -Vinstr --enable-dirty-update --enable-pmp --mtval-has-illegal-inst-bits --xtinst-has-transformed-inst --ram-size 1024 --device-tree-blob rv64gch_xvisor.dtb opensbi_xvisor_payload.elf

...
```

## Getting started - Local

### Initial setup

Checkout git submodules:
```bash
git submodule update --init
```

Create target directory:
```bash
mkdir target
```

### Linux

#### Create device files (can't be tracked by git)

```bash
sudo mknod -m 666 initramfs/dev/null c 1 3
```
```bash
sudo mknod -m 600 initramfs/dev/console c 5 1
```

#### Update path of initramfs to embed in linux kernel

First get the new path:
```bash
echo $(pwd)/target/initramfs.cpio
```
Next, update [`linux-sail-64b_defconfig`](./linux-sail-64b_defconfig)
```diff
 CONFIG_NAMESPACES=y
 CONFIG_USER_NS=y
 CONFIG_CHECKPOINT_RESTORE=y
 CONFIG_BLK_DEV_INITRD=y
-CONFIG_INITRAMFS_SOURCE="old_initramfs.cpio"
+CONFIG_INITRAMFS_SOURCE="new_initramfs.cpio"
 # CONFIG_RD_BZIP2 is not set
 # CONFIG_RD_LZMA is not set
 # CONFIG_RD_XZ is not set
```

#### Build openSBI with linux kernel payload
```bash
make linux
```

#### Run linux on emulator
```bash
make linux-qemu
make linux-spike
make linux-csim # WARNING: takes a long time
```

### Xvisor

#### Create device files (can't be tracked by git)

```bash
sudo mknod -m 666 initramfs/dev/null c 1 3
```
```bash
sudo mknod -m 600 initramfs/dev/console c 5 1
```

#### Build openSBI with xvisor payload & initrd containing a Linux image

```bash
make xvisor
```

#### Update location of xvisor's initrd

Find `initrd` address & update [`rv64gch_xvisor.dts`](rv64gch_xvisor.dts)
```bash
riscv64-unknown-linux-gnu-objdump -x target/opensbi_xvisor_payload.elf | grep _initrd_
```

```diff
   chosen {
     stdout-path = &HTIF;
     bootargs = "vmm.bootcmd=\"vfs mount initrd /; vfs run /boot.xscript\"";
-    linux,initrd-start = <0x82000000>;
+    linux,initrd-start = <0x802a9540>;
-    linux,initrd-end   = <0x82800000>;
+    linux,initrd-end   = <0x812eef40>;
   };
```

#### Run xvisor on emulator
```bash
echo "autoexec" | make xvisor-spike
echo "autoexec" | make xvisor-csim # WARNING: takes a very long time
```
