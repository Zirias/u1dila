IOSTATUS=	$90		; current I/O status byte
CRSRROW=	$d6		; current row of the cursor
KBBUFLEN=	$c6		; length of keyboard buffer
CURCOL=		$286		; current text color
STOPVEC=	$328		; vector to STOP check routine
KBBUF=		$277		; keyboard buffer base
LSTX=		$c5		; currently pressed key
NOKEY=		$40		; flag for "no key pressed"
SCREEN=		$400		; start of text screen
COLRAM=		$d800		; Color RAM
SCRROWS=	25		; number of text rows
SCRCOLS=	40		; number of text columns
SCRNPG=		4		; screen/color RAM number of pages
STARTMSG=	$e422		; start message
BASICPROMPT=	$e386		; READY -> to BASIC

