ALLFILES ?= etckeeper-commit save-pkgstates vsmount vsumount
BASICFILES ?= etckeeper-commit save-pkgstates
TARGET ?= /usr/local/bin

.PHONY: all basic

all: $(addprefix $(TARGET)/,$(ALLFILES))
basic: $(addprefix $(TARGET)/,$(BASICFILES))

$(TARGET)/%: %
	cp -a $< $@ && chown root:root $@ && chmod u=rwx,go=rx $@

