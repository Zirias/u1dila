.include "kernal.inc"
.include "platform.inc"
.include "scrcode.inc"
.include "sddrv.inc"
.include "zpshared.inc"

.export entry

; print string at address `t` of length `l` (1-255)
.macro print t, l
		ldx	#(l ^ $ff) + 1
		lda	t-$100+l,x
		jsr	KRNL_CHROUT
		inx
		bne	*-7
.endmacro

.data

.if SCRCOLS > 25
SPC_OR_NL=	$20
.else
SPC_OR_NL=	$d
.endif

readerrmsg:	.byte	$d, "error reading", SPC_OR_NL, "directory!", $d
readerrlen=	* - readerrmsg

cderrmsg:	.byte	$d, "error sending cd", SPC_OR_NL, "command!", $d
cderrlen=	* - cderrmsg

mnterrmsg:	.byte	$d, "error sending", SPC_OR_NL, "mount/kill!", $d
mnterrlen=	* - mnterrmsg

fakeldcmd:	.byte	12, 15, 1, 4, $22, "0:*", 0	; LOAD"0:*
fakeldcmdlen=	*-4-fakeldcmd
fakerunkeys:	.byte	$d, "run", $d
fakerunkeyslen=	*-fakerunkeys
drvnop1:	.byte	"8911"
drvnop2:	.byte	"01"

.bss

scrollpos:	.res	1	; display scroll offset (first dir line shown)
dirpos:		.res	1	; selected position in dir
scrpos:		.res	1	; selected position on screen
origstop:	.res	2	; save original STOP vector

; For mapping function keys to themselves on c16 and c128
.if .defined(MACH_c16)
FKEYS=		8		; number of mappable keys
KEYDEFS=	$55f		; start of definitions in RAM
KEYCODES=	$dc41		; original key codes in ROM
fkeysave:	.res	2*FKEYS	; room to save original vaues
.elseif .defined(MACH_c128)
FKEYS=		10		; see above ...
KEYDEFS=	$1000
KEYCODES=	$c6dd
fkeysave:	.res	2*FKEYS
.endif

.code

; Clear the screen and fill color RAM with currently selected color.
; The latter is necessary at least on the vic20, which fills the color RAM
; with the background color when clearing the screen.
clrscr:
		lda	#$93
		jsr	KRNL_CHROUT
clrcol:		lda	#>COLRAM
		sta	cs_col+2
		lda	CURCOL
		ldx	#0
		ldy	#SCRNPG
cs_col:		sta	$ff00,x
		inx
		bne	cs_col
		inc	cs_col+2
		dey
		bne	cs_col
cs_done:	rts

; write trailing part of fake load command with the drive number from A
writedrvno:
		and	#7		; mask low bits
		tax
		lda	#'"'		; print "
		sta	(ZPS_0),y
		iny
		lda	#','		; print ,
		sta	(ZPS_0),y
		iny
		lda	drvnop1,x	; load first digit
		sta	(ZPS_0),y	; and print
		iny
		dex
		dex
		bmi	wdn_ok		; drive no >= 10?
		lda	drvnop2,x	; load second digit
		sta	(ZPS_0),y	; and print
		iny
wdn_ok:		lda	#','		; print ,
		sta	(ZPS_0),y
		iny
		lda	#'1'		; print 1
		sta	(ZPS_0),y
		iny
		rts

ftoffset:
		ldx	#0
		stx	ZPS_2
		asl	a		; calculate filetype offset from
		rol	ZPS_2		; dir position
		asl	a
		rol	ZPS_2
		rts

; Main entry point, the BASIC header SYS command jumps here
entry:
		sei
.if .defined(MACH_c16) .or .defined(MACH_c128)
		ldx	#(2*FKEYS)-1	; save original function key
savefkeys:	lda	KEYDEFS,x	; definitions
		sta	fkeysave,x
		dex
		bpl	savefkeys
		ldx	#FKEYS-1	; create the "identity mapping"
fakefdefs:	lda	KEYCODES,x	; fetch control code from ROM
		sta	KEYDEFS+FKEYS,x
		lda	#1		; use constant "1" for the length
		sta	KEYDEFS,x
		dex
		bpl	fakefdefs
.endif
.if .defined(MACH_c128)
		bit	$d7		; check c128 screen mode
		bpl	start		; 40-columns -> continue
		lda	#27		; send escape sequence to
		jsr	KRNL_CHROUT	; toggle screen mode
		lda	#'x'
		jsr	KRNL_CHROUT
start:		lda	#$e		; bank out BASIC ROM, we need the
		sta	$ff00		; RAM below
