ALLFILES ?= etckeeper-commit save-pkgstates vsmount vsumount
BASICFILES ?= etckeeper-commit save-pkgstates reinstall-grub
TARGET ?= /usr/local/bin

.PHONY: all basic

all: $(addprefix $(TARGET)/,$(ALLFILES))
basic: $(addprefix $(TARGET)/,$(BASICFILES))

$(TARGET)/%: %
	test -d $(dir $@) || mkdir -p $(dir $@)
	cp -a $< $@
	chown root:root $@
	chmod u=rwx,go=rx $@

