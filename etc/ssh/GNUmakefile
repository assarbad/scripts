ALLFILES ?= ipset_sshd.sh
TARGET ?= /etc/ssh

.PHONY: all

all: $(addprefix $(TARGET)/,$(ALLFILES))

$(TARGET)/%: %
	test -d $(dir $@) || mkdir -p $(dir $@)
	cp -a $< $@
	chown root:root $@
	chmod u=rwx,go=r $@

