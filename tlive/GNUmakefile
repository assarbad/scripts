# - wget https://www.tug.org/texlive/files/debian-equivs-${YEAR}-ex.txt
# - [optional] equivs-control texlive-local
# - merge the two files
DEP:=texlive-local
VER:=$(shell awk '/^Version:/ {print $$2}' $(DEP))
TGT:=$(DEP)_$(VER)_all.deb

all: $(TGT)

$(TGT): $(DEP)
	equivs-build $<
	test -f $@

clean CLEAN:
	rm -f $(TGT)

rebuild REBUILD: clean all

.PHONY: all clean CLEAN rebuild REBUILD
