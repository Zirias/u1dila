.include "kernal.inc"
.include "sddrv.inc"

CRSRROW=	$cd		; current row of the cursor
KBBUFLEN=	$ef		; length of keyboard buffer
STOPVEC=	$326		; vector to STOP check routine
KBBUF=		$527		; keyboard buffer base
LSTX=		$7f6		; currently pressed key
STARTMSG=	$80c2		; start message
BASICPROMPT=	$867e		; READY -> to BASIC

.segment "BHDR"

		.word	$1001
		.word	hdrend
		.word	2026
		.byte	$9e, <((entry/1000) .mod 10)+$30
		.byte	<((entry/100) .mod 10)+$30
		.byte	<((entry/10) .mod 10)+$30, <(entry .mod 10)+$30, 0
hdrend:		.word	0

.macro print t, l
		ldx	#(l ^ $ff) + 1
		lda	t-$100+l,x
		jsr	KRNL_CHROUT
		inx
		bne	*-7
.endmacro

.data

readerrmsg:	.byte	$d, "error reading directory!", $d
readerrlen=	* - readerrmsg

fakeldcmd:	.byte	12, 15, 1, 4, $22, "0:*", $22, ",8,1", 0
fakerunkeys:	.byte	$d, "run", $d
fakerunkeyslen=	*-fakerunkeys

.bss

scrollpos:	.res	1
dirpos:		.res	1
scrpos:		.res	1
origstop:	.res	2

.code

entry:
		sei
		lda	STOPVEC
		sta	origstop
		lda	STOPVEC+1
		sta	origstop+1
		lda	#<nostop
		sta	STOPVEC
		lda	#>nostop
		sta	STOPVEC+1
		cli
mainloop:	lda	#$93
		jsr	KRNL_CHROUT
		jsr	readdir
		bcc	browse
		print	readerrmsg, readerrlen
exit:		lda	#$40
		cmp	LSTX
		bne	*-3
		sei
		lda	origstop
		sta	STOPVEC
		lda	origstop+1
		sta	STOPVEC+1
		cli
		lda	#$93
		jmp	KRNL_CHROUT
browse:		lda	#0
		sta	scrollpos
		sta	dirpos
		sta	scrpos
		jsr	showdir
waitkey:	jsr	KRNL_GETIN
		beq	waitkey
		cmp	#$11
		beq	movedown
		cmp	#$91
		beq	moveup
		cmp	#$d
		beq	action
		cmp	#3
		beq	exit
		bne	waitkey
movedown:	ldx	dirpos
		inx
		cpx	nfiles
		beq	waitkey
		lda	scrpos
		cmp	#21
		bcc	bardown
		lda	scrollpos
		adc	#24
		cmp	nfiles
		beq	bardown
		inc	scrollpos
		inc	dirpos
		jsr	showdir
		beq	waitkey
bardown:	jsr	calcscrvec
		clc
		lda	$d8
		adc	#40
		sta	$da
		lda	$d9
		adc	#0
		sta	$db
		jsr	invbars
		inc	dirpos
		inc	scrpos
		bne	waitkey
moveup:		lda	dirpos
		beq	waitkey
		lda	scrpos
		cmp	#4
		bcs	barup
		lda	scrollpos
		beq	barup
		dec	scrollpos
		dec	dirpos
		jsr	showdir
		beq	waitkey
barup:		jsr	calcscrvec
		sec
		lda	$d8
		sbc	#40
		sta	$da
		lda	$d9
		sbc	#0
		sta	$db
		jsr	invbars
		dec	dirpos
		dec	scrpos
noaction:	jmp	waitkey
action:		lda	#0
		sta	$da
		lda	dirpos
		asl	a
		rol	$da
		asl	a
		rol	$da
		sta	rdtype+1
		lda	$da
		adc	#>filetypes
		sta	rdtype+2
rdtype:		lda	$ffff
		beq	noaction
		bpl	notadir
		lda	dirpos
		jsr	chdir
		jmp	mainloop
