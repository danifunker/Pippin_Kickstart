/* Pippin Kickstart
 * Copyright 2019-2021 Keith Kaisershot
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
.equ	MBState,		0x172
.equ	SysHeap,		0x2A6
.equ	ROMBase,		0x2AE

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

/* Device Manager constants */
.equ	ejectCode,		7
.equ	fsFromStart,	1

/* Disk Driver error codes */
.equ	noDriveErr,		-64
.equ	offLinErr,		-65

/* Patch constants */
.equ	heapData,		52
.equ	bkLim,			0
.equ	blkSize,		4
.equ	nRelBit,		6
.equ	sizeCorr,		3

.equ	scsiBlkSize,	4240 + 12
.equ	scsiStrsCksum,	0x26B134CE

.equ	tVectorsSize,	43
.equ	tvsOffset,		0x724
.equ	tvsEnd,			0x928
.equ	strsEnd,		0xAD0

.equ	codeStart,		0xB854
.equ	codeEntry,		0xBAD4
.equ	codeEnd,		0x14324
.equ	codeSize,		codeEnd - codeStart
.equ	codeOffset,		codeEntry - codeStart

.equ	patchLoc1,		0xC1F2
.equ	patchLoc2,		0xCEDE
.equ	patchLoc3,		0xC3A0
.equ	patchLoc4,		0xC396

/* Graphics constants */
.equ	whiteColor,		30
.equ	blackColor,		33

.equ	GrafGlobals,	0
.equ	thePort,		0
.equ	clipRgn,		28

.equ	screenWidth,	640
.equ	screenHeight,	480

.equ	logoWidth,		125
.equ	logoHeight,		125

.equ	logoX,			(screenWidth - logoWidth) / 2
.equ	logoY,			(screenHeight - logoHeight) / 2

.equ	outlineThickness,	7

.equ	logoRoutineOffset,	0xE3C	/* same place in every retail Pippin ROM */

.equ	shackleWidth,		91
.equ	shackleThickness,	22
.equ	shackleRadius,		shackleThickness * 3
.equ	distanceToNotch,	46
.equ	distanceFromNotch,	shackleThickness / 2
.equ	notchHeight,		((distanceFromNotch + 1) / 2) * 2

.equ	notchOvalRadius,	17

/* Miscellaneous constants */
.equ	gestaltPhysicalRAMSize,	0x72616D20	/* 'ram ' */
.equ	ellipsis,		201
.equ	dsNoPatch,		98

/* Toolbox traps */
.macro	_Read
	dc.w	0xA002
	.endm
.macro	_Control
	dc.w	0xA004
	.endm
.macro	_Gestalt
	dc.w	0xA1AD
	.endm
.macro	_BlockMoveData
	dc.w	0xA22E
	.endm
.macro	_NewPtrSys
	dc.w	0xA51E
	.endm
.macro	_SetClip
	dc.w	0xA879
	.endm
.macro	_GetClip
	dc.w	0xA87A
	.endm
.macro	_ForeColor
	dc.w	0xA862
	.endm
.macro	_BackColor
	dc.w	0xA863
	.endm
.macro	_DrawChar
	dc.w	0xA883
	.endm
.macro	_DrawString
	dc.w	0xA884
	.endm
.macro	_MoveTo
	dc.w	0xA893
	.endm
.macro	_GetPen
	dc.w	0xA89A
	.endm
.macro	_PenSize
	dc.w	0xA89B
	.endm
.macro	_FrameRect
	dc.w	0xA8A1
	.endm
.macro	_EraseRect
	dc.w	0xA8A3
	.endm
.macro	_FrameRoundRect
	dc.w	0xA8B0
	.endm
.macro	_PaintArc
	dc.w	0xA8BF
	.endm
.macro	_EraseRgn
	dc.w	0xA8D4
	.endm
.macro	_NewRgn
	dc.w	0xA8D8
	.endm
.macro	_DisposeRgn
	dc.w	0xA8D9
	.endm
.macro	_RectRgn
	dc.w	0xA8DF
	.endm
.macro	_SectRgn
	dc.w	0xA8E4
	.endm
.macro	_DiffRgn
	dc.w	0xA8E6
	.endm
.macro	_SysError
	dc.w	0xA9C9
	.endm
.macro	_InitPack
	dc.w	0xA9E5
	.endm
