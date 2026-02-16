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

readerrmsg:	.byte	$d, "error reading directory!", $d
readerrlen=	* - readerrmsg

cderrmsg:	.byte	$d, "error sending cd command!", $d
cderrlen=	* - cderrmsg

mnterrmsg:	.byte	$d, "error sending mount/kill!", $d
mnterrlen=	* - mnterrmsg

fakeldcmd:	.byte	12, 15, 1, 4, $22	; LOAD"
fakeldcmdlen=	*-fakeldcmd
		.byte	"0:*", $22, ",8,1", 0	; 0:*",8,1<NUL>
fakeld9cmd:	.byte	$22, ",9,1", 0		; ",9,1<NUL>
fakerunkeys:	.byte	$d, "run", $d
fakerunkeyslen=	*-fakerunkeys

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

; Main entry point, the BASIC header SYS command jumps here
entry:
		sei
.if .defined(MACH_c16) .or .defined(MACH_c128)
		ldx	#(2*FKEYS)-1	; save original function key
savefkeys:	lda	KEYDEFS,x	; definitions
		sta	fkeysave,x
		dex
		bpl	savefkeys
		lda	#1		; fill the first half with 1, here
		ldx	#FKEYS-1	; the lengths of the mappings are
fakeflen:	sta	KEYDEFS,x	; stored
		dex
		bpl	fakeflen
		ldx	#FKEYS-1	; copy key codes of the function keys
fakefcodes:	lda	KEYCODES,x	; into second half to achieve
		sta	KEYDEFS+FKEYS,x	; "identity mapping"
		dex
		bpl	fakefcodes
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
		rts
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
		sta	actionkey+1	; save key for later check on action
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
		beq	bardown		; then also move the bar
		inc	scrollpos	; otherwise scroll one down
		inc	dirpos		; adjust dir position
		jsr	showdir		; and re-render directory
		beq	waitkey		; back to waiting for key
bardown:	jsr	calcscrvec	; get pointer to current screen row
		lda	ZPS_0		; and calculate pointer to next
		adc	#SCRCOLS	; screen row
		sta	ZPS_2
		lda	ZPS_1
		adc	#0
		sta	ZPS_3
		jsr	invbars		; invert both rows to move the bar
		inc	dirpos		; adjust dir and
		inc	scrpos		; screen position
		bne	waitkey		; back to waiting for key
moveup:		lda	dirpos		; load current dir position
		beq	waitkey		; first entry? -> ignore moving up
		lda	scrpos		; load current screen position
		cmp	#4		; below 4th row from top?
		bcs	barup		; then just move the bar
		lda	scrollpos	; otherwise check scroll position
		beq	barup		; scrolled to top? -> just move bar
		dec	scrollpos	; otherwise scroll up
		dec	dirpos		; adjust dir position
		jsr	showdir		; and re-render directory
		beq	waitkey		; back to waiting for key
barup:		jsr	calcscrvec	; get pointer to current screen row
		lda	ZPS_0		; and calculate pointer to previous
		sbc	#SCRCOLS-1	; screen row
		sta	ZPS_2
		lda	ZPS_1
		sbc	#0
		sta	ZPS_3
		jsr	invbars		; invert both rows to move the bar
		dec	dirpos		; adjust dir and
		dec	scrpos		; screen position
noaction:	jmp	waitkey		; back to waiting for key
action:		lda	#0		; first initialize filetype offset
		sta	ZPS_2		; hi-byte in ZPS2
		lda	dirpos		; load dir position
		bne	chktype		; not first -> continue
		jsr	init		; special-case for first entry
		bcs	cderror		; handle command failed and
		bcc	cdok		; command success
chktype:	asl	a		; calculate filetype offset from
		rol	ZPS_2		; dir position
		asl	a
		rol	ZPS_2
		adc	#<filetypes	; add filetype base address
		sta	rdtype+1
		lda	ZPS_2
		adc	#>filetypes
		sta	rdtype+2
rdtype:		lda	$ffff		; load file type flags
		beq	noaction	; unsupported type -> do nothing
		bpl	notadir		; #$80 means directory
		lda	dirpos		; load dir position
		jsr	chdir		; perform a cd command
		bcc	cdok		; no error?
cderror:	jsr	clrscr		; print cd error message
		print	cderrmsg, cderrlen
		jmp	exit		; and quit
cdok:		jmp	mainloop	; cd success -> restart main loop
notadir:	lsr	a		; #$01 is D64 image
		bcs	diskimg
		jsr	softreset	; PRG: first "soft-reset" machine
		lda	dirpos		; load dir position
		jsr	fnoffset	; calculate filename offset
		adc	#<filenames	; add filenames base address
		sta	prgrdnm+1
		lda	ZPS_2
		adc	#>filenames
		sta	prgrdnm+2
		ldy	#0
