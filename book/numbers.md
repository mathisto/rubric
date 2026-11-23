# Whole numbers

By the end of this chapter, Rubric runs its first programs. They are small: whole numbers, and arithmetic on them. But every example below runs on every commit, and from here on the book checks what it says about the language, not only about itself.

Four decisions shape this chapter. They were made on 2026-11-22, and each one shows up in every chapter after it.

## <a id="decision.transcripts"></a>Decision: examples are transcripts

**Status:** accepted, 2026-11-22.

**Context.** An example has to show the reader what Rubric does, and give the gate something exact to check.

**Forces.** A transcript, like a session at a terminal, shows each result next to the line that produced it, and needs no printing or comment syntax. Assertions such as `1 + 2 == 3` are compact, but need true and false before anything else, and show no results. A program followed by its output suits long programs and is heavy for one-line facts.

**Options.** Transcripts; assertions; a program and its output.

**Choice.** Transcripts. Python's doctest and Elixir's interactive shell work the same way.

**Consequences.** Examples read the same on GitHub and on the website. Error examples look like the rest. Longer programs, such as the reference programs, will need the program-and-output form as well, decided when they arrive.

## <a id="decision.integers"></a>Decision: 64-bit integers that refuse to overflow

**Status:** accepted, 2026-11-22.

**Context.** A whole number needs a size, and arithmetic can produce a result too big for it.

**Forces.** Sixty-four bits is the size the machine does fastest and the size real programs need. Integers that grow without limit, as in Python, never overflow but make every operation slower. Wrapping around, as in C and Java, is fast and is the classic silent bug. Refusing, as Swift does, is safe and costs a check.

**Options.** 64-bit, overflow is an error; unlimited size; 64-bit, wrapping.

**Choice.** 64-bit signed integers, and a result that doesn't fit is an error.

**Consequences.** Rubric never quietly gives a wrong number. A program that needs larger numbers will need a separate type, decided if one ever does.

## <a id="decision.division"></a>Decision: division rounds down

**Status:** accepted, 2026-11-22.

**Context.** When one integer doesn't divide another evenly, `-7 / 2` has two reasonable answers: `-3`, rounding toward zero, or `-4`, rounding down.

**Forces.** Rounding toward zero is what C, Java, Rust, Go and Swift do, so most programmers expect it. Rounding down keeps arithmetic regular: `a == (a / b) * b + a % b` always holds, and the remainder has the sign of the divisor, so `x % 2` is always `0` or `1`. Python, Ruby and Haskell round down.

**Options.** Round down; round toward zero; no `/` on integers, with division spelled out by name.

**Choice.** Round down. `%` gives the matching remainder.

**Consequences.** A reader who expects C's answer will meet a different one on negative numbers. The examples below show it plainly, and the remainder is never negative when the divisor is positive.

## <a id="decision.errors"></a>Decision: errors are coded, one line each

**Status:** accepted, 2026-11-22.

**Context.** Every mistake Rubric can report is part of the language, and appears in this book with its exact wording.

**Forces.** A code makes an error easy to search for and gives it a home in the book. A bare sentence is friendlier at first glance and harder to look up. Messages that draw the line of code with a caret under the problem, as Elm and Rust do, are the clearest for real programs and long for one-line examples.

**Options.** A code and one line; a plain sentence; several lines with the code drawn.

**Choice.** A code and one line, as the section on errors below describes. The drawn form may come later, for whole programs.

**Consequences.** Every error has a code that never changes meaning. The first letter says which stage found it.

## <a id="examples.transcript"></a>How an example reads

An example is a transcript. A line that starts with `>` and a space is typed in; the line after it is Rubric's answer.

```rubric example
> 1 + 2
3
> 6 * 7
42
```

Each typed line gets one answer, and the answer must match exactly, character for character. A typed line can't continue onto the next line yet.

A block labeled `rubric example` must not contain an error. A block labeled `rubric error` is the opposite: its last answer must be an error. Lines before the last may set the scene, and must answer without errors.

```rubric error
> 10 - 3
7
> 10 / 0
error R002: division by zero
```

The gate runs every example and every error in the book on every commit. An example that doesn't run, or answers differently, fails the commit.

## <a id="errors.format"></a>How an error reads

An error is one line: the word `error`, a code, a colon, and a sentence that says what went wrong.

```rubric error
> 2 $ 3
error L001: unexpected character '$' (column 3)
```

The code is a letter and three digits. The letter names the stage of Rubric that found the mistake:

| Letter | Stage | Found |
| --- | --- | --- |
| L | Lexer | Before reading the structure: a character or number that can't be read |
| P | Parser | In the structure: a missing number, an unclosed parenthesis |
| R | Running | While computing: a result too big, a division by zero |