.macro	_Pack7
	dc.w	0xA9EE
	.endm

.equ	MaxBootBlockSize,	512	/* one 512-byte disk block */
/* We'll keep the Pippin auth file in the second disk block. ;) */

_start:
BootBlock1:
	dc.w	0x4C4B	/* 'LK' is the magic that indicates HFS boot blocks */
	bra.w	PippinKickstart
	
/* These two bytes have to be here or the boot blocks won't get executed. */
Version:
	dc.b	'D'
	dc.b	0x18
/* Everything from here on out is for us to use however we want. */
	
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
	
PippinKickstart:
	/* A0 contains a pointer to the ParamBlock that led us here. */
	/* We need this later to eject ourselves, so use A4 for the ROM check. */
	/* A4 is preserved so we can draw the Pippin logo from ROM later. */
	movea.l	ROMBase, %a4
	move.w	0x12(%a4), %d0	/* the minor version is always at offset 18 */
	
	/* D7 also contains the same ParamBlock pointer, but we don't care. */
	/* That same pointer eventually gets passed to our new boot blocks later. */
	moveq.l	#SubtableSize-1, %d7
NextROM:
	cmp.w	ROMVersionTable(%pc, %d7.w*2), %d0
	beq.s	GotROM
	dbra	%d7, NextROM
	moveq.l	#dsNoPatch, %d0
	_SysError				/* if we're not running on a retail Pippin, bail */
	
GotROM:
	
/* Main kickstart code: */
/* D7.W contains an index into all of the ROM-specific tables. */
	
	move.l	%a0, -(%a7)	/* save our ParamBlock since QuickDraw trashes A0 */
	move.w	#7, -(%a7)	/* make sure PACK 7 is available for _NumToString */
	_InitPack
	
/* Create the regions, clear the screen, and draw a "locked" Pippin... */
	
SetupGraphics:
	lea		logoRect, %a3
	
	subq.l	#8, %a7
	_NewRgn					/* create clipRgn */
	move.l	(%a7), %d5		/* save clipRgn */
	move.l	%a3, -(%a7)
	_RectRgn				/* clipRgn == logoRect */
	
	_NewRgn					/* create tempRgn */
	move.l	(%a7), %d6		/* put tempRgn in D6 because D7 is our ROM index */
	move.l	%d6, (tempRgn - logoRect)(%a3)	/* save tempRgn in RAM since D6 */
											/*  is used by the search loop */
	_GetClip				/* tempRgn == original clip region */
	
	movem.l	%d5-%d6/%a3, -(%a7)
	move.l	%d5, -(%a7)
	_DiffRgn				/* clipRgn == original clip region - logoRect */
	pea		blackColor
	_BackColor
	move.l	%d5, -(%a7)
	_EraseRgn				/* erase around the logo */
	
	pea		whiteColor
	_ForeColor				/* draw white-on-black */
	move.l	#((outlineThickness << 16) + outlineThickness), -(%a7)
	_PenSize
	_FrameRect				/* draw logo outline */
	
	jsr		logoRoutineOffset(%a4)	/* draw the Pippin logo from ROM */
	
	bsr.w	DrawShackle
	
	addq.l	#8, %a3			/* A3 -> clipRect */
	move.l	%d5, -(%a7)
	move.l	%a3, -(%a7)
	_RectRgn				/* clipRgn == clipRect */
	
	movea.l	GrafGlobals(%a5), %a0	/* A0 -> qdGlobals */
	movea.l	thePort(%a0), %a0		/* A0 -> qdGlobals.thePort */
	move.l	clipRgn(%a0), -(%a7)	/* push existing clip region */
	move.l	%d5, -(%a7)				/* find intersection with clipRect */
	move.l	%d5, -(%a7)				/* make it our next clip region */
	_SectRgn
	
/* Say hello, give credit where due... */
	
	move.l	#0x00300040, -(%a7)	/* (64, 48) from the upper-left corner */
	_MoveTo
	
	lea		HelloString, %a0
	bsr.w	PrintLine
	lea		SiteString-1, %a0
	move.b	#SkippedString-SiteString, (%a0)
	bsr.w	PrintLine
	bsr.w	NextLine
	
/* Let's print what ROM we're running... */
	
	pea		DetectedString
	_DrawString
	move.b	ROMDigitTable(%pc, %d7.w), %d0
	move.w	%d0, -(%a7)
	_DrawChar
	
