.include "kernal.inc"
.include "scrcode.inc"

.export readdir
.export driveno
.export filenames
.export filedisp
.export filetypes
.export nfiles

.data

driveno:	.byte	$9

.bss

nfiles:		.res	1

.segment "ALBSS"

.align $100
filenames:	.res	$1000
filedisp:	.res	$1000
filetypes:	.res	$400

.code


readdir:
		lda	driveno
		jsr	KRNL_LISTEN
		lda	#$f0
		jsr	KRNL_SECOND
		jsr	KRNL_READST
		bpl	rd_listened
rd_error:	sec
		rts
rd_listened:	lda	#'$'
		jsr	KRNL_CIOUT
		jsr	KRNL_UNLSN
		lda	driveno
		jsr	KRNL_TALK
		lda	#$60
		jsr	KRNL_TKSA
		lda	#0
		sta	$90
		ldy	#6
rd_titleloop:	jsr	rdbyte
		bcs	rd_error
		dey
		bpl	rd_titleloop
		tax
		bne	rd_titleloop
		lda	#0
		ldy	#$1f
rd_clrloop:	sta	filenames,y
		eor	#$20
		sta	filedisp,y
		eor	#$20
		dey
		bpl	rd_clrloop
		lda	#'/'
		sta	filenames
		sta	filedisp
		lda	#'.'
		sta	filenames+$10
		sta	filenames+$11
		sta	filedisp+$10
		sta	filedisp+$11
		lda	#$80
		sta	filetypes
		sta	filetypes+4
		lda	#4
		sta	filetypes+1
		sta	filetypes+5
		lda	#9
		sta	filetypes+2
		sta	filetypes+6
		lda	#18
		sta	filetypes+3
		sta	filetypes+7
		lda	#2
		sta	nfiles
		lda	#<(filenames+$20)
		sta	rd_fnwrite1+1
		sta	rd_fnwrite2+1
		lda	#>(filenames+$20)
		sta	rd_fnwrite1+2
		sta	rd_fnwrite2+2
		lda	#<(filedisp+$20)
		sta	rd_fdwrite1+1
		sta	rd_fdwrite2+1
		lda	#>(filedisp+$20)
		sta	rd_fdwrite1+2
		sta	rd_fdwrite2+2
rd_fileloop:	ldy	#4
rd_entryloop:	jsr	rdbyte
		bcc	*+5
		jmp	rd_dirend
		dey
		bpl	rd_entryloop
		tax
		beq	rd_fileloop
		cmp	#'"'
		bne	rd_entryloop
		ldy	#0
rd_fnmloop:	jsr	rdbyte
		bcc	*+5
		jmp	rd_dirend
		cmp	#'"'
		beq	rd_havenm
rd_fnwrite1:	sta	$ffff,y
		jsr	scrcode
rd_fdwrite1:	sta	$ffff,y
		iny
		cpy	#$10
		bne	rd_fnmloop
rd_fnmtrunc:	jsr	rdbyte
		bcc	*+5
		jmp	rd_dirend
		beq	rd_fileloop
		cmp	#'"'
		bne	rd_fnmtrunc
rd_havenm:	lda	#0
rd_nmfill:	cpy	#$10
		beq	rd_nmfilled
rd_fnwrite2:	sta	$ffff,y
		eor	#$20
rd_fdwrite2:	sta	$ffff,y
		eor	#$20
		iny
		bne	rd_nmfill
rd_nmfilled:	jsr	rdbyte
		bcc	*+5
		jmp	rd_dirend
		cmp	#$20
		beq	rd_nmfilled
		tax
		lda	#0
		sta	$d8
		lda	nfiles
		asl	a
		rol	$d8
		asl	a
		rol	$d8
		adc	#<filetypes
		sta	rd_ftwrite+1
		lda	$d8
		adc	#>filetypes
		sta	rd_ftwrite+2
		txa
		ldy	#1
rd_typeloop:	tax
		beq	rd_fileloop
		jsr	scrcode
rd_ftwrite:	sta	$ffff,y
		jsr	rdbyte
		bcc	*+5
		jmp	rd_dirend
		iny
		cpy	#5
		bne	rd_typeloop
rd_scaneol:	tax
		beq	rd_nextfile
		jsr	rdbyte
		bcs	rd_dirend
		bcc	rd_scaneol
rd_nextfile:	lda	rd_ftwrite+1
		sta	$d8
		lda	rd_ftwrite+2
		sta	$d9
		lda	#0
		tay
		sta	($d8),y
		iny
		lda	($d8),y
		cmp	#4
		bne	rd_ftfdone
		iny
		lda	($d8),y
		cmp	#9
		beq	rd_ftchkdir
		cmp	#$36
		bne	rd_ftfdone
		iny
		lda	($d8),y
		cmp	#$34
		bne	rd_ftfdone
		lda	#1
		ldy	#0
		sta	($d8),y
		beq	rd_ftfdone
rd_ftchkdir:	iny
		lda	($d8),y
		cmp	#18
		bne	rd_ftfdone
		lda	#$80
		ldy	#0
		sta	($d8),y
rd_ftfdone:	clc
		lda	rd_fnwrite1+1
		adc	#$10
		sta	rd_fnwrite1+1
		sta	rd_fnwrite2+1
		lda	rd_fnwrite1+2
		adc	#0
		sta	rd_fnwrite1+2
		sta	rd_fnwrite2+2
		clc
		lda	rd_fdwrite1+1
		adc	#$10
		sta	rd_fdwrite1+1
		sta	rd_fdwrite2+1
		lda	rd_fdwrite1+2
		adc	#0
		sta	rd_fdwrite1+2
		sta	rd_fdwrite2+2
		inc	nfiles
		beq	rd_dirend
		jmp	rd_fileloop
rd_dirend:	jsr	KRNL_UNTLK
		lda	driveno
		jsr	KRNL_LISTEN
		lda	#$e0
		jsr	KRNL_SECOND
		jsr	KRNL_UNLSN
		clc
		rts

rdbyte:
		jsr	KRNL_READST
		asl	a
		bcs	rb_out
		asl	a
		bcs	rb_out
		jsr	KRNL_ACPTR
		clc
rb_out:		rts

