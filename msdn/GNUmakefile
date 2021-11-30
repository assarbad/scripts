KEYS:=$(sort $(wildcard keys/*.xml))
TGTS:=$(addsuffix .SHA256SUM,MSDN-keys-xml.7z MSDN-keys-xml.tar.xz)

all: $(TGTS) allkeys.txt SHA256SUMS

SHA256SUMS: $(KEYS)
	-@mv $@ $@.bak
	sha256sum $^|tee $@

allkeys.txt: $(KEYS)
	-@mv $@ $@.bak
	python combine-msdn-keys.py keys/ > $@

%.SHA256SUM: %
	sha256sum $<|tee $@

MSDN-keys-xml.7z: $(KEYS) SHA256SUMS
	test -d "keys" && 7z a -bt -r -t7z -m0=lzma2 -mx9 -mfb=273 -ms -md=31 -myx=9 -mtm=- -mmt -mmtf -md=1536m -mmf=bt3 -mmc=10000 -mpb=0 $@ $^ || true

%.tar.xz: %.tar
	test -f "$<" && xz -f9eT 10 $< || true

MSDN-keys-xml.tar: $(KEYS) SHA256SUMS
	test -d "keys" && tar -cf $@ $^ || true

clean:
	rm -f $(TGTS) *.bak

CLEAN: clean
	rm -f allkeys.txt SHA256SUM

rebuild: clean all

keys: allkeys.txt

.PHONY: all clean CLEAN rebuild keys
