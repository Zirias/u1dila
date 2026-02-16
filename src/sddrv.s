.include "kernal.inc"
.include "platform.inc"
.include "scrcode.inc"
.include "zpshared.inc"

.export readdir
.export init
.export chdir
.export mount
.export fnoffset
.export driveno
.export filenames
.if .not .defined(NODISPFN)
.export filedisp
.endif
.export filetypes
.export nfiles

.data

driveno:	.byte	$9		; default drive no #9
cdcmd:		.byte	":dc"		; 1541-U command "cd:"
cdcmdlen=	*-cdcmd
mntcmd:		.byte	":tnuom"	; 1541-U command "mount:"
mntcmdlen=	*-mntcmd
killcmd:	.byte	"0llik"		; 1541-U command "kill0"
killcmdlen=	*-killcmd
initcmd:	.byte	"0tini"		; 1541-U command "init0"
initcmdlen=	*-initcmd

.bss

nfiles:		.res	1		; number of files in dir, 0 = 256

.if .defined(VIC20_5K)
MAXFILES=	104			; maximum for unexpanded vic-20 ..
.else
MAXFILES=	256			; ... and all other machines
.segment "ALBSS"
.align $100		; page-align dir data on all but unexpanded vic-20
.endif

filenames:	.res	16 * MAXFILES	; file names in PETSCII
.if .not .defined(NODISPFN)
filedisp:	.res	16 * MAXFILES	; file names in screen code
.endif
filetypes:	.res	4 * MAXFILES	; types, 1 flags byte, 3 screen code

.code

; Read current directory by requesting the "pseudo-BASIC" file "$" from the
; drive and parsing the result on the fly
readdir:
		lda	driveno
		jsr	KRNL_LISTEN	; listen, drive!
		lda	#$f0		; open ($f) channel 0 ($0)
		jsr	KRNL_SECOND
		asl	IOSTATUS	; check bus status
		bcc	rd_listened
rd_error:	rts			; on error, exit with carry set
rd_listened:	lda	#'$'		; request file "$"
		jsr	KRNL_CIOUT
		jsr	KRNL_UNLSN	; stop listening
		lda	driveno
		jsr	KRNL_TALK	; now, please talk ... ;)
		lda	#$60		; ... on channel 0
		jsr	KRNL_TKSA
		lda	#0		; reset bus status just in case
		sta	IOSTATUS
		ldy	#6		; skip 6 bytes (ldaddr, BASIC ptr/line)
rd_titleloop:	jsr	rdbyte		; read a byte
		bcs	rd_error	; carry means error
		dey
		bpl	rd_titleloop
		tax			; now skip until NUL byte marking
		bne	rd_titleloop	; end of BASIC  line

		; we ignored the "title" line, but having received it is an
		; indicator everything worked, so start actual parsing

		ldy	#$1f		; initialize our first two entries
rd_clrloop:	sta	filenames,y	; to 0 ....
.if .not .defined(NODISPFN)
		eor	#$20		; ... and $20 (space) for screencode
		sta	filedisp,y	;
		eor	#$20
.endif
		dey
		bpl	rd_clrloop
		lda	#'/'		; create the two "pseudo-dirs"
		sta	filenames	; "/" and ".."
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
		lda	#$80			; type flag for DIR
		sta	filetypes+4
		lda	#4			; 'D'
		sta	filetypes+1
		sta	filetypes+5
		lda	#9			; 'I'
		sta	filetypes+2
		sta	filetypes+6
		lda	#18			; 'R'
		sta	filetypes+3
		sta	filetypes+7
		lda	#2			; now we have 2 files
		sta	nfiles
		lda	#<(filenames+$20)	; initialize write pointers
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
		lda	#<(filetypes+8)
		sta	ZPS_0
		lda	#>(filetypes+8)
		sta	ZPS_1
rd_fileloop:	ldy	#4		; for every line, ignore 4 bytes:
rd_entryloop:	jsr	rdbyte		; BASIC line pointer and number
		bcc	*+5		; and handle timeout/EOI ...
		jmp	rd_dirend	; ... by just stopping
		dey
		bpl	rd_entryloop
		tax			; copy to X just for checking
		beq	rd_fileloop	; found NUL: end of line
		cmp	#'"'		; look for " (start of filename)
		bne	rd_entryloop
		ldy	#0		; name character counter
rd_fnmloop:	jsr	rdbyte
		bcc	*+5
		jmp	rd_dirend
		cmp	#'"'		; end of filename?
		beq	rd_havenm
