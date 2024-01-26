PWD:=$(shell pwd)
NAME:=ultradefrag
SVNURL:=https://svn.code.sf.net/p/$(NAME)/code/
all: $(NAME)

clean:

$(NAME): $(NAME).svn
	svnsync synchronize file:///$(PWD)/$</

$(NAME).svn: $(NAME).svn/hooks/pre-revprop-change
	-svnsync initialize file:///$(PWD)/$@/ $(SVNURL)

$(NAME).svn/hooks/pre-revprop-change: $(NAME).svn/format
	echo "#!/usr/bin/env bash" > $@
	echo "exit 0" >> $@
	chmod +x $@

$(NAME).svn/format:
	svnadmin create $(dir $@)

rebuild: clean all

.PHONY: all rebuild clean $(NAME)
.NOTPARALLEL: all rebuild clean $(NAME)
