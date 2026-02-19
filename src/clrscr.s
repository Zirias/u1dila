.include "kernal.inc"
.include "platform.inc"

.export clrscr
.export clrcol

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

