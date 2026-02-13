CA65?=		ca65
LD65?=		ld65
CA65FLAGS+=	-t c64 -g -DMACH_$(PLATFORM)
LD65FLAGS+=	-Ln $(TARGET).lbl -m $(TARGET).map -C src/$(TARGET).cfg

TARGET=		u1dila-$(PLATFORM)
PLATFORM?=	c16

MODULES=	bhdr main scrcode sddrv zpshared

OBJS=		$(addprefix obj/$(PLATFORM)/,$(addsuffix .o,$(MODULES)))

all:		$(TARGET).prg

clean:
	rm -fr obj
	rm -f *.lbl *.map *.prg *.d64

$(TARGET).prg:	$(OBJS) src/$(TARGET).cfg Makefile
	$(LD65) -o$@ $(LD65FLAGS) $(OBJS)

obj/$(PLATFORM)/%.o:	src/%.s src/$(TARGET).cfg Makefile | obj/$(PLATFORM)
	$(CA65) $(CA65FLAGS) -o$@ $<

obj/$(PLATFORM):
		mkdir -p $@

.PHONY:		all clean