rd_fnwrite1:	sta	$ffff,y		; store byte of filename
.if .not .defined(NODISPFN)
		jsr	scrcode		; and convert to screencode to
rd_fdwrite1:	sta	$ffff,y		; store that as well
.endif
		iny
		cpy	#$10		; check maximum length (16)
		bne	rd_fnmloop
rd_fnmtrunc:	jsr	rdbyte		; if necessary, read extra name bytes
		bcc	*+5
		jmp	rd_dirend
		beq	rd_fileloop	; NUL? -> end of current line
		cmp	#'"'		; end of filename?
		bne	rd_fnmtrunc	; otherwise keep ignoring
rd_havenm:	lda	#0		; name complete, fill up with NUL
rd_nmfill:	cpy	#$10		; until we have 16 bytes
		beq	rd_nmfilled
rd_fnwrite2:	sta	$ffff,y		; store NUL
.if .not .defined(NODISPFN)
		eor	#$20		; ... and space for screen code
rd_fdwrite2:	sta	$ffff,y
		eor	#$20
.endif
		iny
		bne	rd_nmfill
rd_nmfilled:	jsr	rdbyte		; keep reading to find type
		bcc	*+5
		jmp	rd_dirend
		cmp	#$20		; space? not the type yet
		beq	rd_nmfilled
		ldy	#1		; index to store type characters
rd_typeloop:	tax			; copy to X just for testing
		beq	rd_fileloop	; NUL: end of current line
		jsr	scrcode		; otherwise convert to screen code
rd_ftwrite:	sta	(ZPS_0),y	; and store
		jsr	rdbyte		; read next character
		bcc	*+5
		jmp	rd_dirend
		iny
		cpy	#5		; have all 3 type characters?
		bne	rd_typeloop	; no -> repeat
rd_scaneol:	tax			; copy to X just for testing
		beq	rd_nextfile	; NUL: end found, do post-process
		jsr	rdbyte		; keep reading/ignoring until EOL
		bcc	rd_scaneol
		jmp	rd_dirend
rd_nextfile:	lda	#0		; initialize filetype flags to 0
		tay
		sta	(ZPS_0),y
		iny
		lda	(ZPS_0),y
		cmp	#4		; first char is 'D'?
		bne	rd_ftchkprg	; no -> check PRG
		iny
		lda	(ZPS_0),y
		cmp	#9		; second char is 'I'?
		beq	rd_ftchkdir	; yes -> could be DIR
		cmp	#$36		; second char is '6'?
		bne	rd_ftfdone	; no -> no known file type
		iny
		lda	(ZPS_0),y
		cmp	#$34		; last char is '4'?
		bne	rd_ftfdone	; no -> no known file type
		lda	#1		; flag for "D64"
		ldy	#0
		sta	(ZPS_0),y	; store in flags
		beq	rd_ftfdone
rd_ftchkprg:	cmp	#16		; first char is 'P'?
		bne	rd_ftfdone	; no -> no known file type
		iny
		lda	(ZPS_0),y
		cmp	#18		; second char is 'R'?
		bne	rd_ftfdone
		iny
		lda	(ZPS_0),y
		cmp	#7		; last char is 'G'?
		bne	rd_ftfdone
		lda	#2		; flag for "PRG"
		ldy	#0
		sta	(ZPS_0),y	; store in flags
		beq	rd_ftfdone
rd_ftchkdir:	iny
		lda	(ZPS_0),y
		cmp	#18		; final char is 'R'?
		bne	rd_ftfdone
		lda	#$80		; flag for "DIR"
		ldy	#0
		sta	(ZPS_0),y	; store in flags
rd_ftfdone:	clc
		lda	rd_fnwrite1+1	; update all pointers for next entry
		adc	#$10
		sta	rd_fnwrite1+1
		sta	rd_fnwrite2+1
		bcc	rd_fnsamepg
		inc	rd_fnwrite1+2
		inc	rd_fnwrite2+2
rd_fnsamepg:	clc
.if .not .defined(NODISPFN)
		lda	rd_fdwrite1+1
		adc	#$10
		sta	rd_fdwrite1+1
		sta	rd_fdwrite2+1
		lda	rd_fdwrite1+2
		adc	#0
		sta	rd_fdwrite1+2
		sta	rd_fdwrite2+2
.endif
		lda	ZPS_0
		adc	#4
		sta	ZPS_0
		bcc	rd_ftsamepg
		inc	ZPS_1
