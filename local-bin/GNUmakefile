BASICFILES ?= etckeeper-commit istat save-pkgstates reinstall-grub showsubids
ALLFILES ?= $(BASICFILES) vsmount vsumount
TARGET ?= /usr/local/bin

.PHONY: all basic

all: $(addprefix $(TARGET)/,$(ALLFILES))
basic: $(addprefix $(TARGET)/,$(BASICFILES))

$(TARGET)/%: %
	test -d $(dir $@) || mkdir -p $(dir $@)
	cp -a $< $@
	-test $(shell id -u) -eq 0 && chown root:root $@
	-test $(shell id -u) -eq 0 && chmod u=rwx,go=rx $@