/* ... and how much RAM we have installed. */
	
	pea		ROMCommaString
	_DrawString
	
	move.l	#gestaltPhysicalRAMSize, %d0
	_Gestalt			/* we'll assume _Gestalt succeeds... */
	move.l	%a0, %d0	/* _Gestalt returns our value in A0 */
	moveq.l	#10, %d1
	lsr.l	%d1, %d0	/* divide Gestalt result by 1024 to get size in KB */
	subq.l	#8, %a7		/* allocate an up-to-seven-digit Pascal string */
	move.l	%a7, %a0	/* Mac OS doesn't support > 1.5GB of RAM anyway ;) */
	move.l	%a0, -(%a7)	/* have A0 in the stack, ready for _DrawString */
	clr.w	-(%a7)	/* selector #0: _NumToString, takes params in A0 and D0 */
	_Pack7
	_DrawString
	addq.l	#8, %a7
	
	lea		RAMString, %a0
	bsr.w	PrintLine
	
/* Check to see if the SCSI Manager is impaired, and patch it if so. */
	
	tst.w	%d7				/* ROM 1.0 is index 0 into our subtables */
	bne.w	GoodSCSI
	
	pea		PatchString
	_DrawString
	
	tst.b	(MBState)		/* skip patching if the mouse button is down */
	bpl.w	SkipPatching
	
	movea.l	SysHeap, %a0
	lea		heapData(%a0), %a1	/* A1 -> allocated block in system heap */
NextSysBlock:
	cmp.l	bkLim(%a0), %a1	/* bkLim(A0) -> system heap trailer block */
	beq.w	SkipPatching	/* if this block is the trailer, we've searched */
							/*  the entire system heap and couldn't find the */
							/*  SCSI Manager's pidata section */
	
	movea.l	%a1, %a4
	move.l	blkSize(%a1), %d0	/* D0 == physical size of this block */
	add.l	%d0, %a1			/* A1 -> the next block in case we skip */
	
	btst.b	#nRelBit, (%a4)	/* is this block non-relocatable (bit 6 set)? */
	beq.s	NextSysBlock
	
	sub.b	sizeCorr(%a4), %d0	/* D0 == logical size of this block + 12 */
	cmpi.w	#scsiBlkSize, %d0	/* is this block the right size? */
	bne.s	NextSysBlock
	
	adda.w	#(12 + tvsOffset), %a4	/* A4 -> address of code at offset 0xBAD4 */
									/*  into code section */
									/* earliest TVector after 0xB854, where */
									/*  our patched code starts */
	
	movea.l	%a4, %a3
	adda.w	#(tvsEnd - tvsOffset), %a3	/* A3 -> end of TVector area */
										/* this is also the start of the */
										/*  strings area */
	movea.l	%a3, %a2
	adda.w	#(strsEnd - tvsEnd), %a2	/* A2 -> after end of strings */
	
	/* Verify this really is the SCSI Manager's block in the system heap. */
	/* We do that by checksumming the area in the middle of this block where */
	/*  we know the SCSI Manager looks for some read-only strings. Use an */
	/*  algorithm similar to that used to checksum the Toolbox, only we'll */
	/*  walk our pointer backwards so we can use A3 as-is if/when it comes */
	/*  time to check our TVectors. */
ChecksumLoop:
	add.l	-(%a2), %d0
	cmpa.l	%a2, %a3
	ble.s	ChecksumLoop
	cmp.l	#scsiStrsCksum, %d0
	bne.s	NextSysBlock
	
	/* At this point we can reasonably assume we've found the SCSI Manager's */
	/*  pidata section, allocated and initialized in the system heap. */
	
	/* Check the TVectors to see if any have been patched already. */
	/* If *any* of the TVectors are patched, we shouldn't patch anything */
	/*  because either we already have our patches applied, or somebody else */
	/*  has patched the SCSI Manager, in which case we don't know where these */
	/*  TVectors point anymore. */
