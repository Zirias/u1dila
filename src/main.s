.include "kernal.inc"
.include "platform.inc"
.include "scrcode.inc"
.include "sddrv.inc"
.include "zpshared.inc"

.export entry

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

cderrmsg:	.byte	$d, "error sending cd command!", $d
cderrlen=	* - cderrmsg

mnterrmsg:	.byte	$d, "error sending mount/kill!", $d
mnterrlen=	* - mnterrmsg

fakeldcmd:	.byte	12, 15, 1, 4, $22
fakeldcmdlen=	*-fakeldcmd
		.byte	"0:*", $22, ",8,1", 0
fakeld9cmd:	.byte	$22, ",9,1", 0
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
		lda	ZPS_0
		adc	#40
		sta	ZPS_2
		lda	ZPS_1
		adc	#0
		sta	ZPS_3
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
		lda	ZPS_0
		sbc	#40
		sta	ZPS_2
		lda	ZPS_1
		sbc	#0
		sta	ZPS_3
		jsr	invbars
		dec	dirpos
		dec	scrpos
noaction:	jmp	waitkey
action:		lda	#0
		sta	ZPS_2
		lda	dirpos
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		sta	rdtype+1
		lda	ZPS_2
		adc	#>filetypes
		sta	rdtype+2
rdtype:		lda	$ffff
		beq	noaction
		bpl	notadir
		lda	dirpos
		jsr	chdir
		bcc	cdok
		lda	#$93
		jsr	KRNL_CHROUT
		print	cderrmsg, cderrlen
		rts
cdok:		jmp	mainloop
notadir:	lsr	a
		bcs	diskimg
		jsr	softreset
		lda	#0
		tax
		tay
		sta	ZPS_2
		lda	dirpos
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		sta	prgrdnm+1
		lda	ZPS_2
		adc	#>filenames
		sta	prgrdnm+2
fakeld9loop1:	lda	fakeldcmd,y
		sta	(ZPS_0),y
		iny
		cpy	#fakeldcmdlen
		bne	fakeld9loop1
prgrdnm:	lda	$ffff,x
		beq	prgnmdone
		jsr	scrcode
		sta	(ZPS_0),y
		iny
		inx
		bne	prgrdnm
prgnmdone:	ldx	#0
fakeld9loop2:	lda	fakeld9cmd,x
		beq	fakecmddone
		sta	(ZPS_0),y
		iny
		inx
		bne	fakeld9loop2
diskimg:	lda	dirpos
		jsr	mount
		bcc	mountok
		lda	#$93
		jsr	KRNL_CHROUT
		print	mnterrmsg, mnterrlen
		rts
mountok:	jsr	softreset
		ldy	#0
fakecmdloop:	lda	fakeldcmd,y
		beq	fakecmddone
		sta	(ZPS_0),y
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
ib_invloop:	lda	(ZPS_0),y
		eor	#$80
		sta	(ZPS_0),y
		lda	(ZPS_2),y
		eor	#$80
		sta	(ZPS_2),y
		dey
		bpl	ib_invloop
nostop:		rts

softreset:
		sei
		jsr	KRNL_RESETIO
		jsr	KRNL_RESTOR
		jsr	KRNL_CINT
		tsx
		stx	sr_fixstack+1
		jsr	STARTMSG
sr_fixstack:	ldx	#$ff
		txs
		lda	CRSRROW
		clc
		adc	#2
		sta	scrpos

calcscrvec:
		lda	#>SCREEN
		sta	ZPS_1
		lda	#0
		sta	ZPS_2
		lda	scrpos
		asl	a
		asl	a
		asl	a
		sta	ZPS_0
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		adc	ZPS_0
		sta	ZPS_0
		lda	ZPS_2
		adc	ZPS_1
		sta	ZPS_1
csv_ok:		rts

showdir:	lda	#0
		sta	ZPS_0
		sta	ZPS_2
		lda	#>SCREEN
		sta	ZPS_1
		sec
		lda	nfiles
		sbc	scrollpos
		cmp	#26
		bcc	sd_maxok
		lda	#25
sd_maxok:	sta	ZPS_4
		lda	scrollpos
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		adc	#<filedisp
		sta	sd_fnrd+1
		lda	ZPS_2
		adc	#>filedisp
		sta	sd_fnrd+2
		lda	#0
		sta	ZPS_2
		lda	scrollpos
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		adc	#<filetypes
		sta	sd_ftrd+1
		lda	ZPS_2
		adc	#>filetypes
		sta	sd_ftrd+2
		ldy	#0
		sty	ZPS_2
sd_loop:	lda	#0
		cpy	scrpos
		bne	sd_norev
		lda	#$80
sd_norev:	sta	ZPS_3
		ldy	#0
		lda	#$20
		ora	ZPS_3
		sta	(ZPS_0),y
		iny
		sta	(ZPS_0),y
		iny
		lda	#'<'
		ora	ZPS_3
		sta	(ZPS_0),y
		iny
		ldx	#1
sd_ftrd:	lda	$ffff,x
		ora	ZPS_3
		sta	(ZPS_0),y
		iny
		inx
		cpx	#4
		bne	sd_ftrd
		lda	#'>'
		ora	ZPS_3
		sta	(ZPS_0),y
		iny
		lda	#$20
		ora	ZPS_3
		sta	(ZPS_0),y
		iny
		sta	(ZPS_0),y
		iny
		ldx	#0
sd_fnrd:	lda	$ffff,x
		ora	ZPS_3
		sta	(ZPS_0),y
		iny
		inx
		cpx	#$10
		bne	sd_fnrd
		lda	#$20
		ora	ZPS_3
		sta	(ZPS_0),y
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
		lda	ZPS_0
		adc	#$28
		sta	ZPS_0
		bcc	sd_scrptrok
		inc	ZPS_1
sd_scrptrok:	ldy	ZPS_2
		iny
		cpy	ZPS_4
		beq	sd_done
		sty	ZPS_2
		jmp	sd_loop
sd_done:	rts
