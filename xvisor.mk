CROSS_COMPILE=riscv64-unknown-linux-gnu-

CSIM=../sail-riscv/c_emulator/riscv_sim_RV64
QEMU=qemu-system-riscv64
SPIKE=spike

LOGDIR=./log
TARGETDIR=./target

#-------------------------------------------------------------------------------

XVISOR_CONFIG := xvisor_rv64-defconfig
XVISOR_ELF := $(TARGETDIR)/opensbi_xvisor_payload.elf
XVISOR_DTB := $(TARGETDIR)/rv64gch_xvisor.dtb

#-------------------------------------------------------------------------------
# Build openSBI with Xvisor as payload
#-------------------------------------------------------------------------------

.PHONY: build
build: $(XVISOR_ELF)

$(XVISOR_ELF): xvisor/build/vmm.bin
	$(MAKE) -C ./opensbi/ PLATFORM=generic CROSS_COMPILE=$(CROSS_COMPILE) FW_PAYLOAD_PATH=../$< -j$$(nproc)
	cp opensbi/build/platform/generic/firmware/fw_payload.elf $@

xvisor/build/vmm.bin: xvisor/build/openconf/.config
	$(MAKE) -C ./xvisor/ ARCH=riscv CROSS_COMPILE=$(CROSS_COMPILE) -j$$(nproc)

xvisor/build/openconf/.config: $(XVISOR_CONFIG)
	cp $< ./xvisor/arch/riscv/configs/
	$(MAKE) -C ./xvisor/ ARCH=riscv $<

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
	$(SPIKE) --isa rv64gch_zbb_zicsr -m512 --dtb=$(XVISOR_DTB) $<

# For debug purposes only
qemu: $(XVISOR_ELF)
	$(QEMU) -machine virt -cpu rv64,h=true -nographic -m 512M -bios $<