The letter T is kept for type errors, which arrive with the second type. When the mistake is in what was typed, the message ends with the column where it starts, counting from 1 at the first character after `> `.

## <a id="lexer.integers"></a>Integer literals

A whole number is written as decimal digits. An underscore may sit between two digits, to group them for the reader, and changes nothing.

```rubric example
> 42
42
> 1_000_000
1000000
```

An underscore that doesn't sit between two digits is a mistake:

```rubric error
> 1__000
error L003: an underscore must sit between two digits (column 2)
```

```rubric error
> 1000_
error L003: an underscore must sit between two digits (column 5)
```

A number may not start with `0`, unless it is `0` itself. In C, `010` means eight, so a leading zero would surprise someone either way.

```rubric example
> 0
0
```

```rubric error
> 007
error L002: a number may not start with 0 (column 1)
```

A literal must fit in an Int. The largest is 9,223,372,036,854,775,807:

```rubric example
> 9_223_372_036_854_775_807
9223372036854775807
```

```rubric error
> 9_223_372_036_854_775_808
error L004: 9223372036854775808 does not fit in an Int (column 1)
```

The smallest Int, -9,223,372,036,854,775,808, can't be written as a literal, because its digits alone are too big before the minus sign applies. Rust has the same wrinkle and works around it. For now we don't: write it as `-9_223_372_036_854_775_807 - 1`.

## <a id="lexer.tokens"></a>Operators and spaces

Arithmetic uses `+`, `-`, `*`, `/` and `%`, and parentheses to group. Spaces between them are optional and change nothing.

```rubric example
> 1+2
3
> 1 +    2
3
```

Any other character is an error, and the message names it:

```rubric error
> 3 # 4
error L001: unexpected character '#' (column 3)
```

## <a id="parser.arithmetic"></a>Order of operations

Multiplication, division and remainder come before addition and subtraction. Operators at the same level work from left to right. Parentheses come first.

```rubric example
> 1 + 2 * 3
7
> (1 + 2) * 3
9
> 10 - 4 - 3
3
> 100 / 10 / 5
2
```

A minus sign before a number or a parenthesis negates it, and comes before everything else:

```rubric example
> -5
-5
> 2 * -3
-6
> -(2 + 3)
-5
> - -4
4
```

Four mistakes in structure are errors:

```rubric error
> 1 +
error P001: expected a number after '+' (column 4)
```

```rubric error
> (1 + 2
error P002: this '(' is never closed (column 1)
```

```rubric error
> 1 2
error P003: expected an operator before 2 (column 3)
```

```rubric error
> 1 + 2)
error P004: this ')' has no '(' to close (column 6)
```

## <a id="eval.arithmetic"></a>Adding, subtracting and multiplying

Addition, subtraction and multiplication give the exact answer whenever it fits in an Int:

```rubric example
> 12 + 30
42
> 3 - 10
-7
> -6 * -7
42
```

When it doesn't fit, the answer is an error, never a number that wrapped around. The message shows the numbers involved:

```rubric error
> 9_223_372_036_854_775_807 + 1
error R001: 9223372036854775807 + 1 does not fit in an Int
```

```rubric error
> -9_223_372_036_854_775_807 - 2
error R001: -9223372036854775807 - 2 does not fit in an Int
```

```rubric error
> 3_037_000_500 * 3_037_000_500
error R001: 3037000500 * 3037000500 does not fit in an Int
```

## <a id="eval.division"></a>Dividing

Division rounds down, and `%` gives the remainder that goes with it:

```rubric example
> 7 / 2
3
> 7 % 2
1
> -7 / 2
-4
> -7 % 2
1
> 7 / -2
-4
> 7 % -2
-1
> -7 / -2
3
> -7 % -2
-1
```

In every case, the quotient times the divisor, plus the remainder, gives back the number we started with. For `-7 / 2`, that is `-4 * 2 + 1`.

Dividing by zero is an error, for `/` and `%` alike:

```rubric error
> 5 / 0
error R002: division by zero
```

```rubric error
> 5 % 0
error R002: division by zero
```

One division overflows: the smallest Int divided by `-1`, whose answer is one more than the largest Int.

```rubric error
> (-9_223_372_036_854_775_807 - 1) / -1
error R001: -9223372036854775808 / -1 does not fit in an Int
```

## What this chapter leaves for later

The code for this chapter comes next: a lexer, a parser and an evaluator in Zig, and the runner that plays every transcript in the book. After that, Rubric needs a second type, and with it a type checker, and names for values. Those are the next chapters.