fakeld9loop1:	lda	fakeldcmd,y	; write a fake LOAD cmd to screen
		sta	(ZPS_0),y
		iny
		cpy	#fakeldcmdlen
		bne	fakeld9loop1
prgrdnm:	lda	$ffff,x		; write selected file name to screen
		beq	prgnmdone
		jsr	scrcode
		sta	(ZPS_0),y
		iny
		inx
		cpx	#$10		; check max filename length
		beq	prgnmdone
		bne	prgrdnm
prgnmdone:	ldx	#0
fakeld9loop2:	lda	fakeld9cmd,x	; write fake ",9,1 to screen
		beq	fakecmddone	; skip disk image stuff when done
		sta	(ZPS_0),y
		iny
		inx
		bne	fakeld9loop2
diskimg:	lda	dirpos		; load dir position
		jsr	mount		; and execute a "mount" there
		bcc	mountok		; no error -> continue
		jsr	clrscr		; print mount error msg and exit
		print	mnterrmsg, mnterrlen
		jmp	exit
mountok:	jsr	softreset	; mounted -> "soft-reset" machine
actionkey:	lda	#$ff		; check whether RETURN was pressed
		cmp	#$d		; for this action
		bne	skipload	; if not, skip faking a LOAD
		ldy	#0		; write fake LOAD"0:*",8,1 to screen
fakecmdloop:	lda	fakeldcmd,y
		beq	fakecmddone
		sta	(ZPS_0),y
		iny
		bne	fakecmdloop
fakecmddone:	ldx	#fakerunkeyslen	; store length for faking keyboard
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
nostop:		rts

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
		lda	CRSRROW		; get current screen row
		clc
		adc	#2		; set screen position to two below
		sta	scrpos
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
		sta	ZPS_2
		lda	#>SCREEN
		sta	ZPS_1
		sec
		lda	nfiles		; subtract scroll position from total
		sbc	scrollpos	; number of files
.if .not .defined(VIC20_5K)
		beq	sd_defmax	; 0 (nfiles=0) -> have full 256 files
.endif
		cmp	#SCRROWS+1	; more than available screen rows?
		bcc	sd_maxok
sd_defmax:	lda	#SCRROWS	; then use number of screen rows
sd_maxok:	sta	ZPS_4		; row counter limit -> ZPS_4
		lda	scrollpos	; load scroll position
		jsr	fnoffset	; calculate offset to first filename
.if .defined (NODISPFN)
		adc	#<filenames	; add filenames base pointer
.else
		adc	#<filedisp	; screencode version when available
.endif
		sta	sd_fnrd+1
		lda	ZPS_2
.if .defined (NODISPFN)
		adc	#>filenames
.else
		adc	#>filedisp
.endif
		sta	sd_fnrd+2
		lda	#0		; calculate offset to first file type
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
		ldy	#0		; init current row counter
		sty	ZPS_2		; in ZPS_2
sd_loop:	lda	#0
		cpy	scrpos		; handling selected row?
		bne	sd_norev
		lda	#$80		; then output in reverse (store
sd_norev:	sta	ZPS_3		; bit in ZPS_3, or'd to every output)
		ldy	#0		; init current column counter
.if SCRCOLS > 25
		lda	#$20		; if enough screen space, first
		ora	ZPS_3		; print two spaces
		sta	(ZPS_0),y
		iny
		sta	(ZPS_0),y
		iny
.endif
		lda	#'<'		; print '<'
		ora	ZPS_3
		sta	(ZPS_0),y
		iny
		ldx	#1		; print 3-character file type
sd_ftrd:	lda	$ffff,x
		ora	ZPS_3
		sta	(ZPS_0),y
		iny
		inx
		cpx	#4
		bne	sd_ftrd
		lda	#'>'		; print '>'
		ora	ZPS_3
		sta	(ZPS_0),y
		iny
		lda	#$20		; print a space
		ora	ZPS_3
		sta	(ZPS_0),y
		iny
.if SCRCOLS > 25
		sta	(ZPS_0),y	; plus another when enough screen space
		iny
.endif
		ldx	#0		; print 16 character filename
sd_fnrd:	lda	$ffff,x
.if .defined(NODISPFN)
		jsr	scrcode		; convert if necessary
.endif
		ora	ZPS_3
		sta	(ZPS_0),y
		iny
		inx
		cpx	#$10
		bne	sd_fnrd
.if SCRCOLS > 25
		lda	#$20		; another space when enough room...
		ora	ZPS_3
		sta	(ZPS_0),y
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
		beq	sd_done
		sty	ZPS_2		; no -> repeat
		jmp	sd_loop
sd_done:	rts