notadir:	lda	dirpos
		jsr	mount
		sei
		jsr	KRNL_RESETIO
		jsr	KRNL_RESTOR
		jsr	KRNL_CINT
		jsr	STARTMSG
		lda	CRSRROW
		clc
		adc	#2
		sta	scrpos
		jsr	calcscrvec
		ldy	#0
fakecmdloop:	lda	fakeldcmd,y
		beq	fakecmddone
		sta	($d8),y
		iny
		bne	fakecmdloop
fakecmddone:	ldx	#fakerunkeyslen
		stx	KBBUFLEN
		dex
fakekeysloop:	lda	fakerunkeys,x
		sta	KBBUF,x
		dex
		bpl	fakekeysloop
		ldx	#$fb
		txs
		cli
		jmp	BASICPROMPT

invbars:	ldy	#25
ib_invloop:	lda	($d8),y
		eor	#$80
		sta	($d8),y
		lda	($da),y
		eor	#$80
		sta	($da),y
		dey
		bpl	ib_invloop
nostop:		rts

calcscrvec:	lda	#$c
		sta	$d9
		lda	#0
		sta	$da
		lda	scrpos
		asl	a
		asl	a
		asl	a
		sta	$d8
		rol	$da
		asl	a
		rol	$da
		asl	a
		rol	$da
		adc	$d8
		sta	$d8
		lda	$da
		adc	$d9
		sta	$d9
csv_ok:		rts

showdir:	lda	#0
		sta	$d8
		sta	$da
		lda	#$c
		sta	$d9
		sec
		lda	nfiles
		sbc	scrollpos
		cmp	#26
		bcc	sd_maxok
		lda	#25
sd_maxok:	sta	$dc
		lda	scrollpos
		asl	a
		rol	$da
		asl	a
		rol	$da
		asl	a
		rol	$da
		asl	a
		rol	$da
		adc	#<filedisp
		sta	sd_fnrd+1
		lda	$da
		adc	#>filedisp
		sta	sd_fnrd+2
		lda	#0
		sta	$da
		lda	scrollpos
		asl	a
		rol	$da
		asl	a
		rol	$da
		adc	#<filetypes
		sta	sd_ftrd+1
		lda	$da
		adc	#>filetypes
		sta	sd_ftrd+2
		ldy	#0
		sty	$da
sd_loop:	lda	#0
		cpy	scrpos
		bne	sd_norev
		lda	#$80
sd_norev:	sta	$db
		ldy	#0
		lda	#$20
		ora	$db
		sta	($d8),y
		iny
		sta	($d8),y
		iny
		lda	#'<'
		ora	$db
		sta	($d8),y
		iny
		ldx	#1
sd_ftrd:	lda	$ffff,x
		ora	$db
		sta	($d8),y
		iny
		inx
		cpx	#4
		bne	sd_ftrd
		lda	#'>'
		ora	$db
		sta	($d8),y
		iny
		lda	#$20
		ora	$db
		sta	($d8),y
		iny
		sta	($d8),y
		iny
		ldx	#0
sd_fnrd:	lda	$ffff,x
		ora	$db
		sta	($d8),y
		iny
		inx
		cpx	#$10
		bne	sd_fnrd
		lda	#$20
		ora	$db
		sta	($d8),y
		clc
		lda	sd_ftrd+1
		adc	#4
		sta	sd_ftrd+1
		bcc	sd_ftptrok
		inc	sd_ftrd+2
sd_ftptrok:	clc
		lda	sd_fnrd+1
		adc	#$10
		sta	sd_fnrd+1
		bcc	sd_fnptrok
		inc	sd_fnrd+2
sd_fnptrok:	clc
		lda	$d8
		adc	#$28
		sta	$d8
		bcc	sd_scrptrok
		inc	$d9
sd_scrptrok:	ldy	$da
		iny
		cpy	$dc
		beq	sd_done
		sty	$da
		jmp	sd_loop
sd_done:	rts
