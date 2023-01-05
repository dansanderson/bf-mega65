; Brainf*ck for MEGA65
;
; This is an interpreter for the Brainf*ck programming language, a minimalist
; experimental Turing-complete programming language with a funny name.
;
; https://en.wikipedia.org/wiki/Brainfuck
;
; Your BF program consists of parameter-less instructions capable of manipulating
; an array of bytes in memory, reading input, and writing output. A data cursor
; points to a location in the array, and the instructions either manipulate the
; byte in that location or move the data cursor. The sole control structure is
; a pair of matching brackets capable of conditional execution and looping.
;
; There are eight possible instructions, each represented by a single
; character.
;
;  >  Increment the data pointer.
;  <  Decrement the data pointer.
;  +  Increment the byte at the data pointer.
;  -  Decrement the byte at the data pointer.
;  .  Output the byte at the data pointer.
;  ,  Accept one byte of input, and store it at the data pointer.
;  [  If the byte at the data pointer is zero, jump to the instruction after
;     the matching ].
;  ]  If the byte at the data pointer is non-zero, jump to the instruction
;     after the matching [.
;
; Brackets are always in matched pairs, and can nest. A BF program with
; unmatched brackets is invalid and will not execute.
;
; With BF65, you write BF programs using the MEGA65 BASIC line
; editor. Any numbered line that begins with a BF character is recognized as a
; line of BF code. Any other BASIC line is ignored, and any character on a line
; of BF code that isn't a BF character is also ignored. [TODO: skipping of
; lines that don't begin with a BF instruction is not implemented yet. Right
; now it will recognize any BF character on any line as a BF instruction, and
; ignore all other characters.]
;
; This allows you to combine BASIC commands and BF code in the same listing,
; like so:
;
; 10 bank 0:bload "bf65":sys $1800:end
; 20 rem this program adds 2 and 5.
; 30 ++        set c0 to 2
; 40 > +++++   set c1 to 5
; 50 [ < + > - ]  loop: adding 1 to c0 and subtracting 1 from c1 until c1 is 0
;
; The first line (line 10) consists of BASIC commands to load BF65, run it,
; then end the program. BF65 ignores lines 10 and 20, and finds BF instructions
; starting on line 30. BF65 ignores the commentary on lines 30-50 because they
; do not contain BF instructions.
;
; (Note that this is not a combination of BASIC and BF in a single language.
; The BF interpreter runs when you call SYS $1800, and it starts from the
; beginning of the listing and skips all of the non-BF characters. When you
; type RUN, the BASIC interpreter assumes it will only see BASIC commands up to
; the END statement. It would be cool to have BF run inline with BASIC, but
; that's not what BF65 does.)
;
; A BF program can read a byte of input with the input (,) instruction. With
; this implementation, input is read from memory, up to 256 bytes starting at
; address $8500. The byte before the first null byte ($00), or the last byte of
; the region, whichever comes first, is considered the last byte of the input
; stream. Attempts to read beyond the last byte will have no effect. (According
; to Wikipedia, this is the de facto standard handling of EOF in BF
; implementations.)
;
; The output (.) instruction writes a character to the screen. There is no
; limit to output length, though the screen will scroll just like other
; terminal output.
;
; When execution is complete, you can examine the final state of the BF data
; region using the MEGA65 MONITOR. The data region starts at $8800.

!cpu m65
!to "bf65.prg", cbm

_primm = $ff7d  ; print immediate built-in

; Starting addresses
basicStart = $2001  ; TODO: get this from base page 0 instead of hard coding
inputBytes = $8500
bracketPairs = $8600
bracketPairsEnd = $8800
dataRegion = $8800
dataRegionEnd = $ffff

; Base page addresses
BP_highestDC = $00
BP_PC = $02
BP_DC = $04
BP_inputC = $06  ; 1 byte
BP_endOfData = $07  ; 1 byte
BP_nextBracket = $08
BP_bracketC = $0a

* = $1800

; User entry point
StartBF:
    jmp ActuallyStartBF

BITThisToSetOverflow: rts

InitDC:
    lda #<dataRegion
    sta BP_highestDC
    sta BP_DC
    lda #>dataRegion
    sta BP_highestDC+1
    sta BP_DC+1
    lda #0
    sta dataRegion  ; first byte of data region is 0
    rts

InitInput:
    lda #0
    sta BP_inputC
    sta BP_endOfData
    rts

; Initializes the interpreter
; On error A=$ff, else A=0
Initialize:
    ; Edge case: no BASIC program in memory
    lda basicStart
    bne +
    lda #$00
    tab
    jsr _primm
    !pet "no program in memory. ",0
    lda #$16
    tab
    lda #$ff
    rts   ; return with error
+

    jsr InitDC
    jsr InitInput

    jsr BuildBracketPairs
    cmp #$00
    beq +
    rts   ; return with error
+

    ; Scan BASIC for first BF instruction, set PC
    ; TODO: needs a new "next BF line" routine; use this to skip non-BF lines
    ;       in NextPC also; as written, evals BF chars on BASIC lines
    lda #<(basicStart + 4)
    sta BP_PC
    lda #>(basicStart + 4)
    sta BP_PC+1
    jsr LoadInstr
    cmp #$ff
    bne +
    jsr NextPC
+

    lda #$00
    rts   ; return with success

; Tests the char under PC
; If A on null, A=0
; If A on non-BF char, A=$ff
; Else A=char
LoadInstr:
    ldy #0
    lda (BP_PC),y
    beq ++    ; null
    cmp #$b1
    beq ++
    cmp #$b3
    beq ++
    cmp #$aa
    beq ++
    cmp #$ab
    beq ++
    cmp #$2e
    beq ++
    cmp #$2c
    beq ++
    cmp #$5b
    beq ++
    cmp #$5d
    beq ++
    bra +
++  rts
+

    ; << and >> are tokenized by BASIC 65 as FE 52 and FE 53. If PC is on FE,
    ; look ahead one byte and convert (< = b3, > = b1). If PC is on 52 or 53,
    ; look behind for FE and convert.
    cmp #$fe
    bne +
    ldy #1
    lda (BP_PC),y
    cmp #$52
    bne +++
    lda #$b3
    rts
+++ cmp #$53
    bne +
    lda #$b1
    rts

+   cmp #$52
    beq +++
    cmp #$53
    beq +++
    bra +
+++
    sec
    lda BP_PC
    sbc #1
    sta BP_PC
    lda BP_PC+1
    sbc #0
    sta BP_PC+1
    ldy #0
    lda (BP_PC),y
    tax
    clc
    lda BP_PC
    adc #1
    sta BP_PC
    lda BP_PC+1
    adc #0
    sta BP_PC+1
    cpx #$fe
    bne +
    ldy #0
    lda (BP_PC),y
    cmp #$52
    bne +++
    lda #$b3
    rts
+++ cmp #$53
    bne +
    lda #$b1
    rts

+
    lda #$ff  ; non-BF char
++  rts

; Scans the PC to the next BF instruction
; Sets overflow flag if past end (PC on null), otherwise clears
NextPC:
    clv
    ; Current PC on null == end of program
    jsr LoadInstr
    cmp #$00
    bne +
    bit BITThisToSetOverflow
    rts
+

-   inc BP_PC
    bne +
    inc BP_PC+1
+   jsr LoadInstr
    cmp #$00
    beq +   ; end of line
    cmp #$ff
    beq -   ; non-BF instruction
    bra ++

+   ldy #2
    lda (BP_PC),y
    beq ++     ; end of program, leave PC on null
    clc        ; advance to first char of next line (PC+5)
    lda #4     ; (5-1, because loop above will +1)
    adc BP_PC
    sta BP_PC
    lda #0
    adc BP_PC+1
    sta BP_PC+1
    bra -

++  clv
    rts

; Builds the bracket list
; On error, A=$ff, else A=0
BuildBracketPairs:
    ; bracketPairs is a list of 128 structures storing two 16-bit addresses: an
    ; opening bracket and a matching closing bracket. nextBracket points to the
    ; address of the next free structure, or bracketPairsEnd if the list is full.

    ; Fill bracketPairs to (bracketPairsEnd-1) with zeroes
    lda #<bracketPairs
    sta BP_bracketC
    lda #>bracketPairs
    sta BP_bracketC+1
-   ldy #0
    lda #0
    sta (BP_bracketC),y
    iny
    sta (BP_bracketC),y
    iny
    sta (BP_bracketC),y
    iny
    sta (BP_bracketC),y
    clc
    lda BP_bracketC
    adc #4
    sta BP_bracketC
    lda BP_bracketC+1
    adc #0
    sta BP_bracketC+1
    cmp #>bracketPairsEnd    ; (assumes bracketPairsEnd is $xx00)
    bne -

    ; Scan program for brackets
    lda #<(basicStart + 4)
    sta BP_PC
    lda #>(basicStart + 4)
    sta BP_PC+1
    lda #<bracketPairs
    sta BP_nextBracket
    lda #>bracketPairs
    sta BP_nextBracket+1
--- jsr LoadInstr
    cmp #$00
    beq +
    cmp #$5b   ; open bracket: add to end of bracket list
    bne ++
    ; if BP_nextBracket==bracketPairsEnd, error: too many brackets
    lda BP_nextBracket
    cmp #<bracketPairsEnd
    bne ++++
    lda BP_nextBracket+1
    cmp #>bracketPairsEnd
    bne ++++
    jmp _ErrTooManyBrackets
++++
    ; add to end of bracket list, BP_nextBracket += 4
    ldy #0
    lda BP_PC
    sta (BP_nextBracket),y
    ldy #1
    lda BP_PC+1
    sta (BP_nextBracket),y
    clc
    lda BP_nextBracket
    adc #4
    sta BP_nextBracket
    lda BP_nextBracket+1
    adc #0
    sta BP_nextBracket+1
    bra +++

++  cmp #$5d   ; close bracket: set on latest unclosed bracket
    bne +++
    lda BP_nextBracket
    sta BP_bracketC
    lda BP_nextBracket+1
    sta BP_bracketC+1
-   sec
    lda BP_bracketC
    sbc #4
    sta BP_bracketC
    lda BP_bracketC+1
    sbc #0
    sta BP_bracketC+1
    cmp #>bracketPairs  ; (assumes bracketPairs starts at $xx00)
    bpl ++
    jmp _ErrMismatchedBrackets
++  ldy #3
    lda (BP_bracketC),y
    cmp #$00
    bne -
    lda BP_PC+1
    sta (BP_bracketC),y
    ldy #2
    lda BP_PC
    sta (BP_bracketC),y

+++
    jsr NextPC
    bra ---

+
    ; if any open brackets unclosed, error: mismatched brackets
    lda #<bracketPairs
    sta BP_bracketC
    lda #>bracketPairs
    sta BP_bracketC+1
-   ldy #1
    lda (BP_bracketC),y
    cmp #$00
    beq +
    ldy #3
    lda (BP_bracketC),y
    cmp #$00
    beq ++
    clc
    lda BP_bracketC
    adc #4
    sta BP_bracketC
    lda BP_bracketC+1
    adc #0
    sta BP_bracketC+1
    cmp #>bracketPairsEnd    ; (assumes bracketPairsEnd is $xx00)
    bne -
    bra +
++  jmp _ErrMismatchedBrackets

+
    lda #$00
    rts

_ErrMismatchedBrackets:
    lda #$00
    tab
    jsr _primm
    !pet "error: mismatched brackets. ",0
    lda #$16
    tab
    lda #$ff
    rts

_ErrTooManyBrackets:
    lda #$00
    tab
    jsr _primm
    !pet "error: too many bracket pairs, max 128 pairs. ",0
    lda #$16
    tab
    lda #$ff
    rts

; Writes A to terminal
; (Unnecessarily slow for long strings because it flips the base page twice.)
; Clobbers A
WriteChar:
    tax
    lda #$00     ; temporarily switch base page back to 0 for kernel call
    tab
    txa
    jsr $ffd2    ; bsout
    lda #$16
    tab
    rts

; Writes A to terminal as hexadecimal number
; Clobbers A and Y
; (Only used for debugging)
_WriteHexLower:
    and #$0f
    clc
    adc #$30
    cmp #$3a
    bcc +
    clc
    adc #$07
+   jsr WriteChar
    rts
WriteHex:
    tay
    ror
    ror
    ror
    ror
    jsr _WriteHexLower
    tya
    jsr _WriteHexLower
    rts

; Writes the PC and the value at the PC as hex to the terminal
; Clobbers A and Y
; (Only used for debugging)
WritePC:
    lda BP_PC+1
    jsr WriteHex
    lda BP_PC
    jsr WriteHex
    lda #32
    jsr WriteChar
    ldy #0
    lda (BP_PC),y
    jsr WriteHex
    lda #13
    jsr WriteChar
    rts

; Performs the output instruction
OutputInstr:
    ldy #0
    lda (BP_DC),y
    cmp #10    ; write 10 as 13, to comply with other BF implementations
    bne +
    lda #13
+   jsr WriteChar
    rts

; Performs the input instruction
; If input data is exhausted, has no effect
InputInstr:
    lda BP_endOfData
    bne +    ; if endOfData flag is set, do nothing
    ldy BP_inputC
    lda inputBytes,y
    beq +    ; if byte under input cursor is 0, do nothing
    ldy #0
    sta (BP_DC),y
    inc BP_inputC
    bne +
    ; Has read 256 bytes, set endOfData flag
    lda #1
    sta BP_endOfData
+   rts

; Performs the increment DC instruction
; Sets overflow flag if DC is at end of range
IncDCInstr:
    clv

    ; If BP_DC == dataRegionEnd, set overflow and return
    lda #<dataRegionEnd
    cmp BP_DC
    bne +
    lda #>dataRegionEnd
    cmp BP_DC+1
    bne +
    bit BITThisToSetOverflow
    rts
+
    ; To avoid initializing the entire data region with zeroes, we track the
    ; highest seen data cell and when we go higher, we initialize along the
    ; way.
    ;
    ; If BP_DC == BP_highestDC, inc BP_highestDC; store 0
    lda BP_highestDC+1   ; (cmp BP_highestDC+1 first so A=BP_highestDC at end)
    cmp BP_DC+1
    bne ++
    lda BP_highestDC
    cmp BP_DC
    bne ++
    inc BP_highestDC
    bne +
    inc BP_highestDC+1
+   lda #0
    ldy #0
    sta (BP_highestDC),y
++
    ; Inc BP_DC
    inc BP_DC
    bne +
    inc BP_DC+1
+   rts

; Performs the decrement DC instruction
; Sets overflow flag if DC is at beginning of range
DecDCInstr:
    clv

    ; If BP_DC == dataRegion, set overflow and return
    lda #<dataRegion
    cmp BP_DC
    bne +
    lda #>dataRegion
    cmp BP_DC+1
    bne +
    bit BITThisToSetOverflow
    rts
+
    ; Dec BP_DC
    lda #1
    sta $fe
    lda #0
    sta $ff
    lda BP_DC
    sec
    sbc $fe
    sta BP_DC
    lda BP_DC+1
    sbc $ff
    sta BP_DC+1
    rts

; Performs the increment data instruction
IncDataInstr:
    ldy #0
    lda (BP_DC),y
    clc
    adc #1
    sta (BP_DC),y
    rts

; Performs the decrement data instruction
DecDataInstr:
    ldy #0
    lda (BP_DC),y
    sec
    sbc #1
    sta (BP_DC),y
    rts

LeftBracketInstr:
    ldy #0
    lda (BP_DC),y
    cmp #$00
    bne +
    ; find matching right bracket and set PC to that location
    lda #<bracketPairs
    sta BP_bracketC
    lda #>bracketPairs
    sta BP_bracketC+1
-   ldy #0
    lda (BP_bracketC),y
    cmp BP_PC
    bne ++
    ldy #1
    lda (BP_bracketC),y
    cmp BP_PC+1
    bne ++
    ldy #2
    lda (BP_bracketC),y
    sta BP_PC
    ldy #3
    lda (BP_bracketC),y
    sta BP_PC+1
    bra +
++  clc
    lda BP_bracketC
    adc #4
    sta BP_bracketC
    lda BP_bracketC+1
    adc #0
    sta BP_bracketC+1
    cmp #<bracketPairsEnd
    bne -
+   rts

RightBracketInstr:
    ldy #0
    lda (BP_DC),y
    cmp #$00
    beq +
    ; find matching left bracket and set PC to that location
    lda #<bracketPairs
    sta BP_bracketC
    lda #>bracketPairs
    sta BP_bracketC+1
-   ldy #2
    lda (BP_bracketC),y
    cmp BP_PC
    bne ++
    ldy #3
    lda (BP_bracketC),y
    cmp BP_PC+1
    bne ++
    ldy #0
    lda (BP_bracketC),y
    sta BP_PC
    ldy #1
    lda (BP_bracketC),y
    sta BP_PC+1
    bra +
++  clc
    lda BP_bracketC
    adc #4
    sta BP_bracketC
    lda BP_bracketC+1
    adc #0
    sta BP_bracketC+1
    cmp #<bracketPairsEnd
    bne -
+   rts

; Performs one instruction
; Sets overflow flag if past end, otherwise clears
; A=$ff on error
Step:
    clv

    jsr LoadInstr
    cmp #$00
    bne +    ; if PC on null, set overflow flag and return
    bit BITThisToSetOverflow
    rts

+   cmp #$b1
    bne ++
    jsr IncDCInstr
    bvc +   ; return error on overflow
    jmp _ErrOutOfRange

++  cmp #$b3
    bne ++
    jsr DecDCInstr
    bvc +   ; return error on overflow
    jmp _ErrOutOfRange

++  cmp #$aa
    bne ++
    jsr IncDataInstr
    bra +

++  cmp #$ab
    bne ++
    jsr DecDataInstr
    bra +

++  cmp #$2e
    bne ++
    jsr OutputInstr
    bra +

++  cmp #$2c
    bne ++
    jsr InputInstr
    ; ignore overflow: end of region is EOF
    bra +

++  cmp #$5b
    bne ++
    jsr LeftBracketInstr
    bra +

++  cmp #$5d
    bne +
    jsr RightBracketInstr

+   jsr NextPC
    lda #$00    ; return success
    rts

_ErrOutOfRange:
    lda #$00
    tab
    jsr _primm
    !pet "error: data cursor out of range. ",0
    lda #$16
    tab
    lda #$ff
    rts

; Perform user call: start
ActuallyStartBF:
    lda #$16
    tab

    jsr Initialize
    cmp #$ff
    beq +++

-   jsr Step
    cmp #$ff
    beq +++
    bvc -

    bra ++
+++
    lda #$00
    tab
    jsr _primm
    !pet "bf65 aborted.",13,0
    rts
++
    lda #$00
    tab
    rts