.endif
		lda	STOPVEC		; save original STOP vector
		sta	origstop
		lda	STOPVEC+1
		sta	origstop+1
		lda	#<nostop	; ... and replace witha pointer to
		sta	STOPVEC		; a single RTS, to disable the
		lda	#>nostop	; system's detection of the STOP key
		sta	STOPVEC+1
		cli			; initialization done, allow IRQ
mainloop:	jsr	clrscr		; clear the screen
		jsr	readdir		; read the directory
		bcc	browse		; no error -> start browsing
		print	readerrmsg, readerrlen
exit:		lda	#NOKEY		; exit, first wait until no key pressed
waitkbidle:	cmp	LSTX		; to avoid detecting a still pressed
		bne	waitkbidle	; STOP key
		sei
		lda	origstop	; then restore original STOP vector
		sta	STOPVEC
		lda	origstop+1
		sta	STOPVEC+1
.if .defined(MACH_c16) .or .defined(MACH_c128)
		ldx	#(2*FKEYS)-1	; restore original function key
restfkeys:	lda	fkeysave,x	; mappings on c16 and c128
		sta	KEYDEFS,x
		dex
		bpl	restfkeys
.endif
.if .defined(MACH_c128)
		lda	#0		; on c128, bank BASIC back in
		sta	$ff00
.endif
		cli			; exit sequence done
nostop:		rts
browse:		lda	#0		; initialize browser variables
		sta	scrollpos
		sta	dirpos
		sta	scrpos
		jsr	showdir		; show directory on screen
waitkey:	jsr	KRNL_GETIN	; wait for a key
		beq	waitkey
		cmp	#3		; STOP?
		bne	checkkey
		jsr	clrscr		; then clear screen
		beq	exit		; and exit ('bra', clrscr sets Z)
checkkey:	cmp	#$11		; cursor down?
		beq	movedown
		cmp	#$91		; cursor up?
		beq	moveup
		sta	ZPS_4		; save key for later check on action
		cmp	#$d		; RETURN?
		beq	action
		cmp	#$85		; F1?
		beq	action
		bne	waitkey		; unknown key, repeat waiting
movedown:	ldx	dirpos		; load current dir position
		inx			; and increment
		cpx	nfiles		; still inside directory?
		beq	waitkey		; if not, ignore moving down
		lda	scrpos		; load current screen position
		cmp	#SCRROWS-4	; above 4th row from bottom?
		bcc	bardown		; then just move the bar
		lda	scrollpos	; otherwise check scroll position
		adc	#SCRROWS-1
		cmp	nfiles		; already scrolled to the bottom?
		bcs	bardown		; then also move the bar
		inc	scrollpos	; otherwise scroll one down
		inc	dirpos		; adjust dir position
		bne	doscroll	; to common scroll code
bardown:	jsr	calcscrvec	; get pointer to current screen row
		lda	ZPS_0		; and calculate pointer to next
		adc	#SCRCOLS	; screen row
		sta	ZPS_2
		lda	ZPS_1
		adc	#0
		sta	ZPS_3
		inc	dirpos		; adjust dir and
		inc	scrpos		; screen position
		bne	doinv		; to common move bar
moveup:		lda	dirpos		; load current dir position
		beq	waitkey		; first entry? -> ignore moving up
		lda	scrpos		; load current screen position
		cmp	#4		; below 4th row from top?
		bcs	barup		; then just move the bar
		lda	scrollpos	; otherwise check scroll position
		beq	barup		; scrolled to top? -> just move bar
		dec	scrollpos	; otherwise scroll up
		dec	dirpos		; adjust dir position
doscroll:	jsr	showdir		; and re-render directory
noaction:	beq	waitkey		; back to waiting for key
barup:		jsr	calcscrvec	; get pointer to current screen row
		lda	ZPS_0		; and calculate pointer to previous
		sbc	#SCRCOLS-1	; screen row
		sta	ZPS_2
		lda	ZPS_1
		sbc	#0
		sta	ZPS_3
		dec	dirpos		; adjust dir and
		dec	scrpos		; screen position
doinv:		jmp	invbars
action:		lda	dirpos		; load dir position
		jsr	ftoffset	; calculate filetype offset from
.if .defined(VIC20_5K)			; only needed for unaligned BSS:
		adc	#<filetypes	; add filetype base address LB
.endif
		sta	rdtype+1
		lda	ZPS_2
		adc	#>filetypes	; add filetype page
		sta	rdtype+2
