/* Pippin Kickstart
 * Copyright 2019 Keith Kaisershot
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

.arch 68020

.section .text
.global _start

/* Low memory globals */
.equ	MemTop,		0x0108
.equ	ROMBase,	0x02AE

/* Data block sizes */
.equ	frameSize,		90
.equ	ioQElSize,		50

/* Offsets into ParamBlock */
.equ	ioPosOffset,	46
.equ	ioPosMode,		44
.equ	ioReqCount,		36
.equ	ioBuffer,		32
.equ	csCode,			26
.equ	ioRefNum,		24

/* Offsets into drive queue element */
.equ	dqRefNum,		8

/* Device Manager constants */
.equ	flashRefNum,	-81
.equ	ejectCode,		7
.equ	fsFromStart,	1

/* Disk Driver error codes */
.equ	offLinErr,		-65
.equ	noDriveErr,		-64

/* Miscellaneous constants */
.equ	whiteColor,		30
.equ	dsNoPatch,		98
.equ	ellipsis,		201

/* Toolbox traps */
.macro	_Read
	dc.w	0xA002
	.endm
.macro	_Control
	dc.w	0xA004
	.endm
.macro	_DrawChar
	dc.w	0xA883
	.endm
.macro	_DrawString
	dc.w	0xA884
	.endm
.macro	_DrawText
	dc.w	0xA885
	.endm
.macro	_ForeColor
	dc.w	0xA862
	.endm
.macro	_GetPen
	dc.w	0xA89A
	.endm
.macro	_InitAllPacks
	dc.w	0xA9E6
	.endm
.macro	_MoveTo
	dc.w	0xA893
	.endm
.macro	_SysError
	dc.w	0xA9C9
	.endm
.macro	_Pack7
	dc.w	0xA9EE
	.endm

.equ	MaxBootBlocksSize,	512	/* one 512-byte disk block */
/* We'll keep the Pippin auth file in the second disk block. ;) */

_start:
BootBlocks:
	dc.w	0x4C4B	/* 'LK' is the magic that indicates HFS boot blocks */
	bra		PippinKickstart
	
/* These two bytes have to be here or the boot blocks won't get executed. */
Version:
	dc.b	'D'
	dc.b	0x18
/* Everything from here on out is for us to use however we want. */
	
NotAPippin:
	moveq	#dsNoPatch, %d0
	_SysError
	
ROMVersionTable:
	
	/* Pippin ROM minor version numbers */
	/* The major version at offset 8 is always $77D for the "Universal" ROM. */
	
	/* Only put entries here for retail ROMs that perform authentication. */
	/* Don't put entries here for "Disco," "C3," or "GM Flash." */
	/* These ROMs already can boot from whatever without any checks. */
	dc.w	0x2CF2	/* 1.0 */
	dc.w	0x2CF5	/* 1.2 */
	dc.w	0x2CF8	/* 1.3 */
.equ	SubtableSize,	(.-ROMVersionTable)/2
	
ROMDigitTable:
	dc.b	'0'
	dc.b	'2'
	dc.b	'3'
ROMCommaString:
	/* This string just so happens to realign us to an even boundary. :) */
	dc.b	PippinKickstart-.-1
	.ascii	" ROM, "
	
PippinKickstart:
	/* A0 contains a pointer to the ParamBlock that led us here. */
	/* We need this later to eject ourselves, so use A1 for the ROM check. */
	movea.l	ROMBase, %a1
	move	0x12(%a1), %d0	/* the minor version is always at offset 18 */
	
	/* D7 also contains the same ParamBlock pointer, but we don't care. */
	/* That same pointer eventually gets passed to our new boot blocks later. */
	moveq	#SubtableSize, %d7
NextROM:
	subq	#1, %d7
	bmi.b	NotAPippin
	
	cmp		ROMVersionTable(%pc, %d7.w*2), %d0
	bne.b	NextROM
	
/* Main kickstart code: */
/* D7.W contains an index into all of the ROM-specific tables. */
	
	move.l	%a0, -(%a7)	/* save our ParamBlock since QuickDraw trashes A0 */
	_InitAllPacks	/* make sure PACK 7 is available */
	
	move.l	#whiteColor, -(%a7)
	_ForeColor
	
	move.l	#0x00300040, -(%a7)	/* (64, 48) from the upper-left corner */
	_MoveTo
	
/* Say hello, give credit where due... */
	
	lea		HelloString, %a0
	bsr		PrintLine
	lea		SiteString-1, %a0
	move.b	#DetectedString-SiteString, (%a0)
	bsr		PrintLine
	bsr		NextLine
	
/* Let's print what ROM we're running... */
	
	pea		DetectedString
	_DrawString
	move.b	ROMDigitTable(%pc, %d7.w), %d0
	move.w	%d0, -(%a7)
	_DrawChar
	
