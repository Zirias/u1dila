IOSTATUS=	$90		; current I/O status byte
CRSRROW=	$eb		; current row of the cursor
KBBUFLEN=	$d0		; length of keyboard buffer
CURCOL=		$f1		; current text color
STOPVEC=	$328		; vector to STOP check routine
KBBUF=		$34a		; keyboard buffer base
LSTX=		$d4		; currently pressed key
NOKEY=		$58		; flag for "no key pressed"
SCREEN=		$400		; start of text screen
COLRAM=		$d800		; Color RAM
SCRROWS=	25		; number of text rows
SCRCOLS=	40		; number of text columns
SCRNPG=		4		; screen/color RAM number of pages
STARTMSG=	$419b		; start message
BASICPROMPT=	$4d37		; READY -> to BASIC

