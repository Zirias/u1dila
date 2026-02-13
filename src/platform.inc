.if .defined(MACH_c16)
.include "c16.inc"
.elseif .defined(MACH_c64)
.include "c64.inc"
.elseif .defined(MACH_vic20)
.include "vic20.inc"
.elseif .defined(MACH_vic20x)
.include "vic20x.inc"
.elseif .defined(MACH_vic20e)
.include "vic20e.inc"
.elseif .defined(MACH_c128)
.include "c128.inc"
.else
.error "Unknown platform!"
.endif

