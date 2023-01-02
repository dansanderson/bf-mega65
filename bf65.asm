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
; With this version of BF, you write BF programs using the MEGA65 BASIC line
; editor. Any numbered line that begins with a BF character is recognized as a
; line of BF code. Any other BASIC line is ignored, and any character on a line
; of BF code that isn't a BF character is also ignored. For example:
;
; 10 rem this program adds 2 and 5.
; 20 ++        set c0 to 2
; 30 > +++++   set c1 to 5
; 40 [ < + > - ]  loop: adding 1 to c0 and subtracting 1 from c1 until c1 is 0
;
; To start BF, run this command:
;    BANK 0:SYS $8000
;
; Because BF ignores non-BF BASIC lines, you can start your program with
; BASIC commands to load BF65 from disk and execute it, then just run it like a
; BASIC program. Be sure to include an END statement before the first BF line.
;
; 10 bload "bf65":bank 0:sys $8000:end
; 20 ++>+++++[<+>-]
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
; region using the MONITOR. The data region starts at $8800.

!cpu m65
!to "bf65.prg", cbm

; Starting addresses
basicStart = $2001
inputBytes = $8500
bracketPairs = $8600
dataRegion = $8800
dataRegionEnd = $ffff

; Base page addresses
BP_highestDC = $00
BP_PC = $02
BP_DC = $04
BP_inputC = $06  ; 1 byte
BP_endOfData = $07  ; 1 byte
BP_nextBracket = $08

* = $8000  ; TODO: update this to ensure program ends before $84ff

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
    jsr InitDC
    jsr InitInput

    jsr BuildBracketList
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
    rts

; Tests the char under PC
; If A on null, A=0
; If A on non-BF char, A=$ff
; Else A=char
LoadInstr:
    ldy #0
    lda (BP_PC),y
    bne +    ; null
    rts
+
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
    lda #$ff  ; non-BF char
++  rts

; Scans the PC to the next BF instruction
; Sets overflow flag if past end (PC on null), otherwise clears
NextPC:
    ; Current PC on null == end of program
    jsr LoadInstr
    bne +
    bit BITThisToSetOverflow
    rts
+

-   inc BP_PC
    bne +
    inc BP_PC+1
+   jsr LoadInstr
    beq +   ; end of line
    cmp #$ff
    beq -   ; non-BF instruction
    bra ++

+   ldy #1
    lda (BP_PC),y
    beq ++     ; end of program, leave PC on null
    clc        ; advance to first char of next line (PC+5)
    lda #5
    adc BP_PC
    lda #0
    adc BP_PC+1
    bra -

++  clv
    rts

; Builds the bracket list
; On error, A=$ff, else A=0
BuildBracketList:
    lda #<(basicStart + 4)
    sta BP_PC
    lda #>(basicStart + 4)
    sta BP_PC+1
    lda #<bracketPairs
    sta BP_nextBracket
    lda #>bracketPairs
    sta BP_nextBracket+1
    jsr LoadInstr
-   bvs +
    ; TODO
    ;   - if open bracket
    ;     - if BP_nextBracket==dataRegion, bra +++
    ;     - else add to end of bracket list, inc BP_nextBracket
    ;   - if closed bracket
    ;     - find latest unclosed bracket in list
    ;       - if not found, bra ++
    ;       - else set it
    jsr NextPC
    bra -
+
    ; - if any open brackets unclosed, bra ++
    rts
++  jsr $ff7d   ; primm
    !pet "error: mismatched brackets",0
    lda #$ff
    rts
+++ jsr $ff7d   ; primm
    !pet "error: too many bracket pairs, max 128 pairs",0
    lda #$ff
    rts

; Performs the output instruction
OutputInstr:
    ldy #0
    lda (BP_DC),y
    tax
    lda #$00     ; temporarily switch base page back to 0 for kernel call
    tab
    txa
    jsr $ffd2    ; bsout
    lda #$16
    tab
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
    sta (BP_DC),y
++
    ; Inc BP_DC
    inc BP_DC
    bne +
    inc BP_DC+1
+   rts

; Performs the decrement DC instruction
; Sets overflow flag if DC is at beginning of range
DecDCInstr:
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
    sec
    lda #1
    sbc BP_DC
    lda #0
    sbc BP_DC+1
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
    ; TODO
    ; Test byte under DC. If 0, find matching right bracket and set PC to that location.
    rts

RightBracketInstr:
    ; TODO
    ; Test byte under DC. If non-0, find matching left bracket and set PC to that location.
    rts

