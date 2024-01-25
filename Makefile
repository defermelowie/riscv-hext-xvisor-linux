CROSS_COMPILE=riscv64-unknown-linux-gnu-

SAIL_OSIM=../sail-riscv/ocaml_emulator/riscv_ocaml_sim_RV64
SAIL_CSIM=../sail-riscv/c_emulator/riscv_sim_RV64
QEMU=qemu-system-riscv64
SPIKE=spike

LOGDIR=./log
TARGETDIR=./target

#-------------------------------------------------------------------------------
# openSBI with Xvisor payload
#-------------------------------------------------------------------------------

XVISOR_CONFIG := xvisor-sail-64b-defconfig
XVISOR_ELF := $(TARGETDIR)/opensbi_xvisor_payload.elf
XVISOR_DTB := $(TARGETDIR)/rv64gch.dtb

.PHONY: xvisor
xvisor: $(XVISOR_ELF)

$(XVISOR_ELF): xvisor/build/vmm.bin
	$(MAKE) -C ./opensbi/ PLATFORM=generic CROSS_COMPILE=$(CROSS_COMPILE) FW_PAYLOAD_PATH=../$<
	cp opensbi/build/platform/generic/firmware/fw_payload.elf $@

xvisor/build/vmm.bin: xvisor/build/openconf/.config
	$(MAKE) -C ./xvisor/ ARCH=riscv CROSS_COMPILE=$(CROSS_COMPILE) -j$(nproc)

xvisor/build/openconf/.config: $(XVISOR_CONFIG)
	cp $< ./xvisor/arch/riscv/configs/
	$(MAKE) -C ./xvisor/ ARCH=riscv $<

#-------------------------------------------------------------------------------

.PHONY: xvisor-csim
xvisor-csim: $(XVISOR_ELF) $(XVISOR_DTB)
	$(SAIL_CSIM) -Vmem -Vplatform -Vreg -Vinstr \
	--enable-dirty-update --enable-pmp --mtval-has-illegal-inst-bits --xtinst-has-transformed-inst \
	--ram-size 512 --device-tree-blob $(XVISOR_DTB) $<

.PHONY: xvisor-spike
xvisor-spike: $(XVISOR_ELF) $(XVISOR_DTB)
	$(SPIKE) --isa rv64gch -m512 --dtb=$(XVISOR_DTB) $<

# For debug purposes only
.PHONY: xvisor-qemu
xvisor-qemu: $(XVISOR_ELF)
	$(QEMU) -machine virt -cpu rv64,h=true -nographic -m 512M -bios $<

#-------------------------------------------------------------------------------
# openSBI with linux payload
#-------------------------------------------------------------------------------

LINUX_CONFIG := linux-sail-64b_defconfig
LINUX_ELF := $(TARGETDIR)/opensbi_linux_payload.elf
LINUX_INITRAMFS := $(TARGETDIR)/initramfs.cpio
LINUX_DTB := $(TARGETDIR)/rv64gch.dtb

# # Debug target: modify linux-sail-64b_defconfig using menuconfig
# .PHONY: linuxconfig
# linuxconfig: linux/build/.config
# 	$(MAKE) -C linux O=build ARCH=riscv menuconfig
# 	$(MAKE) -C linux O=build ARCH=riscv savedefconfig
# 	cp linux/build/defconfig $(LINUX_CONFIG)

.PHONY: linux
linux: $(LINUX_ELF) $(LINUX_INITRAMFS)

$(LINUX_ELF): linux/build/arch/riscv/boot/Image
	$(MAKE) -C ./opensbi/ PLATFORM=generic CROSS_COMPILE=$(CROSS_COMPILE) FW_PAYLOAD_PATH=../$<
	cp opensbi/build/platform/generic/firmware/fw_payload.elf $@

linux/build/arch/riscv/boot/Image: linux/build/.config $(LINUX_INITRAMFS)
	$(MAKE) -C linux O=build ARCH=riscv CROSS_COMPILE=$(CROSS_COMPILE) Image -j8

linux/build/.config: $(LINUX_CONFIG)
	cp $< ./linux/arch/riscv/configs/$<
	$(MAKE) -C linux O=build ARCH=riscv $<

$(LINUX_INITRAMFS): busybox/busybox initramfs/*
	cp busybox/busybox initramfs/bin/
	cd initramfs && find . -print0 | cpio --null -ov --format=newc --owner root:root > ../$(LINUX_INITRAMFS)

busybox/busybox: busybox-config
	cp busybox-config busybox/.config
	$(MAKE) -C busybox ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- -j 8

#-------------------------------------------------------------------------------

.PHONY: linux-csim
linux-csim: $(LINUX_ELF) $(LINUX_DTB)
	$(SAIL_CSIM) -Vmem -Vplatform -Vreg -Vinstr \
	--enable-dirty-update --enable-pmp --mtval-has-illegal-inst-bits --xtinst-has-transformed-inst \
	--ram-size 512 --device-tree-blob $(LINUX_DTB) $<

.PHONY: linux-spike
linux-spike: $(LINUX_ELF) $(LINUX_DTB)
	$(SPIKE) --isa rv64gch_zbb_zicsr -m512 --dtb=$(LINUX_DTB) $<

# For debug purposes only
.PHONY: linux-qemu
linux-qemu: $(LINUX_ELF)
	$(QEMU) -machine virt -cpu rv64,h=true -nographic -m 512M -bios $<

#-------------------------------------------------------------------------------
# Support targets
#-------------------------------------------------------------------------------

rv64-osim.dts:
	$(SAIL_OSIM) -dump-dts -o $@

rv64-spike.dts:
	$(SPIKE) --isa rv64gch -m512 --dump-dts none > $@

$(TARGETDIR)/%.dtb: %.dts
	dtc $< > $@

.PHONY: clean
clean:
	$(MAKE) -C ./opensbi/ clean
	$(MAKE) -C busybox clean
	rm -f ./initramfs/bin/busybox
	$(MAKE) -C ./linux/ clean
	$(MAKE) -C linux ARCH=riscv mrproper
	rm -f ./linux/arch/riscv/configs/$(LINUX_CONFIG)
	rm -f ./linux/build/arch/riscv/boot/Image
	$(MAKE) -C ./xvisor/ clean
	rm -f ./xvisor/arch/riscv/configs/$(XVISOR_CONFIG)
	rm -f $(TARGETDIR)/*.dtb
	rm -f $(TARGETDIR)/*.cpio
	rm -f $(TARGETDIR)/*.elf
	rm -f $(TARGETDIR)/*.dump
	rm -f $(LOGDIR)/*.log
