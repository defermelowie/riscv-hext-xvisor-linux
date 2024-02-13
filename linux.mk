CROSS_COMPILE=riscv64-unknown-linux-gnu-

CSIM=../sail-riscv/c_emulator/riscv_sim_RV64
QEMU=qemu-system-riscv64
SPIKE=spike

LOGDIR=./log
TARGETDIR=./target

#-------------------------------------------------------------------------------

BBOX_CONFIG  := busybox_config
LINUX_CONFIG := linux_rv64_defconfig
LINUX_INITRAMFS := $(TARGETDIR)/linux_initramfs.cpio
LINUX_IMAGE := $(TARGETDIR)/Image
LINUX_ELF   := $(TARGETDIR)/opensbi_linux_payload.elf
LINUX_DTB   := $(TARGETDIR)/rv64gch_linux.dtb

#-------------------------------------------------------------------------------
# Build openSBI with linux image as payload
#-------------------------------------------------------------------------------

.PHONY: build
build: $(LINUX_ELF) $(LINUX_DTB)

$(LINUX_ELF): $(LINUX_IMAGE)
	$(MAKE) -C ./opensbi/ PLATFORM=generic CROSS_COMPILE=$(CROSS_COMPILE) FW_PAYLOAD_PATH=../$(LINUX_IMAGE) -j$$(nproc)
	cp opensbi/build/platform/generic/firmware/fw_payload.elf $@

$(LINUX_IMAGE): $(LINUX_CONFIG) $(LINUX_INITRAMFS)
	INITRAMFS=$$(realpath $(LINUX_INITRAMFS) | sed -e "s:\/:\\\/:g"); echo $$INITRAMFS;\
	sed -i -e "s/<LINUX_INITRAMFS>/$$INITRAMFS/g" $(LINUX_CONFIG)
	cp $(LINUX_CONFIG) ./linux/arch/riscv/configs/$(LINUX_CONFIG)
	$(MAKE) -C linux O=build ARCH=riscv $(LINUX_CONFIG)
	$(MAKE) -C linux O=build ARCH=riscv CROSS_COMPILE=$(CROSS_COMPILE) Image -j$$(nproc)
	cp linux/build/arch/riscv/boot/Image $(LINUX_IMAGE)

$(LINUX_INITRAMFS): $(BBOX_CONFIG) disks/linux_initramfs/init
	-mknod -m 666 disks/linux_initramfs/dev/null c 1 3
	-mknod -m 600 disks/linux_initramfs/dev/console c 5 1
	cp $(BBOX_CONFIG) busybox/.config
	$(MAKE) -C busybox ARCH=riscv CROSS_COMPILE=$(CROSS_COMPILE) -j$$(nproc)
	$(MAKE) -C busybox ARCH=riscv CROSS_COMPILE=$(CROSS_COMPILE) install CONFIG_PREFIX=../disks/linux_initramfs/
	cd disks/linux_initramfs && find . -print0 | cpio --null -ov --format=newc --owner root:root > ../../$(LINUX_INITRAMFS)

$(TARGETDIR)/%.dtb: %.dts
	dtc $< > $@

#-------------------------------------------------------------------------------
# Debug: Modify $(LINUX_CONFIG)
#-------------------------------------------------------------------------------

.PHONY: config
config:
	cp $(LINUX_CONFIG) ./linux/arch/riscv/configs/$(LINUX_CONFIG)
	$(MAKE) -C linux O=build ARCH=riscv $(LINUX_CONFIG)
	$(MAKE) -C linux O=build ARCH=riscv menuconfig
	$(MAKE) -C linux O=build ARCH=riscv savedefconfig
	cp linux/build/defconfig $(LINUX_CONFIG)

#-------------------------------------------------------------------------------
# Run on emulators
#-------------------------------------------------------------------------------

.PHONY: csim spike qemu

csim: $(LINUX_ELF) $(LINUX_DTB)
	$(CSIM) -Vmem -Vplatform -Vreg -Vinstr \
	--enable-dirty-update --enable-pmp --mtval-has-illegal-inst-bits --xtinst-has-transformed-inst \
	--ram-size 512 --device-tree-blob $(LINUX_DTB) $<

spike: $(LINUX_ELF) $(LINUX_DTB)
	$(SPIKE) --isa rv64gchv_zbb_zicsr -m512 --dtb=$(LINUX_DTB) $<

# For debug purposes only
qemu: $(LINUX_ELF)
	$(QEMU) -machine virt -cpu rv64,h=true -nographic -m 512M -bios $<
