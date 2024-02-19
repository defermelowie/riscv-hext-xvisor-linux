# RISC-V Hypervisors

> For testing hypervisor extension support in the Sail model

## Initial setup

Checkout git submodules:
```bash
git submodule update --init
```

Create target directory:
```bash
mkdir target
```

## Linux

### Create device files (can't be tracked by git)

```bash
sudo mknod -m 666 initramfs/dev/null c 1 3
```
```bash
sudo mknod -m 600 initramfs/dev/console c 5 1
```

### Update path of initramfs to embed in linux kernel

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

### Build openSBI with linux kernel payload
```bash
make linux
```

### Run linux on emulator
```bash
make linux-qemu
make linux-spike
make linux-csim # WARNING: takes a long time
```

## Xvisor

### Create device files (can't be tracked by git)

```bash
sudo mknod -m 666 initramfs/dev/null c 1 3
```
```bash
sudo mknod -m 600 initramfs/dev/console c 5 1
```

### Build openSBI with xvisor payload & initrd containing a Linux image

```bash
make xvisor
```

### Update location of xvisor's initrd

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

### Run xvisor on emulator
```bash
echo "autoexec" | make linux-spike
echo "autoexec" | make linux-csim # WARNING: takes a very long time
```
