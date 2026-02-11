.export scrcode

.code

scrcode:
		bmi	sc_shifted
		cmp	#$20
		bcc	sc_noprint
		cmp	#$60
		bcc	sc_lower
		and	#$df
		bne	sc_done
sc_noprint:	lda	#$20
		bne	sc_done
sc_lower:	and	#$3f
		bne	sc_done
sc_shifted:	cmp	#$ff
		bne	sc_nopi
		lda	#$5e
		bne	sc_done
sc_nopi:	and	#$7f
		cmp	#$20
		bcc	sc_noprint
		ora	#$40
sc_done:	rts
