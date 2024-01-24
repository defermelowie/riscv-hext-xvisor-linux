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
# Support targets
#-------------------------------------------------------------------------------

rv64-osim.dts:
	$(SAIL_OSIM) -dump-dts -o $@

rv64-spike.dts:
	$(SPIKE) --dump-dts none > $@

$(TARGETDIR)/%.dtb: %.dts
	dtc $< > $@

.PHONY: clean
clean:
	$(MAKE) -C ./opensbi/ clean
	$(MAKE) -C ./xvisor/ clean
	rm -f ./xvisor/arch/riscv/configs/$(XVISOR_CONFIG)
	rm -f $(TARGETDIR)/*.dtb
	rm -f $(TARGETDIR)/*.dump
	rm -f $(LOGDIR)/*.log