CheckLoop:
	subq.l	#8, %a3
	tst.l	-(%a3)
	bpl.s	SkipPatching	/* if the high bit of (A3) is set, we know this */
							/*  TVector still points into ROM, so we haven't */
							/*  patched it */
	cmpa.l	%a3, %a4
	bne.s	CheckLoop
	
	move.l	#codeSize, %d6	/* size of the code we need to patch */
							/* we only actually need to patch nine bytes in */
							/*  four places */
	move.l	%d6, %d0		/* IM '92 says block size is passed in A0. Lies. */
	_NewPtrSys				/* put our patch in the system heap */
	
	movea.l	%a0, %a1			/* A1 -> our patched area (dst) */
	movea.l	(%a4), %a0			/* A0 -> 0xBAD4 into code section */
	suba.w	#codeOffset, %a0	/* A0 -> 0xB854 into code section (src) */
	
	move.l	%d6, %d0	/* copy 0xB854 to 0x14324 into our patched area */
	_BlockMoveData		/* don't flush the 68K emulator's cache for PPC code */
	
	/* patch the code */
	move.l	#0x00074081, %d0			/* #7 as a word, then beq.s */
	move.l	%d0, (patchLoc1 - codeStart)(%a1)
	move.l	%d0, (patchLoc2 - codeStart)(%a1)
	move.w	%d0, (patchLoc3 - codeStart)(%a1)
	swap	%d0
	move.w	%d0, (patchLoc4 - codeStart)(%a1)
	
	suba.l	%a1, %a0	/* A0 == delta between destination and source */
	
	/* now let's patch up the TVectors to point to our patched code */
	move.b	#tVectorsSize-1, %d0	/* # of TVectors to patch minus one */
TVectorLoop:
	movea.l	(%a4), %a2
	suba.l	%a0, %a2
	move.l	%a2, (%a4)+
	addq.l	#8, %a4
	dbra	%d0, TVectorLoop
	
	movea.l	%a1, %a0
	move.l	%d6, %d0
	dc.w	0xFE0C		/* undocumented F-line instruction that evicts our */
						/*  patched area from the PPC data cache into main */
						/*  memory so it's visible to the instruction decoder */
	
	lea		DoneString, %a0
	bra.w	DonePatching
	
SkipPatching:
	lea		SkippedString, %a0
	bra.w	DonePatching
	
logoRect:
	dc.w	logoY - outlineThickness
	dc.w	logoX - outlineThickness
	dc.w	logoY + logoHeight + outlineThickness
	dc.w	logoX + logoWidth + outlineThickness
lockedRect:
	dc.w	logoY - outlineThickness - distanceToNotch
	dc.w	logoX - outlineThickness + (((shackleWidth + 1) / 2) - shackleThickness)
	dc.w	logoY - outlineThickness + (shackleRadius / 2)
	dc.w	logoX - outlineThickness + (((shackleWidth + 1) / 2) - shackleThickness + shackleWidth)
clipRect:
	dc.w	logoY - outlineThickness - (distanceToNotch + notchHeight)
	dc.w	logoX - outlineThickness + (((shackleWidth + 1) / 2) - shackleThickness)
	dc.w	logoY - outlineThickness + distanceFromNotch
	dc.w	logoX + logoWidth + outlineThickness + (shackleWidth / 2)
	
DetectedString:
	dc.b	PatchString-.-1
	.ascii	"Detected 1."
PatchString:
	dc.b	EjectString-.-1
	.ascii	"Patching SCSI Manager"
	dc.b	ellipsis
EjectString:
	dc.b	SearchString-.-1
	.ascii	"Ejecting boot media"
	dc.b	ellipsis
SearchString:
	dc.b	EndOfStrings1-.-1
	.ascii	"Finding boot candidate"
	dc.b	ellipsis
EndOfStrings1:
	
/* Pad the rest of our block with 0xDA bytes. */
.equ	BootBlock1Size,	.-BootBlock1
.space	MaxBootBlockSize-BootBlock1Size, 0xDA
	
BootBlock2:
/* Leave some room for a minimal Pippin authentication block. */
.space	8, 0xDA
HelloString:
	dc.b	SiteString-HelloString+7-1
	.ascii	"Pippin Kickstart 1.1 by "
SiteString:
	/* Don't define a length here because we poke it into SiteString-1. */
	.ascii	"blitter.net/pippinkickstart"
SkippedString:
	dc.b	EndOfStrings2-.-1
	.ascii	" skipped."
EndOfStrings2:
.space	64-(.-HelloString), 0x00
.space	112-(.-BootBlock2), 0xDA
	
/* Designate some room for tempRgn. */
.equ	tempRgn,	.-4
	
