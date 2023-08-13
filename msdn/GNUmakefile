PYSCRIPTS:=combine-msdn-keys.py get-msdn-keys.py weed-out-dupes.py
ifneq ($(COMSPEC)$(ComSpec),)
BLACK:=py -3 -m black
FLAKE8:=py -3 -m flake8
VULTURE:=py -3 -m vulture
else
BLACK:=black
FLAKE8:=flake8
VULTURE:=vulture
endif
KEYS:=$(sort $(wildcard keys/*.xml))
TGTS.raw:=MSDN-keys-xml.7z MSDN-keys-xml.tar.xz
TGTS:=$(addsuffix .SHA256SUM,$(TGTS.raw))

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
	rm -f $(TGTS) $(TGTS.raw) *.bak

CLEAN: clean
	rm -f allkeys.txt SHA256SUM

rmkeys:
	rm -f allkeys.txt

rebuild: clean all
REBUILD: CLEAN all

renew-keys: rmkeys allkeys.txt
keys: allkeys.txt

lint: $(PYSCRIPTS)
	$(FLAKE8) $^

pretty: black

black: $(PYSCRIPTS)
	$(BLACK) $^

vulture: $(PYSCRIPTS)
	$(VULTURE) $^

check: pretty lint vulture

.PHONY: all black check clean CLEAN lint pretty rebuild REBUILD vulture keys rmkeys renew-keys
.PRECIOUS: $(TGTS.raw)
