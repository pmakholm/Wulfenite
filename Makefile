SRC = Wulfenite/Actions.nqp \
      Wulfenite/Grammar.nqp \
      Wulfenite/Compiler.nqp

INSTALL = echo $(file) | cpio -pd ../blib;

all: $(SRC:%.nqp=src/%.pbc)
	install -d blib
	(cd src; $(foreach file,$(SRC:%.nqp=%.pbc),$(INSTALL)) ) 

clean:
	rm -Rf blib $(SRC:%.nqp=src/%.pbc)

%.pir: %.nqp
	nqp-p --target=pir --output $@ $<

%.pbc: %.pir
	parrot -o $@ $<
