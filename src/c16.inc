IOSTATUS=	$90		; current I/O status byte
CRSRROW=	$cd		; current row of the cursor
KBBUFLEN=	$ef		; length of keyboard buffer
CURCOL=		$53b		; current text color
STOPVEC=	$326		; vector to STOP check routine
KBBUF=		$527		; keyboard buffer base
LSTX=		$7f6		; currently pressed key
SCREEN=		$c00		; start of text screen
COLRAM=		$800		; Color RAM
SCRROWS=	25		; number of text rows
SCRCOLS=	40		; number of text columns
SCRNPG=		4		; screen/color RAM number of pages
STARTMSG=	$80c2		; start message
BASICPROMPT=	$867e		; READY -> to BASIC

