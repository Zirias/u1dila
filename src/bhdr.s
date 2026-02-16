.import __BHDR_LOAD__
.import entry

; BASIC header, including PRG load address
.segment "BHDR"
		.word	__BHDR_LOAD__+2	; load address from linker config

		.word	hdrend		; pointer to next BASIC line
		.word	2026		; line number

		; For the SYS command (token $9e), convert entry address
		; to 4-digit decimal number in PETSCII
		.byte	$9e, <((entry/1000) .mod 10)+$30
		.byte	<((entry/100) .mod 10)+$30
		.byte	<((entry/10) .mod 10)+$30, <(entry .mod 10)+$30

		.byte	0		; <NUL>, end of BASIC line

hdrend:		.word	0		; NULL pointer, end of BASIC program