; Performs one instruction
; Sets overflow flag if past end, otherwise clears
Step:
    ldy #0
    lda (BP_PC),y
    bne +    ; if PC on null, do nothing
    rts

+   cmp #$b1
    bne ++
    jsr IncDCInstr
    bra +

++  cmp #$b3
    bne ++
    jsr DecDCInstr
    bra +

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
    bra +

++  cmp #$5b
    bne ++
    jsr LeftBracketInstr
    bra +

++  cmp #$5d
    bne +
    jsr RightBracketInstr

+   jsr NextPC
    rts

TEST_OutputInstr:
    jsr InitDC
    lda #65
    ldy #0
    sta (BP_DC),y
    jsr OutputInstr
    rts

TEST_InputInstr:
    lda #0
    sta $3000
    sta $3001
    sta $3002
    sta $3003

    ; TEST inputBytes starts with a null
    ; Result in $3000
    jsr InitDC
    jsr InitInput
    lda #$ff
    ldy #0
    sta (BP_DC),y

    lda #0
    sta inputBytes
    jsr InputInstr
    lda BP_inputC
    bne +     ; inputC hasn't moved
    lda (BP_DC),y
    cmp #$ff
    bne +     ; value under DC hasn't changed
    bra ++
+   lda #1
    sta $3000
++

    ; TEST inputBytes has one non-null value
    ; Result in $3001
    jsr InitDC
    jsr InitInput
    lda #$ff
    ldy #0
    sta (BP_DC),y

    lda #1
    sta inputBytes
    lda #0
    sta inputBytes+1
    jsr InputInstr
    lda BP_inputC
    ldx #1
    cmp #1
    bne +    ; (1) inputC has advanced to 1
    lda (BP_DC),y
    ldx #2
    cmp #1
    bne +    ; (2) value under DC was overwritten to 1
    jsr InputInstr
    lda BP_inputC
    ldx #3
    cmp #1
    bne +    ; (3) inputC has not advanced
    ldy #0
    lda (BP_DC),y
    ldx #4
    cmp #1
    bne +    ; (4) value under DC hasn't changed
    bra ++
+   stx $3001
++

    ; TEST inputBytes is four bytes long
    ; Result in $3002
    jsr InitDC
    jsr InitInput
    lda #$ff
    ldy #0
    sta (BP_DC),y

    lda #1
    sta inputBytes
    lda #3
    sta inputBytes+1
    lda #5
    sta inputBytes+2
    lda #7
    sta inputBytes+3
    lda #0
    sta inputBytes+4
    jsr InputInstr
    ldy #0
    lda (BP_DC),y
    ldx #1
    cmp #1
    bne +    ; (1) value under DC was overwritten to 1
    jsr InputInstr
    ldy #0
    lda (BP_DC),y
    ldx #2
    cmp #3
    bne +    ; (2) value under DC was overwritten to 3
    jsr InputInstr
    ldy #0
    lda (BP_DC),y
    ldx #3
    cmp #5
    bne +    ; (3) value under DC was overwritten to 5
    jsr InputInstr
    ldy #0
    lda (BP_DC),y
    ldx #4
    cmp #7
    bne +    ; (4) value under DC was overwritten to 7
    lda BP_inputC
    ldx #5
    cmp #4
    bne +    ; (5) inputC is now 4
    jsr InputInstr
    ldy #0
    lda (BP_DC),y
    ldx #6
    cmp #7
    bne +    ; (6) value under DC hasn't changed
    lda BP_inputC
    ldx #7
    cmp #4
    bne +    ; (7) inputC has not advanced
    bra ++
+   stx $3002
++

    ; TEST inputBytes region is full of non-nulls
    ; Result in $3003
    jsr InitDC
    jsr InitInput
    lda #$ff
    ldy #0
    sta (BP_DC),y

    lda #$bb
    sta inputBytes
    ldy #1
-   tya
    sta inputBytes,y
    iny
    bne -

    lda #0
    sta $ff
-   ldx #1
    lda $ff
    cmp BP_inputC
    bne +    ; (1) inputC advances for each InputInstr call
    jsr InputInstr
    inc $ff
    bne -
    jsr InputInstr
    ldx #2
    lda BP_inputC
    bne +    ; (2) inputC has not advanced
    ldy #0
    ldx #3
    lda (BP_DC),y
    cmp #$ff
    bne +    ; (3) value under DC is last read input
    bra ++
+   stx $3003
++

    rts

TEST_IncDCInstr:
    rts


; Perform user call: start
ActuallyStartBF:
    lda #$16
    tab

;    jsr Initialize
;-   jsr Step
;    bvc -

    jsr TEST_IncDCInstr

    lda #$00
    tab
    rts
