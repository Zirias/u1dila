.if .defined(MACH_c16)
.include "c16.inc"
.else
.error "Unknown platform!"
.endif

