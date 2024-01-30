CROSS_COMPILE=riscv64-unknown-linux-gnu-

CSIM=../sail-riscv/c_emulator/riscv_sim_RV64
QEMU=qemu-system-riscv64
SPIKE=spike

LOGDIR=./log
TARGETDIR=./target

#-------------------------------------------------------------------------------

XVISOR_CONFIG := xvisor_rv64-defconfig
XVISOR_INITRD := $(TARGETDIR)/initrd.cpio
XVISOR_BIN := $(TARGETDIR)/xvisor_vmm.bin
XVISOR_ELF := $(TARGETDIR)/opensbi_xvisor_payload.elf
XVISOR_DTB := $(TARGETDIR)/rv64gch_xvisor.dtb

GUEST_IMAGE  := $(TARGETDIR)/Image
GUEST_ROOTFS := $(TARGETDIR)/linux_initramfs.cpio

#-------------------------------------------------------------------------------
# Build openSBI with Xvisor as payload
#-------------------------------------------------------------------------------

.PHONY: build
build: $(XVISOR_ELF)

$(XVISOR_ELF): $(XVISOR_BIN)
	$(MAKE) -C ./opensbi/ PLATFORM=generic CROSS_COMPILE=$(CROSS_COMPILE) FW_PAYLOAD_PATH=../$(XVISOR_BIN) -j$$(nproc)
	cp opensbi/build/platform/generic/firmware/fw_payload.elf $@

$(XVISOR_INITRD): xvisor_guest.dts xvisor_linux.dts $(GUEST_IMAGE) $(GUEST_ROOTFS)
# DEBUG: Delete existing structure & create new one from scratch
# rm -rf ./disks/xvisor_initrd/*
# mkdir -p ./disks/xvisor_initrd/tmp
# mkdir -p ./disks/xvisor_initrd/system
# mkdir -p ./disks/xvisor_initrd/images/riscv/virt64/
# cp -f ./xvisor/docs/banner/roman.txt ./disks/xvisor_initrd/system/banner.txt
# cp -f ./xvisor/tests/riscv/virt64/xscript/one_guest_virt64.xscript ./disks/xvisor_initrd/boot.xscript
# cp -f ./xvisor/tests/riscv/virt64/linux/nor_flash.list ./disks/xvisor_initrd/images/riscv/virt64/nor_flash.list
# cp -f ./xvisor/tests/riscv/virt64/linux/cmdlist ./disks/xvisor_initrd/images/riscv/virt64/cmdlist
# Create guest device tree blob (for xvisor)
	dtc xvisor_guest.dts > ./disks/xvisor_initrd/images/riscv/virt64-guest.dtb
# Build and copy basic firmware
	$(MAKE) -C ./xvisor/tests/riscv/virt64/basic ARCH=riscv CROSS_COMPILE=$(CROSS_COMPILE)
	cp -f ./xvisor/build/tests/riscv/virt64/basic/firmware.bin ./disks/xvisor_initrd/images/riscv/virt64/firmware.bin
# Copy guest's image, device tree blob and root file system
	cp -f $(GUEST_IMAGE) ./disks/xvisor_initrd/images/riscv/virt64/Image
	dtc xvisor_linux.dts > ./disks/xvisor_initrd/images/riscv/virt64/virt64.dtb
	cp -f $(GUEST_ROOTFS) ./disks/xvisor_initrd/images/riscv/virt64/rootfs.img
# Build initrd archive
	cd disks/xvisor_initrd && find . -print0 | cpio --null -ov --format=newc --owner root:root > ../../$(XVISOR_INITRD)

$(XVISOR_BIN): $(XVISOR_CONFIG)
	cp $(XVISOR_CONFIG) ./xvisor/arch/riscv/configs/
	$(MAKE) -C ./xvisor/ ARCH=riscv $(XVISOR_CONFIG)
	$(MAKE) -C ./xvisor/ ARCH=riscv CROSS_COMPILE=$(CROSS_COMPILE) -j$$(nproc)
	cp xvisor/build/vmm.bin $@

$(TARGETDIR)/%.dtb: %.dts
	dtc $< > $@

#-------------------------------------------------------------------------------
# Run on emulators
#-------------------------------------------------------------------------------

.PHONY: csim spike qemu
csim: $(XVISOR_ELF) $(XVISOR_DTB)
	$(CSIM) -Vmem -Vplatform -Vreg -Vinstr \
	--enable-dirty-update --enable-pmp --mtval-has-illegal-inst-bits --xtinst-has-transformed-inst \
	--ram-size 512 --device-tree-blob $(XVISOR_DTB) $<

spike: $(XVISOR_ELF) $(XVISOR_DTB)
	$(SPIKE) --isa rv64gchv_zbb_zicsr -m512 --dtb=$(XVISOR_DTB) $<

# For debug purposes only
qemu: $(XVISOR_BIN) $(XVISOR_INITRD) $(XVISOR_ELF)
	$(QEMU) -machine virt -cpu rv64,h=true -nographic -m 512M \
	-bios opensbi/build/platform/generic/firmware/fw_jump.bin \
	-kernel $(XVISOR_BIN) -initrd $(XVISOR_INITRD) \
	-append 'vmm.bootcmd="vfs mount initrd /;vfs run /boot.xscript"'