rd_ftsamepg:	inc	nfiles		; increment number if files
.if .defined(VIC20_5K)
		lda	nfiles
		cmp	#MAXFILES	; check for max
.endif
		beq	rd_dirend	; max reached -> stop reading $
		jmp	rd_fileloop	; read next entry
rd_dirend:	jsr	KRNL_UNTLK	; drive, stop talking!
		lda	driveno
		jsr	KRNL_LISTEN	; and listen now...
		lda	#$e0		; close ($e) channel 0 ($0).
		jsr	KRNL_SECOND
		jsr	KRNL_UNLSN	; stop listening
		clc			; no error -> clear carry
		rts

; Send the init0 command (used as a workaround for non-funct "cd:/")
init:
		lda	#<initcmd
		ldx	#>initcmd
		ldy	#initcmdlen-1
		jsr	sendcmd
		bcs	init_done	; error sending command?
		jsr	KRNL_UNLSN
		asl	IOSTATUS	; move possible timeout to carry
init_done:	rts

; Send the cd:xxxx command
chdir:
		jsr	setname		; set pointer to current filename
		lda	#<cdcmd
		ldx	#>cdcmd
		ldy	#cdcmdlen-1
		jsr	sendcmd		; send command prefix "cd:"
		bcs	cd_done		; error?
		jsr	sendname	; send the name (also doing UNLSN)
		asl	IOSTATUS	; move possible timeout to carry
cd_done:	rts

; Send the mount:xxxx command, followed by kill0
mount:
		jsr	setname		; set pointer to current filename
		lda	#<mntcmd
		ldx	#>mntcmd
		ldy	#mntcmdlen-1
		jsr	sendcmd		; send command prefix "mount:"
		bcs	mnt_done	; error?
		jsr	sendname	; send the name (also doing UNLSN)
		asl	IOSTATUS	; move possible timeout to carry
		bcs	mnt_done	; error?
		lda	#<killcmd
		ldx	#>killcmd
		ldy	#killcmdlen-1
		jsr	sendcmd		; send "kill0" command
		jsr	KRNL_UNLSN
		asl	IOSTATUS	; move possible timeout to carry
mnt_done:	rts

; Send a given command to the drive:
;	A/X:	pointer to command string (in reverse order)
;  	Y:	command length minus one
sendcmd:
		sta	sc_cmdloop+1	; save pointer to command
		stx	sc_cmdloop+2
		sty	sc_listened+1	; save starting index for sending
		lda	#0		; reset bus status just in case
		sta	IOSTATUS
		lda	driveno
		jsr	KRNL_LISTEN	; listen, drive!
		lda	#$6f		; ... on channel #15
		jsr	KRNL_SECOND
		bit	IOSTATUS
		bpl	sc_listened	; error listening?
		jsr	KRNL_UNLSN
sc_error:	sec			; then set carry to indicate the error
		rts
sc_listened:	ldx	#$ff		; index of last byte
sc_cmdloop:	lda	$ffff,x		; send bytes in ...
		jsr	KRNL_CIOUT	; ... reverse order
		dex
		bpl	sc_cmdloop
		clc			; no error -> clear carry
		rts

; Calculate filename offset for file number in A (or: A*16)
; in:	A
; out:	A (low byte), ZPS_2 (high byte)
; clob:	X
fnoffset:
		ldx	#0
		stx	ZPS_2
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		asl	a
		rol	ZPS_2
		rts

; Set pointer to current file name for 'sendname'
setname:
		jsr	fnoffset
		adc	#<filenames
		sta	sn_rdfn+1
		lda	ZPS_2
		adc	#>filenames
		sta	sn_rdfn+2
		rts

; Send current file name
sendname:
		ldx	#0
sn_rdfn:	lda	$ffff,x
		beq	sn_cmddone	; NUL: End of filename
		jsr	KRNL_CIOUT
		inx
		cpx	#$10		; max 16 bytes
		bne	sn_rdfn
sn_cmddone:	jmp	KRNL_UNLSN	; UNLSN after sending name

; Read a byte from talking drive
rdbyte:
		sec			; set carry as error flag ...
		bit	IOSTATUS	; ... and check current status
		bmi	rb_out		; error on timeout
		bvs	rb_out		; error on EOI (end of information)
		jsr	KRNL_ACPTR	; otherwise read next byte
		clc			; and clear error flag
rb_out:		rts