rdtype:		lda	$ffff		; load file type flags
		bpl	notadir		; #$80 means directory
		lda	dirpos		; load dir position
		jsr	chdir		; perform a cd command
		bcc	cdok		; no error?
cderror:	jsr	clrscr		; print cd error message
		print	cderrmsg, cderrlen
		jmp	exit		; and quit
cdok:		jmp	mainloop	; cd success -> restart main loop
notadir:	bne	diskimg		; #$01 means D64 image
		jsr	softreset	; PRG: first "soft-reset" machine
		lda	dirpos		; load dir position
		jsr	fnoffset	; calculate filename offset
.if .defined(VIC20_5K)			; only needed for unaligned BSS:
		adc	#<filenames	; add filenames base address
.endif
		sta	prgrdnm+1
		lda	ZPS_2
		adc	#>filenames
		sta	prgrdnm+2
		ldy	#0
fakeldsloop1:	lda	fakeldcmd,y	; write a fake LOAD cmd to screen
		sta	(ZPS_0),y
		iny
		cpy	#fakeldcmdlen
		bne	fakeldsloop1
		ldx	#$f
prgrdnm:	lda	$ffff,x		; write selected file name to screen
		beq	prgnmdone
		jsr	scrcode
		sta	(ZPS_0),y
		iny
		dex
		bpl	prgrdnm
prgnmdone:	lda	CURDEV
		bne	finishfakecmd
diskimg:	lda	dirpos		; load dir position
		jsr	mount		; and execute a "mount" there
		bcc	mountok		; no error -> continue
		jsr	clrscr		; print mount error msg and exit
		print	mnterrmsg, mnterrlen
		jmp	exit
mountok:	jsr	softreset	; mounted -> "soft-reset" machine
		lda	ZPS_4		; check whether RETURN was pressed
		cmp	#$d		; for this action
		bne	skipload	; if not, skip faking a LOAD
		ldy	#0		; write fake LOAD"0:*",8,1 to screen
fakecmdloop:	lda	fakeldcmd,y
		beq	finishfake8cmd
		sta	(ZPS_0),y
		iny
		bne	fakecmdloop
finishfake8cmd:	lda	#8
finishfakecmd:	jsr	writedrvno
		ldx	#fakerunkeyslen	; store length for faking keyboard
		stx	KBBUFLEN	; input ...
		dex
.if .defined(MACH_vic20) .or .defined(MACH_vic20e) .or .defined(MACH_vic20x)
		cpy	#SCRCOLS	; on vic-20, check written length
		bcc	fakekeysloop
		lda	ZPS_1		; if more than one screen row,
		ldy	scrpos		; store flag for "extended row"
		sta	$da,y		; for the next one
.endif
fakekeysloop:	lda	fakerunkeys,x	; ... and store a fake
		sta	KBBUF,x		; <RETURN>RUN<RETURN> in keyboard
		dex			; buffer.
		bpl	fakekeysloop
skipload:	ldx	#$fb		; force stack pointer to the value
		txs			; expected on BASIC coldstart, and
		cli			; return control to BASIC, printing
		jmp	BASICPROMPT	; READY. and executing keyboard buffer.

; invert bars on screen for two rows,
; base pointers in ZPS_0/ZPS_1 and ZPS_2/ZPS_3
invbars:
.if SCRCOLS > 25
		ldy	#25
.else
		ldy	#SCRCOLS-1
.endif
ib_invloop:	lda	(ZPS_0),y
		eor	#$80
		sta	(ZPS_0),y
		lda	(ZPS_2),y
		eor	#$80
		sta	(ZPS_2),y
		dey
		bpl	ib_invloop
		jmp	waitkey

; "Soft reset" routine for exit after mount or selecting a PRG to run
softreset:
.if .defined(MACH_c128)
		lda	#0		; c128: Bank in BASIC again
		sta	$ff00
.endif
		sei
		jsr	KRNL_RESETIO	; Reset I/O
		jsr	KRNL_RESTOR	; Restore kernal vectors
		jsr	KRNL_CINT	; Reset screen
		tsx			; save stack pointer because BASIC
		stx	sr_fixstack+1	; implementations fiddle with it
		jsr	STARTMSG	; print machine's start message
sr_fixstack:	ldx	#$ff		; restore stack pointer
		txs
		ldx	CRSRROW		; get current screen row
		inx
		inx			; set screen position to two below
		stx	scrpos
		jsr	clrcol		; init color RAM and "fallthrough"

; Calculate pointer to current screen line in ZPS_0/ZPS_1,
; using ZPS_2 as scratch space
; Only implemented for 40 and 22 screen columns, using fixed shift/add
; sequences.
calcscrvec:
		lda	#>SCREEN
		sta	ZPS_1
		lda	#0
		sta	ZPS_2
		lda	scrpos