/* ... and how much RAM we have installed. */
	
	pea		ROMCommaString
	_DrawString
	
	subq.l	#8, %a7		/* allocate an up-to-seven-digit Pascal string */
	movea.l	%a7, %a0	/* Mac OS doesn't support > 1.5GB of RAM anyway ;) */
	move.l	%a0, -(%a7)	/* have A0 in the stack, ready for _DrawString */
	move.l	MemTop, %d0
	move	#10, %d1
	lsr.l	%d1, %d0	/* divide MemTop by 1024 to give us kilobytes */
	clr		-(%a7)	/* selector #0: _NumToString */
	_Pack7
	_DrawString
	addq.l	#8, %a7
	
	lea		RAMString, %a0
	bsr		PrintLine
	
/* First, let's eject ourselves... */
	
	pea		EjectString
	_DrawString
	
	movea.l	(%a7)+, %a0	/* get our ParamBlock back */
	bsr.b	Eject
	
	bsr		PrintDone
	
/* Now let's enter a loop similar to what the Start Manager does, */
/*  but without an auth/driver check. */
	
	pea		SearchString
	_DrawString
	
	/* Push return address here. */
	/* Take us directly to after the call to FindStartupDevice upon return. */
	bsr		GetROMAddress	/* index into FoundBootDiskSubtable */
	move.l	%a1, -(%a7)
	
	link	%a4, #-frameSize	/* same frame size used by Start Manager */
	
	/* Jsr to EmbarkOnSearch */
	bsr.b	JsrToROM	/* trashes D0-D2, A0-A1, but doesn't touch D7 */
	
	lea		IsItAnything, %a3	/* override what EmbarkOnSearch gives us */
	/* We always want to accept any and all candidates. */
	
	bra.b	FirstEntry
	
NextPass:
	subq	#(SubtableSize * 2), %d7
	/* rewind FindNextCandidate, LoadSCSIDrivers */
	
FirstEntry:
	/* Jsr to LoadSCSIDrivers */
	bsr.b	JsrToROM	/* trashes D0-D2, A0-A1, but doesn't touch D7 */
	
TryAgain:
	/* Give .AppleCD some time */
	lea		-ioQElSize(%a7), %a7
	movea.l	%a7, %a0
	move.l	#0xFFDC0041, ioRefNum(%a0)	/* ioRefNum: -36, csCode: 65 (accRun) */
	_Control
	lea		ioQElSize(%a7), %a7
	
	/* Jsr to FindNextCandidate */
	bsr.b	JsrToROM	/* trashes D0-D2, A0-A1, but doesn't touch D7 */
	beq.b	NextPass
	
	/* Jsr to SelectDevice */
	bsr.b	JsrToROM	/* trashes D0, returns A0/A2 but doesn't touch D7 */
	
	/* Read and verify the boot blocks ourselves. */
	/* This way, if we detect early that they're invalid, we can stay in our */
	/*  own loop without relinquishing control to the ROM and its checks. */
	move	#fsFromStart, ioPosMode(%a0)
	clr.l	ioPosOffset(%a0)
	move.l	%a6, ioBuffer(%a0)
	move.l	#0x200, %d0
	add.l	%d0, ioBuffer(%a0)
	move.l	%d0, ioReqCount(%a0)
	_Read
	cmp		#0x4C4B, 0x200(%a6)	/* 'LK' is the magic word */
	beq.b	GotIt
	
	/* rewind SelectDevice, FindNextCandidate */
	subq	#(SubtableSize * 2), %d7
	
	/* Eject if D0 is not offLinErr (-65) or noDriveErr (-64). */
	add		#-noDriveErr, %d0
	beq.b	TryAgain
	addq	#noDriveErr-offLinErr, %d0
	beq.b	TryAgain
	pea		TryAgain	/* return to TryAgain */
	
/* Eject is here so it's within range of the bsr.b instruction that calls it. */
Eject:
	move	#ejectCode, csCode(%a0)
	_Control
	rts
	
/* We found a boot candidate, so let's jump back into ROM and boot it. */
/* We know we've found valid boot blocks because we checked ourselves. */
	
GotIt:
	move.l	%a0, -(%a7)	/* save the ParamBlock from SelectDevice */
	bsr.b	PrintDone
	/* Let folks know we're about to boot. */
	pea		FoundString
	_DrawString
	movea.l	(%a7)+, %a0	/* restore the ParamBlock from SelectDevice */
	
	/* Push return address here. */
	bsr.b	GetROMAddress	/* index into AfterRvprTable */
	move.l	%a1, -(%a7)
	
	/* Jump directly to GetStartupInfo, return to the beq.b after 'rvpr' 0. */
	/* Fall through to JsrToROM; trashes A1 */
	/*  but who cares because this code no longer exists after this returns */
	/*  since it'll be replaced by fresh boot blocks, ready to execute. ;) */
	
