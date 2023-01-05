# bf65, a Brainf\*ck interprefer for the MEGA65

bf65 is an interpreter for the
[Brainf\*ck](https://en.wikipedia.org/wiki/Brainfuck) programming language, a
minimalist experimental Turing-complete programming language with a funny name.
It is written for the [MEGA65](https://mega65.org/) personal computer, in 45GS02
assembly language.

Download the `bf65.d81` disk image for a ready-to-run interpreter and example
programs.

## What is Brainf\*ck?

A BF program consists of parameter-less instructions that manipulate
an array of bytes in memory, read input, and write output. A data cursor
points to a location in the array, and the instructions either manipulate the
byte in that location or move the data cursor. The sole control structure is
a pair of matching brackets capable of conditional execution and looping.

There are eight possible instructions, each represented by a single
character.

- `>` Increment the data pointer.
- `<` Decrement the data pointer.
- `-` Increment the byte at the data pointer.
- `*` Decrement the byte at the data pointer.
- `.` Output the byte at the data pointer.
- `,` Accept one byte of input, and store it at the data pointer.
- `[` If the byte at the data pointer is zero, jump to the instruction after the matching `]`.
- `]` If the byte at the data pointer is non-zero, jump to the instruction after the matching `[`.

Brackets are always in matched pairs, and can nest. A BF program with
unmatched brackets is invalid and will not execute.

The following program calculates 2 + 5, leaving the result in the first cell of
the data array:

```brainfuck
++           set c0 to 2
> +++++      set c1 to 5
[ < + > - ]  loop: adding 1 to c0 and subtracting 1 from c1 until c1 is 0
```

## How do I write a BF65 program?

With BF65, you write BF programs using the MEGA65 BASIC line editor. Any
numbered line that begins with a BF character is recognized as a line of BF
code. Any other BASIC line is ignored in full, and any character on a line of BF code
that isn't a BF character is also ignored. This allows you to combine BASIC
commands and BF code in the same listing, like so:

```basic
10 bank 0:bload "bf65":sys $1800:end
20 rem this program adds 2 and 5. see $8800 for the answer.
30 ++           set c0 to 2
40 > +++++      set c1 to 5
50 [ < + > - ]  loop: adding 1 to c0 and subtracting 1 from c1 until c1 is 0
```

The first line (line 10) consists of BASIC commands to load BF65, run it,
then end the program. You can execute this program with
the RUN command.

```basic
RUN
```

BF65 ignores lines 10 and 20, and finds BF instructions
starting on line 30. BF65 ignores the commentary on lines 30-50 because they
do not contain BF instructions.

Note that this is not a combination of BASIC and BF in a single language.
The BF interpreter runs when you call SYS $1800, and it starts from the
beginning of the listing and skips all of the non-BF characters. When you
type RUN, the BASIC interpreter assumes it will only see BASIC commands up to
the END statement. (It would be cool to have BF run inline with BASIC, but
that's not what BF65 does.)

The `sys $1800` command runs BF65, and returns to BASIC when the BF program
completes (if it completes). If you like, you can have additional BASIC commands in
the program, such as to load input data or visualize the data region after BF65
completes. Just be sure that BASIC flow of control does not reach a line of BF
code, or it will abort with a syntax error.

## Input and output

A BF program can read a byte of input with the input (`,`) instruction. With
this implementation, input is read from memory, up to 256 bytes starting at
address $8500. The byte before the first null byte ($00), or the last byte of
the region, whichever comes first, is considered the last byte of the input
stream. Attempts to read beyond the last byte will have no effect. (According
to Wikipedia, this is the de facto standard handling of EOF in BF
implementations.)

If you have input data in a SEQ file that you want processed,
use a BLOAD statement in the BASIC portion to load it to $8500.

The output (`.`) instruction writes a character to the screen. There is no
limit to output length, though the screen will scroll just like other
terminal output.

Some BF programs leave their result in the data array. When execution is complete, you can examine the final state of the data
array using the MEGA65 MONITOR. The data region starts at $8800.

```basic
READY.
MONITOR

...
M8800
```

## Standards compliance

As mentioned, the input instruction `,` signifies the end of the input by doing
nothing. The data cell under the cursor does not change for all subsequent
input commands. In input memory, a null byte or the the end of the input region
is considered one byte beyond the end of the file. It is not possible to read a
null input value. (This deviates from implementations that detect EOF as a
condition and not a value in the input stream.)

The data cursor manipulated by the `<` and `>` instructions exits the program
with an error message if the cursor goes outside the data range. The data range
extends from $8800 to $ffff (with the ROM and I/O registers banked out of those
addresses), providing the standard 30 Kb BF array size.

The data increment and decrement instructions `+` and `-` modify the byte value
under the data cursor. The value wraps around at each end of the byte value
range, so calling `+` when the cell contains 255 updates it to 0. This happens
silently without error.

All output (including error messages) uses the kernel's terminal output stream.
You can redirect this output to a file or printer using the CMD command.

## Building BF65

`bf65.asm` is written for the ACME assembler. Assemble it to `bf65.prg` with
this command:

```shell
acme bf65.asm
```

This PRG file uses a load address of $1800. It does not provide its own BASIC
loader. Instead, it is meant to be loaded and invoked by a BF program listing
using BASIC commands.

I have included some example program listings in [petcat](https://vice-emu.sourceforge.io/vice_16.html) format, as the
files ending in `.bas`. petcat is a tool included with the VICE suite of
Commoodore emulators. To convert a `.bas` file to a MEGA65 PRG file:

```shell
petcat -w65 -o program.prg -- program.bas
```

The `bf65_unittests.asm` file contains a bunch of sloppy test code I wrote
along the way. It may or may not be useful to verify future changes.

## Porting BF65

I wrote this for the MEGA65 as an exercise. It uses almost no
MEGA65-specific features and could be ported to other 6502-style 8-bit
machines. Only the following aspects are specific to the MEGA65:

- It uses the 45GS02 relocatable base page register to use $1600 as the base
  page.
- The BASIC start address is assumed to be $2001.
- MEGA65 BASIC has `<<` and `>>` operators that tokenize differently from the
  `<` and `>` operators. The lexer accommodates this, and may or may not need
  adjustment for other platforms.
- Memory ranges are hard-coded as symbols at the top of the source file.
- It uses a MEGA65-specific ROM routine to print the error messages. This could
  be easily rewritten as a local routine using the target system's character
  out routine.

If you port bf65 to another machine, or really do anything fun with it at all,
please let me know!

## Brainf\*ck resources

- [http://brainfuck.org/tests.b]
- [http://brainfuck.org/]
- [http://www.bf.doleczek.pl/]
- [https://curlie.org/Computers/Programming/Languages/Brainfuck]
