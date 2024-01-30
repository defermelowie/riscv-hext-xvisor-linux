MAKEFLAGS += -r --no-print-directory

LOGDIR = ./log
TARGETDIR = ./build

all: xvisor linux

#-------------------------------------------------------------------------------
# Xvisor
#-------------------------------------------------------------------------------

xvisor: xvisor-build

.PHONY: xvisor-%
xvisor-%:
	$(MAKE) -f xvisor.mk $* LOGDIR=$(LOGDIR) TARGETDIR=$(TARGETDIR)

#-------------------------------------------------------------------------------
# Linux
#-------------------------------------------------------------------------------

linux: linux-build

.PHONY: linux-%
linux-%:
	$(MAKE) -f linux.mk $* LOGDIR=$(LOGDIR) TARGETDIR=$(TARGETDIR)

#-------------------------------------------------------------------------------
# Support
#-------------------------------------------------------------------------------

.PHONY: setup clean

setup:
	mkdir -p $(TARGETDIR)
	mkdir -p $(LOGDIR)

clean:
	$(MAKE) -C opensbi clean
	$(MAKE) -C busybox clean
	$(MAKE) -C linux clean
	$(MAKE) -C linux mrproper
	$(MAKE) -C xvisor clean
	rm -f $(TARGETDIR)/*.dtb
	rm -f $(TARGETDIR)/*.cpio
	rm -f $(TARGETDIR)/*.elf
	rm -f $(TARGETDIR)/*.dump
	rm -f $(LOGDIR)/*.log
