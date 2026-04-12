ROCKY_VERSION := 9
ROCKY_ARCH := x86_64
BASE_URL := https://dl.rockylinux.org/pub/rocky/$(ROCKY_VERSION)/images/$(ROCKY_ARCH)
BASE_IMAGE := Rocky-$(ROCKY_VERSION)-GenericCloud-Base.latest.$(ROCKY_ARCH).qcow2
OUTPUT := rocky$(ROCKY_VERSION)-desktop-xrdp.qcow2
SUDO := $(if $(filter 0,$(shell id -u)),,sudo)
OUTPUT_UID := $(shell stat -c '%u' .)
OUTPUT_GID := $(shell stat -c '%g' .)
QEMU_SYSTEM ?= qemu-system-x86_64
RUN_MEMORY ?= 4096
RUN_CPUS ?= 2
RUN_SSH_PORT ?= 2222
RUN_RDP_PORT ?= 3390
RUN_ACCEL := $(if $(wildcard /dev/kvm),-enable-kvm -cpu host,)
RUN_QEMU_ARGS ?=

.PHONY: all build clean check-deps check-run-deps download compress run

all: build compress

check-deps:
	@command -v virt-customize >/dev/null 2>&1 || \
		{ echo "ERROR: virt-customize not found. Install your distro's libguestfs tools package."; exit 1; }
	@command -v qemu-img >/dev/null 2>&1 || \
		{ echo "ERROR: qemu-img not found. Install your distro's qemu image tools package."; exit 1; }
	@command -v dhclient >/dev/null 2>&1 || \
		{ echo "ERROR: dhclient not found. Install isc-dhcp-client on Debian/Ubuntu hosts."; exit 1; }

check-run-deps:
	@command -v $(QEMU_SYSTEM) >/dev/null 2>&1 || \
		{ echo "ERROR: $(QEMU_SYSTEM) not found. Install your distro's qemu-system-x86 package."; exit 1; }

download: $(BASE_IMAGE)

$(BASE_IMAGE):
	curl -L -o $(BASE_IMAGE) $(BASE_URL)/$(BASE_IMAGE)

build: check-deps $(BASE_IMAGE)
	$(SUDO) cp $(BASE_IMAGE) $(OUTPUT)
	$(SUDO) virt-customize -a $(OUTPUT) --commands-from-file run-command.virt
	$(SUDO) chown $(OUTPUT_UID):$(OUTPUT_GID) $(OUTPUT)

compress: $(OUTPUT)
	$(SUDO) qemu-img convert -c -O qcow2 $(OUTPUT) $(OUTPUT).tmp
	$(SUDO) mv $(OUTPUT).tmp $(OUTPUT)
	$(SUDO) chown $(OUTPUT_UID):$(OUTPUT_GID) $(OUTPUT)
	@echo "Final image: $(OUTPUT) ($$(du -h $(OUTPUT) | cut -f1))"

clean:
	$(SUDO) rm -f $(OUTPUT)

run: check-run-deps
	@test -f $(OUTPUT) || { echo "ERROR: $(OUTPUT) not found. Run 'make' first."; exit 1; }
	@echo "Booting $(OUTPUT)"
	@echo "SSH: localhost:$(RUN_SSH_PORT)"
	@echo "RDP: localhost:$(RUN_RDP_PORT)"
	$(QEMU_SYSTEM) $(RUN_ACCEL) \
		-m $(RUN_MEMORY) \
		-smp $(RUN_CPUS) \
		-drive file=$(OUTPUT),format=qcow2,if=virtio \
		-nic user,model=virtio-net-pci,hostfwd=tcp::$(RUN_SSH_PORT)-:22,hostfwd=tcp::$(RUN_RDP_PORT)-:3389 \
		-serial mon:stdio \
		-display none \
		-no-reboot \
		$(RUN_QEMU_ARGS)

distclean: clean
	rm -f $(BASE_IMAGE)
