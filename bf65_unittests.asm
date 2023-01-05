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
    jsr InitDC
    jsr InitInput

    lda #0
    sta $3000

    lda BP_DC
    ldx #1
    cmp #<dataRegion
    bne +   ; (1) DC starts at home (low)
    lda BP_DC+1
    ldx #2
    cmp #>dataRegion
    bne +   ; (2) DC starts at home (high)
    jsr IncDCInstr
    ldx #$81
    bvs +   ; ($81) overflow clear
    lda BP_DC
    ldx #3
    cmp #<(dataRegion+1)
    bne +   ; (3) After one incDC, DC is one ahead (low)
    lda BP_DC+1
    ldx #4
    cmp #>dataRegion
    bne +   ; (4) After one incDC, DC is one ahead (high)
    jsr IncDCInstr
    ldx #$82
    bvs +   ; ($82) overflow clear
    lda BP_DC
    ldx #5
    cmp #<(dataRegion+2)
    bne +   ; (5) After two incDC, DC is two ahead (low)
    ldx #6
    cmp BP_highestDC
    bne +   ; (6) DC == highestDC (low)
    lda BP_DC+1
    ldx #7
    cmp BP_highestDC+1
    bne +   ; (7) DC == highestDC (high)
    ldx #8
    lda dataRegion
    bne +   ; (8) First cell is 0
    ldx #9
    lda dataRegion+1
    bne +   ; (9) Second cell is 0

    ; TEST DC=0, highestDC=2, cells non-null
    lda #<dataRegion
    sta BP_DC
    lda #>dataRegion
    sta BP_DC+1
    lda #$ff
    ldy #0
    sta (BP_DC),y
    iny
    sta (BP_DC),y
    jsr IncDCInstr
    ldx #$84
    bvs +   ; ($84) overflow clear
    lda BP_DC
    ldx #$0c
    cmp #<(dataRegion+1)
    bne +   ; ($0c) After one incDC, DC is one ahead (low)
    lda BP_DC+1
    ldx #$0d
    cmp #>dataRegion
    bne +   ; ($0d) After one incDC, DC is one ahead (high)
    ldy #0
    lda (BP_DC),y
    ldx #$0e
    cmp #$ff
    bne +   ; ($0e) First cell still contains non-null

    lda #<dataRegionEnd
    sta BP_DC
    sta BP_highestDC
    lda #>dataRegionEnd
    sta BP_DC+1
    sta BP_highestDC+1
    jsr IncDCInstr
    ldx #$83
    bvc +   ; ($83) overflow set
    lda BP_DC
    ldx #$0a
    cmp #<dataRegionEnd
    bne +   ; ($0a) DC hasn't moved (low)
    lda BP_DC+1
    ldx #$0b
    cmp #>dataRegionEnd
    bne +   ; ($0b) DC hasn't moved (high)

    bra ++
+   stx $3000
++
    rts


TEST_DecDCInstr:
    jsr InitDC
    jsr InitInput

    lda #0
    sta $3000

    jsr DecDCInstr
    ldx #$01
    bvc +   ; (1) Dec at start overflows
    lda BP_DC
    ldx #$02
    cmp #<dataRegion
    bne +   ; (2) Dec at start does not move DC (low)
    lda BP_DC+1
    ldx #$03
    cmp #>dataRegion
    bne +   ; (3) Dec at start does not move DC (low)
    lda #<(dataRegion+3)
    sta BP_DC
    lda #>(dataRegion+3)
    sta BP_DC+1
    jsr DecDCInstr
    ldx #$04
    bvs +   ; (4) Dec at non-start does not overflow
    lda BP_DC
    ldx #$05
    cmp #<(dataRegion+2)
    bne +   ; (5) New DC is one less (low)
    lda BP_DC+1
    ldx #$06
    cmp #>(dataRegion+2)
    bne +   ; (6) New DC is one less (low)

    bra ++
+   stx $3000
++
    rts


TEST_IncDataInstr:
    jsr InitDC
    jsr InitInput
    ldx #0
    stx $3000

    ldy #0
    ldx #$01
    lda (BP_DC),y
    bne +   ; (1) First cell starts 0
    jsr IncDataInstr
    ldy #0
    lda (BP_DC),y
    ldx #$02
    cmp #$01
    bne +   ; (2) Inc changes first cell to 1
    lda #$ff
    ldy #0
    sta (BP_DC),y
    jsr IncDataInstr
    ldy #0
    ldx #$03
    lda (BP_DC),y
    bne +   ; (3) Inc after $ff wraps to 0

    bra ++
+   stx $3000
++
    rts


