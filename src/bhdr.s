.import __BHDR_LOAD__
.import entry

.segment "BHDR"
		.word	__BHDR_LOAD__+2
		.word	hdrend
		.word	2026
		.byte	$9e, <((entry/1000) .mod 10)+$30
		.byte	<((entry/100) .mod 10)+$30
		.byte	<((entry/10) .mod 10)+$30, <(entry .mod 10)+$30, 0
hdrend:		.word	0

