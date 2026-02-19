CA65?=		ca65
LD65?=		ld65
MV?=		mv
TOUCH?=		touch

CA65FLAGS+=	-t c64 -g -DMACH_$(PLATFORM)
LD65FLAGS+=	-Ln $(TARGET).lbl -m $(TARGET).map -C src/$(TARGET).cfg

PLATFORMS:=	vic20 vic20x vic20e c64 c16 c128
TARGET=		u1dila-$(PLATFORM)
PLATFORM?=	c16

ifeq ($(filter $(PLATFORM),$(PLATFORMS)),)
$(error Unsupported PLATFORM: $(PLATFORM))
endif

MODULES=	bhdr clrscr main scrcode sddrv zpshared

OBJS=		$(addprefix obj/$(PLATFORM)/,$(addsuffix .o,$(MODULES)))
DEPS=		$(addprefix obj/$(PLATFORM)/,$(addsuffix .d,$(MODULES)))

V?=0

ifneq ($(V),0)
V:=		1
endif

_V_0=		@
_V_1=		#
_CA65_0=	@echo "  [CA65]   $@";
_CA65_1=	#
_LD65_0=	@echo "  [LD65]   $@";
_LD65_1=	#

all:		$(TARGET).prg
world:		$(PLATFORMS)

define PRULE
$1:
	@$(MAKE) --no-print-directory PLATFORM=$1
endef
$(foreach p,$(PLATFORMS),$(eval $(call PRULE,$p)))

clean:
	rm -fr obj
	rm -f *.lbl *.map *.prg *.d64

$(DEPS): ;
include $(wildcard $(DEPS))

$(TARGET).prg:	$(OBJS) src/$(TARGET).cfg Makefile
	$(_LD65_$(V))$(LD65) -o$@ $(LD65FLAGS) $(OBJS)

obj/$(PLATFORM)/%.o:	src/%.s obj/$(PLATFORM)/%.d Makefile | obj/$(PLATFORM)
	$(_CA65_$(V))$(CA65) $(CA65FLAGS) --create-dep $(@:.o=.Td) -o$@ $< &&\
	$(MV) -f $(@:.o=.Td) $(@:.o=.d) >/dev/null 2>&1 &&\
	$(TOUCH) $@

obj/$(PLATFORM):
	$(_V_$(V))mkdir -p $@

.PHONY:		all world clean $(PLATFORMS)