.if SCRCOLS = 40
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
.elseif SCRCOLS = 22
		asl	a
		sta	ZPS_0
		asl	a
		tax			; save current factor ...
		adc	ZPS_0
		sta	ZPS_0
		txa			; to continue shifting after add
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		adc	ZPS_0
		sta	ZPS_0
.else
.error "Unsupported number of columns!"
.endif
		lda	ZPS_2
		adc	ZPS_1
		sta	ZPS_1
		rts

; Show current view of directory, based on scroll position and selected entry
showdir:
		lda	#0		; init base screen pointer ZPS_0/ZPS_1
		sta	ZPS_0		; and scratch space in ZPS_2
		lda	#>SCREEN
		sta	ZPS_1
		sec
		lda	nfiles		; subtract scroll position from total
		sbc	scrollpos	; number of files -> rows to show
.if .not .defined(VIC20_5K)
		beq	sd_defmax	; 0 (nfiles=0) -> have full 256 files
.endif
		cmp	#SCRROWS+1	; more than available screen rows?
		bcc	sd_maxok
sd_defmax:	lda	#SCRROWS	; then use number of screen rows
sd_maxok:	sta	ZPS_4		; row counter limit -> ZPS_4
		lda	scrollpos	; load scroll position
		jsr	fnoffset	; calculate offset to first filename
.if .defined(VIC20_5K)			; only needed for unaligned BSS:
		adc	#<filenames	; add filenames base pointer LB
.endif
		sta	sd_fnrd+1
		lda	ZPS_2
.if .defined (NODISPFN)
		adc	#>filenames	; add filenames page
.else
		adc	#>filedisp	; add filedisp page
.endif
		sta	sd_fnrd+2
		lda	scrollpos
		jsr	ftoffset	; calculate offset to first file type
.if .defined(VIC20_5K)			; only needed for unaligned BSS
		adc	#<filetypes
.endif
		sta	sd_ftrd+1
		lda	ZPS_2
		adc	#>filetypes
		sta	sd_ftrd+2
		ldy	#0		; init current row counter
sd_loop:	sty	ZPS_2		; in ZPS_2
		lda	#0
		cpy	scrpos		; handling selected row?
		bne	sd_norev
		lda	#$80		; then output in reverse (store
sd_norev:	sta	ZPS_3		; bit in ZPS_3, or'd to every output)
		ldy	#0		; init current column counter
.if SCRCOLS > 25
		jsr	sd_spcout	; if enough screen space, first
		sta	(ZPS_0),y	; print two spaces
		iny
.endif
		lda	#'<'		; print '<'
		jsr	sd_chrout
		ldx	#3		; print 3-character file type
sd_ftrd:	lda	$ffff,x
		jsr	sd_chrout
		dex
		bne	sd_ftrd
		lda	#'>'		; print '>'
		jsr	sd_chrout
		jsr	sd_spcout	; print a space
.if SCRCOLS > 25
		sta	(ZPS_0),y	; plus another when enough screen space
		iny
.endif
		ldx	#$f		; print 16 character filename
sd_fnrd:	lda	$ffff,x
.if .defined(NODISPFN)
		jsr	scrcode		; convert if necessary
.endif
		jsr	sd_chrout
		dex
		bpl	sd_fnrd
.if SCRCOLS > 25
		jsr	sd_spcout	; another space when enough room...
.endif
		clc			; advance all the pointers
		lda	sd_ftrd+1
		adc	#4		; +4 for filetypes
		sta	sd_ftrd+1
		bcc	sd_ftptrok
		inc	sd_ftrd+2
sd_ftptrok:	clc
		lda	sd_fnrd+1
		adc	#$10		; +16 for filenames
		sta	sd_fnrd+1
		bcc	sd_fnptrok
		inc	sd_fnrd+2
sd_fnptrok:	clc
		lda	ZPS_0
		adc	#SCRCOLS	; +<columns> for screen row
		sta	ZPS_0
		bcc	sd_scrptrok
		inc	ZPS_1
sd_scrptrok:	ldy	ZPS_2		; load row counter
		iny			; increment
		cpy	ZPS_4		; number of rows to print reached?
		bne	sd_loop		; no -> repeat
sd_done:	rts
sd_spcout:	lda	#$20
sd_chrout:	ora	ZPS_3		; apply reverse bit
		sta	(ZPS_0),y	; store to screen
		iny			; increment column counter
		rts