/* input:  D7.W == index into table (which ROM are we * desired subtable) */
/* output: D7.W == next desired index */
/* trashes: A1 */
JsrToROM:
	bsr.b	GetROMAddress
	jmp		(%a1)
	
	/* ... and we're done here. */
	
/* input:  D7.W == index into table (which ROM are we * desired subtable) */
/* output: A1   == return address from table */
/*         D7.W == next desired index */
GetROMAddress:
	movea.l	ROMBase, %a1
	adda	ROMOffsetTable(%pc, %d7.w*2), %a1
	addq	#SubtableSize, %d7
	rts
	
/* input: none */
/* trashes: D0-D2, A0-A1 are scratch regs used by QuickDraw */
PrintDone:
	lea		DoneString, %a0
	/* Fall through to PrintLine */
	
/* input: A0 -> Pascal string to print */
/* trashes: D0-D2, A0-A1 are scratch regs used by QuickDraw */
PrintLine:
	move.l	%a0, -(%a7)
	_DrawString
	/* Fall through to NextLine */
	
/* input: none */
/* trashes: D0-D2, A0-A1 are scratch regs used by QuickDraw */
NextLine:
	subq.l	#4, %a7
	move.l	%a7, -(%a7)
	_GetPen
	/* Advance down by 16 pixels and return to the left "margin." */
	add		#0x0010, (%a7)
	move	#0x0040, 2(%a7)
	_MoveTo
/* Putting this here (in place of NextLine's rts) gets me two bytes back. */
IsItAnything:
	cmp		%d0, %d0	/* return beq */
	rts
	
ROMOffsetTable:
/* The organization and order of this table are extremely important. */
/* D7.W is initialized to the initial ROM index into FoundBootDiskSubtable. */
/* Each call to GetROMAddress or JsrToROM advances D7 by SubtableSize. */
/* Each call to GetROMAddress or JsrToROM in turn corresponds to the order in */
/*  which ROMOffsetTable is organized; that is, these offsets must be */
/*  accessed in the order they are defined here. */
/* D7 must be subbed/added accordingly if these tables are to be accessed out */
/*  of order, as is done during the candidate-finding loop. */
FoundBootDiskSubtable:		/* return address */
	dc.w	0x22BC	/* 1.0 */
	dc.w	0x235C	/* 1.2 */
	dc.w	0x234C	/* 1.3 */
	
EmbarkOnSearchSubtable:		/* ROM call */
	dc.w	0x16EC	/* 1.0 */
	dc.w	0x1764	/* 1.2 */
	dc.w	0x1760	/* 1.3 */
	
LoadSCSIDriversSubtable:	/* ROM call */
	dc.w	0x1808	/* 1.0 */
	dc.w	0x1880	/* 1.2 */
	dc.w	0x187C	/* 1.3 */
	
FindNextCandidateSubtable:	/* ROM call */
	dc.w	0x1918	/* 1.0 */
	dc.w	0x1996	/* 1.2 */
	dc.w	0x1992	/* 1.3 */
	
SelectDeviceSubtable:		/* ROM call */
	dc.w	0x1956	/* 1.0 */
	dc.w	0x19D4	/* 1.2 */
	dc.w	0x19D0	/* 1.3 */
	
AfterRvprSubtable:			/* return address */
	dc.w	0x15B0	/* 1.0 */
	dc.w	0x160C	/* 1.2 */
	dc.w	0x1614	/* 1.3 */
	
GetStartupInfoSubtable:		/* ROM call */
	dc.w	0x1988	/* 1.0 */
	dc.w	0x1A06	/* 1.2 */
	dc.w	0x1A02	/* 1.3 */
	
HelloString:
	dc.b	31 /* SiteString-.-1 */
	.ascii	"Pippin Kickstart 1.0 by " /* blitter" */
SiteString:
	/* dc.b	DetectedString-.-1 */
	.ascii	"blitter.net/pippinkickstart"
DetectedString:
	dc.b	RAMString-.-1
	.ascii	"Detected 1."
RAMString:
	dc.b	EjectString-.-1
	.ascii	"K RAM"
EjectString:
	dc.b	SearchString-.-1
	.ascii	"Ejecting boot media"
	dc.b	ellipsis
SearchString:
	dc.b	FoundString-.-1
	.ascii	"Finding boot candidate"
	dc.b	ellipsis
FoundString:
	dc.b	DoneString-.-1
	.ascii	"Booting"
	dc.b	ellipsis
DoneString:
	dc.b	EndOfStrings-.-1
	.ascii	" done."
EndOfStrings:

/* Pad the rest of our block with 0xDA bytes. */
.equ	BootBlocksSize,	.-BootBlocks
.space	MaxBootBlocksSize-BootBlocksSize, 0xDA
