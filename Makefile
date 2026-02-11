CA65?=		ca65
LD65?=		ld65
CA65FLAGS+=	-t c64 -g
LD65FLAGS+=	-Ln $(TARGET).lbl -m $(TARGET).map -C src/$(TARGET).cfg

TARGET=		u1dila

MODULES=	main scrcode sddrv

OBJS=		$(addprefix obj/,$(addsuffix .o,$(MODULES)))

all:		$(TARGET).prg

clean:
	rm -fr obj
	rm -f *.lbl *.map *.prg *.d64

$(TARGET).prg:	$(OBJS) src/$(TARGET).cfg Makefile
	$(LD65) -o$@ $(LD65FLAGS) $(OBJS)

obj/%.o:	src/%.s src/$(TARGET).cfg Makefile | obj
	$(CA65) $(CA65FLAGS) -o$@ $<

obj:
		mkdir obj

.PHONY:		all clean