unlockedRect:
	dc.w	logoY - outlineThickness - (distanceToNotch + notchHeight)
	dc.w	logoX + logoWidth + outlineThickness - (shackleWidth / 2)
	dc.w	logoY - outlineThickness + distanceFromNotch + (shackleRadius / 2)
	dc.w	logoX + logoWidth + outlineThickness + (shackleWidth / 2)
notchRect:
	dc.w	logoY - outlineThickness - notchHeight
	dc.w	logoX + logoWidth + outlineThickness + (shackleWidth / 2) - shackleThickness
	dc.w	logoY - outlineThickness
	dc.w	logoX + logoWidth + outlineThickness + (shackleWidth / 2) - (shackleThickness / 2)
arcRect:
	dc.w	logoY - outlineThickness - (notchHeight / 2) - (notchOvalRadius / 2)
	dc.w	logoX + logoWidth + outlineThickness + (shackleWidth / 2) - (shackleThickness /  2) - (notchOvalRadius) + 2
	dc.w	logoY - outlineThickness - (notchHeight / 2) + (notchOvalRadius / 2)
	dc.w	logoX + logoWidth + outlineThickness + (shackleWidth / 2) - (shackleThickness /  2) + (notchOvalRadius) - 1
	
/* These subroutines are here so they're in range of our bsr.s instructions. */
	
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
	
/* input: none */
/* trashes: D0-D2, A0-A1 are scratch regs used by QuickDraw */
NextLine:
	subq.l	#4, %a7
	move.l	%a7, -(%a7)
	_GetPen
	/* Advance down by 16 pixels and return to the left "margin." */
	add.w	#0x0010, (%a7)
	move.w	#0x0040, 2(%a7)
	_MoveTo
	rts
	
/* input: A3 -> shackle rect - 8 */
/* trashes: D0-D2, A0-A1 are scratch regs used by QuickDraw */
DrawShackle:
	move.l	%d5, -(%a7)
	_SetClip			/* clip shackle to logo */
	
	move.l	#((shackleThickness << 16) + shackleThickness), -(%a7)
	_PenSize
	
	addq.l	#8, %a3		/* a3 -> shackle rect */
	move.l	%a3, -(%a7)
	move.l	#((shackleRadius << 16) + shackleRadius), -(%a7)
	_FrameRoundRect
	rts
	
DonePatching:
	bsr.s	PrintLine
GoodSCSI:
/* First, let's eject ourselves... */
	
	pea		EjectString
	_DrawString
	
	movea.l	(%a7)+, %a0	/* get our ParamBlock back */
	bsr.w	Eject
	
	bsr.s	PrintDone
	
	pea		SearchString
	_DrawString
	
/* Now let's enter a loop similar to what the Start Manager does, */
/*  but without an auth/driver check. */
	
	/* Push return address here. */
	/* Take us directly to after the call to FindStartupDevice upon return. */
	bsr.s	GetROMAddress	/* index into FoundBootDiskSubtable */
	move.l	%a1, -(%a7)
	
	link	%a4, #-frameSize	/* same frame size used by Start Manager */
	
	/* Jsr to EmbarkOnSearch */
	bsr.s	JsrToROM	/* trashes D0-D2, A0-A1, but doesn't touch D7 */
	
	lea		IsItAnything, %a3	/* override what EmbarkOnSearch gives us */
	/* We always want to accept any and all candidates. */
	
	bra.s	FirstEntry
	
/* input:  D7.W == index into table (which ROM are we * desired subtable) */
/* output: A1   == return address from table */
/*         D7.W == next desired index */
GetROMAddress:
	movea.l	ROMBase, %a1
	adda.w	ROMOffsetTable(%pc, %d7.w*2), %a1
	addq.w	#SubtableSize, %d7
	rts
	
/* We found a boot candidate, so let's jump back into ROM and boot it. */
/* We know we've found valid boot blocks because we checked ourselves. */
	
