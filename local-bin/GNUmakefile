BASICFILES ?= etckeeper-commit istat save-pkgstates reinstall-grub showsubids lxc-guest-create
ALLFILES ?= $(BASICFILES) vsmount vsumount
TARGET ?= /usr/local/bin

.PHONY: all basic

all: $(addprefix $(TARGET)/,$(ALLFILES))
basic: $(addprefix $(TARGET)/,$(BASICFILES))

$(TARGET)/%: %
	test -d $(dir $@) || mkdir -p $(dir $@)
	cp -a $< $@
	-test $(shell id -u) -eq 0 && chown root:root $@ && chmod u=rwx,go=rx $@

