ALL:= build-dropbear.monolithic build-llvm-and-clang.monolithic

all: $(ALL)

build-dropbear.monolithic: build-musl
build-llvm-and-clang.monolithic: build-cmake

%.monolithic: %
	sed 's|^PAYLOAD=""|PAYLOAD="$(shell echo "$(filter-out $(patsubst %.monolithic,%,$@),$^)"|tr 'a-z-' 'A-Z_')"|g' $< > $@ && \
	echo "exit 0\n$(shell echo "$(filter-out $(patsubst %.monolithic,%,$@),$^)"|tr 'a-z-' 'A-Z_'):" >> $@ && \
	cat $(filter-out $(patsubst %.monolithic,%,$@),$^) >> $@ && \
	chmod +x $@

rebuild: clean all

clean:
	$(RM) $(ALL)

.PHONY: all rebuild clean
.ONESHELL: $(ALL)
.NOTPARALLEL: $(ALL) rebuild clean
