; Brainf*ck for MEGA65
; dddaaannn (dansanderson), January 2023
; Released under GPL 3. See LICENSE.

!cpu m65
!to "bf65.prg", cbm

_primm = $ff7d  ; print immediate built-in

; Starting addresses
basicStart = $2001
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

; Instruction codes as they appear in BASIC memory (see LoadInstr)
IN_IncDC = $b1
IN_DecDC = $b3
IN_IncData = $aa
IN_DecData = $ab
IN_Output = $2e
IN_Input = $2c
IN_LeftBracket = $5b
IN_RightBracket = $5d

* = $1800

; User entry point
StartBF:
    jmp ActuallyStartBF

!macro incPC .amount {
    clc
    lda BP_PC
    adc #.amount
    sta BP_PC
    lda BP_PC+1
    adc #0
    sta BP_PC+1
}

!macro decPC .amount {
    sec
    lda BP_PC
    sbc #.amount
    sta BP_PC
    lda BP_PC+1
    sbc #0
    sta BP_PC+1
}

!macro ldaFromPC .offset {
    ldy #.offset
    lda (BP_PC),y
}

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
    lda basicStart+1
    bne +
    jmp _ErrNoProgamInMemory
+   jsr InitDC
    jsr InitInput

    jsr BuildBracketPairs
    cmp #$00
    beq +
    rts   ; return with error
+

    ; Scan BASIC for first BF line
    lda #<(basicStart + 4)
    sta BP_PC
    lda #>(basicStart + 4)
    sta BP_PC+1
    jsr NextLine

    lda #$00
    rts   ; return with success

; Tests the char under PC
; If A on null, A=0
; If A on non-BF char, A=$ff
; Else A=char
LoadInstr:
    +ldaFromPC 0
    cmp #$00
    beq ++
    cmp #IN_IncDC
    beq ++
    cmp #IN_DecDC
    beq ++
    cmp #IN_IncData
    beq ++
    cmp #IN_DecData
    beq ++
    cmp #IN_Output
    beq ++
    cmp #IN_Input
    beq ++
    cmp #IN_LeftBracket
    beq ++
    cmp #IN_RightBracket
    beq ++
    bra +
++  rts
+

    ; << and >> are tokenized by BASIC 65 as FE 52 and FE 53. If PC is on FE,
    ; look ahead one byte and convert (< = b3, > = b1). If PC is on 52 or 53,
    ; look behind for FE and convert.
    cmp #$fe
    bne +
    +ldaFromPC 1
    cmp #$52
    bne +++
    lda #IN_DecDC
    rts
+++ cmp #$53
    bne +
    lda #IN_IncDC
    rts

+   cmp #$52
    beq +++
    cmp #$53
    beq +++
    bra +
+++
    +decPC 1
    +ldaFromPC 0
    tax
    +incPC 1
    cpx #$fe
    bne +
    +ldaFromPC 0
    cmp #$52
    bne +++
    lda #IN_DecDC
    rts
+++ cmp #$53
    bne +
    lda #IN_IncDC
    rts

+   lda #$ff  ; non-BF char
++  rts

; If value under PC is not null and not a BF instruction, advance to next BASIC
; line that begins with a BF instruction, or to the terminating null of the
; last line if none.
NextLine:
--  jsr LoadInstr
    cmp #$ff
    beq +   ; Value under PC is either null or BF instruction
    rts
+
-   +incPC 1
    +ldaFromPC 0
    cmp #$00   ; end of line
    bne -
    +ldaFromPC 2
    cmp #$00   ; end of program
    bne +
    rts
+   +incPC 5
    bra --

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

-   +incPC 1
--  jsr LoadInstr
    cmp #$00
    beq +   ; end of line
    cmp #$ff
    beq -   ; non-BF instruction
    bra ++

+   +ldaFromPC 2
    cmp #$00
    beq ++  ; end of program
    clc
    +incPC 5
    jsr NextLine
    bra --

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
    cmp #IN_LeftBracket   ; open bracket: add to end of bracket list
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

++  cmp #IN_RightBracket   ; close bracket: set on latest unclosed bracket
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

+   lda #$00
    rts


; Writes A as PETSCII to terminal
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

+   cmp #IN_IncDC
    bne ++
    jsr IncDCInstr
    bvc +   ; return error on overflow
    jmp _ErrOutOfRange

++  cmp #IN_DecDC
    bne ++
    jsr DecDCInstr
    bvc +   ; return error on overflow
    jmp _ErrOutOfRange

++  cmp #IN_IncData
    bne ++
    jsr IncDataInstr
    bra +

++  cmp #IN_DecData
    bne ++
    jsr DecDataInstr
    bra +

++  cmp #IN_Output
    bne ++
    jsr OutputInstr
    bra +

++  cmp #IN_Input
    bne ++
    jsr InputInstr
    ; ignore overflow: end of region is EOF
    bra +

++  cmp #IN_LeftBracket
    bne ++
    jsr LeftBracketInstr
    bra +

++  cmp #IN_RightBracket
    bne +
    jsr RightBracketInstr

+   jsr NextPC
    lda #$00    ; return success
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


_ErrNoProgamInMemory:
    lda #$00
    tab
    jsr _primm
    !pet "no program in memory. ",0
    lda #$16
    tab
    lda #$ff
    rts   ; return with error

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

_ErrOutOfRange:
    lda #$00
    tab
    jsr _primm
    !pet "error: data cursor out of range. ",0
    lda #$16
    tab
    lda #$ff
    rts
