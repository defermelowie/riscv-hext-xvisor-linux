MAKEFLAGS += -r --no-print-directory

LOGDIR = ./log
TARGETDIR = ./target

all: setup clean xvisor

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
	cd opensbi && git stash -u
	cd busybox && git stash -u
	cd linux && git stash -u
	cd xvisor && git stash -u
	rm -f $(TARGETDIR)/*
	rm -f $(LOGDIR)/*