GotIt:
	move.l	%a0, -(%a7)	/* save the ParamBlock from SelectDevice */
	bsr.s	PrintDone
	
	/* Let folks know we're about to boot. */
	pea		FoundString
	_DrawString
	
	/* Erase the "locked" Pippin. */
	move.l	%d5, -(%a7)
	_EraseRgn
	
	/* Draw an "unlocked" Pippin. */
	lea		unlockedRect-8, %a3		/* because A4 is our link pointer */
	bsr.s	DrawShackle
	
	pea		notchRect
	_EraseRect
	pea		arcRect
	clr.w	-(%a7)
	move.w	#-45, -(%a7)
	_PaintArc
	
	/* Clean up. */
	move.l	%d5, -(%a7)		/* push clipRgn */
	_DisposeRgn
	move.l	-(%a3), -(%a7)	/* push tempRgn */
	move.l	(%a3), -(%a7)	/* push tempRgn */
	_SetClip
	_DisposeRgn
	
	movea.l	(%a7)+, %a0	/* restore the ParamBlock from SelectDevice */
	
	/* Push return address here. */
	bsr.s	GetROMAddress	/* index into AfterRvprTable */
	move.l	%a1, -(%a7)
	
	/* Jump directly to GetStartupInfo, return to the beq.s after 'rvpr' 0. */
	/* Fall through to JsrToROM; trashes A1 */
	/*  but who cares because this code no longer exists after this returns */
	/*  since it'll be replaced by fresh boot blocks, ready to execute. ;) */
	
/* input:  D7.W == index into table (which ROM are we * desired subtable) */
/* output: D7.W == next desired index */
/* trashes: A1 */
JsrToROM:
	bsr.s	GetROMAddress
	jmp		(%a1)
	
	/* ... and we're done here. */
	
NextPass:
	subq.w	#(SubtableSize * 2), %d7
	/* rewind FindNextCandidate, LoadSCSIDrivers */
	
FirstEntry:
	/* Jsr to LoadSCSIDrivers */
	bsr.s	JsrToROM	/* trashes D0-D2, A0-A1, but doesn't touch D7 */
	
TryAgain:
	/* Give .AppleCD some time */
	lea		-ioQElSize(%a7), %a7
	movea.l	%a7, %a0
	move.l	#0xFFDC0041, ioRefNum(%a0)	/* ioRefNum: -36, csCode: 65 (accRun) */
	_Control
	lea		ioQElSize(%a7), %a7
	
	/* Jsr to FindNextCandidate */
	bsr.s	JsrToROM	/* trashes D0-D2, A0-A1, but doesn't touch D7 */
	beq.s	NextPass
	
	/* Jsr to SelectDevice */
	bsr.s	JsrToROM	/* trashes D0, returns A0/A2 but doesn't touch D7 */
	
	/* Read and verify the boot blocks ourselves. */
	/* This way, if we detect early that they're invalid, we can stay in our */
	/*  own loop without relinquishing control to the ROM and its checks. */
	move.w	#fsFromStart, ioPosMode(%a0)
	clr.l	ioPosOffset(%a0)
	move.l	%a6, ioBuffer(%a0)
	move.l	#0x200, ioReqCount(%a0)
	_Read
	cmp.w	#0x4C4B, (%a6)	/* 'LK' is the magic word */
	beq.s	GotIt
	
	/* rewind SelectDevice, FindNextCandidate */
	subq.w	#(SubtableSize * 2), %d7
	
	/* Eject if D0 is not offLinErr (-65) or noDriveErr (-64). */
	add.w	#-noDriveErr, %d0
	beq.s	TryAgain
	addq.w	#noDriveErr-offLinErr, %d0
	beq.s	TryAgain
	pea		TryAgain	/* return to TryAgain */
	
Eject:
	move.w	#ejectCode, csCode(%a0)
	_Control
	rts
	
IsItAnything:
	cmp.w	%d0, %d0	/* return beq */
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
	
ROMCommaString:
	dc.b	RAMString-.-1
	.ascii	" ROM, "
RAMString:
	dc.b	FoundString-.-1
	.ascii	"K RAM"
FoundString:
	dc.b	DoneString-.-1
	.ascii	"Booting"
	dc.b	ellipsis
DoneString:
	dc.b	EndOfStrings3-.-1
	.ascii	" done."
EndOfStrings3:
	
/* Pad the rest of our block with 0xDA bytes... */
/*  ... but leave some room for the authentication signature block. */
.equ	BootBlock2Size, .-BootBlock2
.space	MaxBootBlockSize-49-BootBlock2Size, 0xDA
.space	1, 0xDA
	
ROMDigitTable:
	dc.b	'0'
	dc.b	'2'
	dc.b	'3'
	
.space  45, 0xDA