TEST_DecDataInstr:
    jsr InitDC
    jsr InitInput
    ldx #0
    stx $3000

    lda #$02
    ldy #0
    sta (BP_DC),y
    jsr DecDataInstr
    ldy #0
    lda (BP_DC),y
    ldx #$01
    cmp #$01
    bne +   ; (1) Dec changes first cell to 1
    lda #$0
    ldy #0
    sta (BP_DC),y
    jsr DecDataInstr
    ldy #0
    ldx #$02
    lda (BP_DC),y
    cmp #$ff
    bne +   ; (2) Dec after $00 wraps to $ff

    bra ++
+   stx $3000
++
    rts


TEST_LoadInstr:
    jsr InitDC
    jsr InitInput
    ldx #0
    stx $3000

    ; Copy a simple BASIC program to memory
    ldy #(TEST_LoadInstr_BASIC_end-TEST_LoadInstr_BASIC)
-   lda TEST_LoadInstr_BASIC,y
    sta basicStart,y
    dey
    bne -

    ; Set PC to first char on first line
    lda #<(basicStart + 4)
    sta BP_PC
    lda #>(basicStart + 4)
    sta BP_PC+1

    jsr LoadInstr
    ldx #$01
    cmp #$5b
    bne +   ; (1) PC on a left bracket ($5b)
    lda #$41
    sta basicStart + 4
    jsr LoadInstr
    ldx #$02
    cmp #$ff
    bne +   ; (2) PC on the letter A
    lda #$00
    sta basicStart + 4
    ldx #$03
    jsr LoadInstr
    bne +   ; (3) PC on null
    bra ++
+   stx $3000
++

    lda #$00
    sta basicStart+4

    rts

TEST_LoadInstr_BASIC:
!word $2007
!word $000a
!byte $5b, $00
!word $200d
!word $0014
!byte $80, $00
!byte $00, $00
TEST_LoadInstr_BASIC_end = *


TEST_NextPC:
    jsr InitDC
    jsr InitInput
    ldx #0
    stx $3000

    ; Copy a simple BASIC program to memory
    ldy #(TEST_NextPC_BASIC_end-TEST_NextPC_BASIC)
-   lda TEST_NextPC_BASIC,y
    sta basicStart,y
    dey
    bne -

    lda #<(basicStart + 4)
    sta BP_PC
    lda #>(basicStart + 4)
    sta BP_PC+1

    ; TEST finds all BF chars, skips non-BF chars
    ldy #0
    lda (BP_PC),y
    ldx #$01
    cmp #$b1
    bne +
    jsr NextPC
    ldx #$71
    bvs +
    ldy #0
    lda (BP_PC),y
    ldx #$02
    cmp #$b3
    bne +
    jsr NextPC
    ldx #$72
    bvs +
    ldy #0
    lda (BP_PC),y
    ldx #$03
    cmp #$aa
    bne +
    jsr NextPC
    ldx #$73
    bvs +
    ldy #0
    lda (BP_PC),y
    ldx #$04
    cmp #$ab
    bne +

    bra ++
+   stx $3000
    rts
++

    jsr NextPC
    ldx #$81
    bvs +
    ldy #0
    lda (BP_PC),y
    ldx #$05
    cmp #$2e
    bne +
    jsr NextPC
    ldx #$82
    bvs +
    ldy #0
    lda (BP_PC),y
    ldx #$06
    cmp #$2c
    bne +
    jsr NextPC
    ldx #$83
    bvs +
    ldy #0
    lda (BP_PC),y
    ldx #$07
    cmp #$5b
    bne +
    jsr NextPC
    ldx #$84
    bvs +
    ldy #0
    lda (BP_PC),y
    ldx #$08
    cmp #$5d
    bne +
    jsr NextPC
    ldx #$85
    bvs +
    ldy #0
    lda (BP_PC),y
    ldx #$09
    cmp #$b1
    bne +
    jsr NextPC
    ldx #$86
    bvs +
    ldy #0
    lda (BP_PC),y
    ldx #$0a
    cmp #$b3
    bne +

    jsr NextPC
    ldx #$87
    bvs +
    ldy #0
    ldx #$0b
    lda (BP_PC),y
    bne +

    jsr NextPC
    ldx #$88
    bvc +

    bra ++
+   stx $3000
++

    rts

TEST_NextPC_BASIC:
!word $2001+(BASIC_L2-*)
!word $000a
!byte $b1,$b3,$aa,$ab,$2e,$2c,$5b,$5d,0
BASIC_L2:
!word $2001+(BASIC_L3-*)
!word $0014
!byte $41,$41,$41,$41,0
BASIC_L3:
!word $2001+(BASIC_L3-*)
!word $0014
!byte $b1,$41,$41,$41,$b3,$41,0
BASIC_L4:
!byte 0,0
TEST_NextPC_BASIC_end = *
