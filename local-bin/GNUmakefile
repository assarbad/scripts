BASICFILES ?= etckeeper-commit istat save-pkgstates reinstall-grub showsubids lxc-guest-create generate_mac sync-etc-hosts-and-lxc-guest-configs
ALLFILES ?= $(BASICFILES)
TARGET ?= /usr/local/bin

.PHONY: all basic

all: $(addprefix $(TARGET)/,$(ALLFILES))
basic: $(addprefix $(TARGET)/,$(BASICFILES))

$(TARGET)/%: %
	test -d $(dir $@) || mkdir -p $(dir $@)
	cp -a $< $@
	-test $(shell id -u) -eq 0 && chown root:root $@ && chmod u=rwx,go=rx $@

