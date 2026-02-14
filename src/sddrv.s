.include "kernal.inc"
.include "platform.inc"
.include "scrcode.inc"
.include "zpshared.inc"

.export readdir
.export init
.export chdir
.export mount
.export driveno
.export filenames
.if .not .defined(NODISPFN)
.export filedisp
.endif
.export filetypes
.export nfiles

.data

driveno:	.byte	$9
cdcmd:		.byte	":dc"
cdcmdlen=	*-cdcmd
mntcmd:		.byte	":tnuom"
mntcmdlen=	*-mntcmd
killcmd:	.byte	"0llik"
killcmdlen=	*-killcmd
initcmd:	.byte	"0tini"
initcmdlen=	*-initcmd

.bss

nfiles:		.res	1

.if .defined(VIC20_5K)
MAXFILES=	102
.else
MAXFILES=	256
.segment "ALBSS"
.align $100
.endif

filenames:	.res	16 * MAXFILES
.if .not .defined(NODISPFN)
filedisp:	.res	16 * MAXFILES
.endif
filetypes:	.res	4 * MAXFILES

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
		sta	IOSTATUS
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
.if .not .defined(NODISPFN)
		eor	#$20
		sta	filedisp,y
		eor	#$20
.endif
		dey
		bpl	rd_clrloop
		lda	#'/'
		sta	filenames
.if .not .defined(NODISPFN)
		sta	filedisp
.endif
		lda	#'.'
		sta	filenames+$10
		sta	filenames+$11
.if .not .defined(NODISPFN)
		sta	filedisp+$10
		sta	filedisp+$11
.endif
		lda	#$80
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
.if .not .defined(NODISPFN)
		lda	#<(filedisp+$20)
		sta	rd_fdwrite1+1
		sta	rd_fdwrite2+1
		lda	#>(filedisp+$20)
		sta	rd_fdwrite1+2
		sta	rd_fdwrite2+2
.endif
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
.if .not .defined(NODISPFN)
		jsr	scrcode
rd_fdwrite1:	sta	$ffff,y
.endif
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
.if .not .defined(NODISPFN)
		eor	#$20
rd_fdwrite2:	sta	$ffff,y
		eor	#$20
.endif
		iny
		bne	rd_nmfill
rd_nmfilled:	jsr	rdbyte
		bcc	*+5
		jmp	rd_dirend
		cmp	#$20
		beq	rd_nmfilled
		tax
		lda	#0
		sta	ZPS_0
		lda	nfiles
		asl	a
		rol	ZPS_0
		asl	a
		rol	ZPS_0
		adc	#<filetypes
		sta	rd_ftwrite+1
		lda	ZPS_0
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
		bcc	rd_scaneol
		jmp	rd_dirend
rd_nextfile:	lda	rd_ftwrite+1
		sta	ZPS_0
		lda	rd_ftwrite+2
		sta	ZPS_1
		lda	#0
		tay
		sta	(ZPS_0),y
		iny
		lda	(ZPS_0),y
		cmp	#4
		bne	rd_ftchkprg
		iny
		lda	(ZPS_0),y
		cmp	#9
		beq	rd_ftchkdir
		cmp	#$36
		bne	rd_ftfdone
		iny
		lda	(ZPS_0),y
		cmp	#$34
		bne	rd_ftfdone
		lda	#1
		ldy	#0
		sta	(ZPS_0),y
		beq	rd_ftfdone
rd_ftchkprg:	cmp	#16
		bne	rd_ftfdone
		iny
		lda	(ZPS_0),y
		cmp	#18
		bne	rd_ftfdone
		iny
		lda	(ZPS_0),y
		cmp	#7
		bne	rd_ftfdone
		lda	#2
		ldy	#0
		sta	(ZPS_0),y
		beq	rd_ftfdone
rd_ftchkdir:	iny
		lda	(ZPS_0),y
		cmp	#18
		bne	rd_ftfdone
		lda	#$80
		ldy	#0
		sta	(ZPS_0),y
rd_ftfdone:	clc
		lda	rd_fnwrite1+1
		adc	#$10
		sta	rd_fnwrite1+1
		sta	rd_fnwrite2+1
		lda	rd_fnwrite1+2
		adc	#0
		sta	rd_fnwrite1+2
		sta	rd_fnwrite2+2
.if .not .defined(NODISPFN)
		clc
		lda	rd_fdwrite1+1
		adc	#$10
		sta	rd_fdwrite1+1
		sta	rd_fdwrite2+1
		lda	rd_fdwrite1+2
		adc	#0
		sta	rd_fdwrite1+2
		sta	rd_fdwrite2+2
.endif
		inc	nfiles
.if .defined(VIC20_5K)
		lda	nfiles
		cmp	#MAXFILES
.endif
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

init:
		lda	#<initcmd
		ldx	#>initcmd
		ldy	#initcmdlen-1
		jsr	sendcmd
		bcs	init_done
		jsr	KRNL_UNLSN
		jsr	KRNL_READST
		asl	a
init_done:	rts

chdir:
		jsr	setname
		lda	#<cdcmd
		ldx	#>cdcmd
		ldy	#cdcmdlen-1
		jsr	sendcmd
		bcs	cd_done
		jsr	sendname
		jsr	KRNL_READST
		asl	a
cd_done:	rts

mount:
		jsr	setname
		lda	#<mntcmd
		ldx	#>mntcmd
		ldy	#mntcmdlen-1
		jsr	sendcmd
		bcs	mnt_done
mnt_name:	jsr	sendname
		jsr	KRNL_READST
		asl	a
		bcs	mnt_done
		lda	#<killcmd
		ldx	#>killcmd
		ldy	#killcmdlen-1
		jsr	sendcmd
		jsr	KRNL_UNLSN
		jsr	KRNL_READST
		asl	a
mnt_done:	rts

sendcmd:
		sta	sc_cmdloop+1
		stx	sc_cmdloop+2
		sty	sc_listened+1
		lda	#0
		sta	IOSTATUS
		lda	driveno
		jsr	KRNL_LISTEN
		lda	#$6f
		jsr	KRNL_SECOND
		jsr	KRNL_READST
		bpl	sc_listened
		jsr	KRNL_UNLSN
sc_error:	sec
		rts
sc_listened:	ldx	#$ff
sc_cmdloop:	lda	$ffff,x
		jsr	KRNL_CIOUT
		dex
		bpl	sc_cmdloop
		clc
		rts

setname:
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		clc
		adc	#<filenames
		sta	sn_rdfn+1
		lda	ZPS_2
		and	#$f
		adc	#>filenames
		sta	sn_rdfn+2
		rts

sendname:
		ldx	#0
sn_rdfn:	lda	$ffff,x
		beq	sn_cmddone
		jsr	KRNL_CIOUT
		inx
		cpx	#$10
		bne	sn_rdfn
sn_cmddone:	jmp	KRNL_UNLSN

rdbyte:
		sec
		bit	IOSTATUS
		bmi	rb_out
		bvs	rb_out
		jsr	KRNL_ACPTR
		clc
rb_out:		rts

