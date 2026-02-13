.if .defined(MACH_c16)
.include "c16.inc"
.elseif .defined(MACH_c64)
.include "c64.inc"
.else
.error "Unknown platform!"
.endif

