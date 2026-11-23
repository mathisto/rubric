<!-- prose only -->
# True and false

By the end of this chapter, Rubric has a second type, Bool, with its two values `true` and `false`. Comparisons produce them, and `and`, `or` and `not` combine them. With two types comes the type checker: from here on, Rubric checks every line before it runs a single step of it.

Three decisions shape this chapter. They were made on 2026-11-22.

## <a id="decision.bool"></a>Decision: the second type is Bool

**Status:** accepted, 2026-11-22.

**Context.** A type checker only has work to do once there are two types. The question is which type comes next.

**Forces.** Bool is the smallest type there is, comparisons produce it without new syntax, and every later chapter needs it: choices, loops and tests all turn on true and false. Text is more useful for output, but brings escapes, Unicode and joining rules all at once. Decimal numbers would show the checker refusing to mix them with Ints, but bring rounding and printing rules early.

**Options.** Bool; Text; decimal numbers.

**Choice.** Bool.

**Consequences.** Text and decimal numbers get chapters of their own. Bool arrives without `if`, which waits for the chapter that decides how blocks are written, so that its syntax isn't fixed by accident.

## <a id="decision.logic-words"></a>Decision: logic is spelled in words

**Status:** accepted, 2026-11-22.

**Context.** Combining true and false needs three operations: both, either, and the opposite.

**Forces.** Words, as in Python and Ruby, read like the prose around them, which is Rubric's first goal. Symbols, as in C, Java and Rust, are familiar to most programmers and denser on the page.

**Options.** `and`, `or` and `not`; `&&`, `||` and `!`.

**Choice.** `and`, `or` and `not`.

**Consequences.** Typing a symbol from another language is a mistake, and the error says which word to write instead.

## <a id="decision.no-chaining"></a>Decision: comparisons don't chain

**Status:** accepted, 2026-11-22.

**Context.** On paper, `1 < 2 < 3` means both comparisons hold. In C, it compares the result of `1 < 2` with `3`.

**Forces.** Chaining as on paper, as Python does, reads naturally but is one more rule to learn, and surprises C programmers. C's reading, with static types, is a type error anyway. Refusing to chain, as Rust does, surprises nobody.

**Options.** An error; chaining as on paper; C's left-to-right reading.

**Choice.** An error. Write `1 < 2 and 2 < 3`.

**Consequences.** Every comparison stands alone, and a chain is caught before the program runs, with a message that says what to write.

## <a id="lexer.words"></a>Words

Five words have a meaning so far: `true`, `false`, `and`, `or` and `not`. A word is a run of lowercase letters.

```rubric example
> true
true
> false
false
```

Any other word is a mistake, for now. When names arrive in the next chapter, a word will be able to mean a value.

```rubric error
> yes
error L005: unknown word 'yes' (column 1)
```

A symbol that means logic in another language is a mistake too, and the error says what to write:

```rubric error
> !true
error L001: unexpected character '!'; write 'not' (column 1)
```

```rubric error
> true && false
error L001: unexpected character '&'; write 'and' (column 6)
```

```rubric error
> true || false
error L001: unexpected character '|'; write 'or' (column 6)
```

## <a id="eval.comparison"></a>Comparing

Six operators compare two values and answer with a Bool:

| Operator | Means |
| --- | --- |
| `==` | equal |
| `!=` | not equal |
| `<` | less than |
| `<=` | less than or equal |
| `>` | greater than |
| `>=` | greater than or equal |

```rubric example
> 1 == 1
true
> 1 != 2
true
> 2 <= 1
false
> 10 > 9
true
> 3 >= 3
true
```

Arithmetic comes before comparison, so both sides are worked out first:

```rubric example
> 1 + 2 == 3
true
> 2 * 3 < 7
true
```

Bools can be compared for equality too:

```rubric example
> true == true
true
> true != false
true
```

## <a id="parser.no-chaining"></a>One comparison at a time

A comparison can't follow another without parentheses. Equality counts as a comparison, so `1 < 2 == true` is a chain as well.

```rubric error
> 1 < 2 < 3
error P005: comparisons can't be chained; use 'and' (column 7)
```

```rubric error
> 1 < 2 == true
error P005: comparisons can't be chained; use 'and' (column 7)
```

Parentheses make the order explicit, and then it is allowed:

```rubric example
> (1 < 2) == true
true
```

## <a id="eval.logic"></a>And, or, not

`and` is true when both sides are. `or` is true when either side is. `not` turns true into false and false into true.

```rubric example
> true and false
false
> true or false
true
> not true
false
```

`not` comes after comparison, so `not 1 > 2` asks whether `1 > 2` is false. `and` comes before `or`, as multiplication comes before addition.

```rubric example
> not 1 > 2
true
> true or false and false
true
> (true or false) and false
false
> not (1 > 2) and 3 >= 3
true
```

`and` and `or` stop as soon as the answer is known. When the left side of `and` is false, or the left side of `or` is true, the right side never runs:

```rubric example
> false and 1 / 0 == 0
false
> true or 1 / 0 == 0
true
```

When the right side does run, its errors are real:

```rubric error
> true and 1 / 0 == 0
error R002: division by zero
```

## <a id="parser.precedence"></a>The order of everything

From the loosest to the tightest, the levels are:

| Level | Operators | Within the level |
| --- | --- | --- |
| Either | `or` | left to right |
| Both | `and` | left to right |
| Opposite | `not` | applies to what follows |
| Comparison | `==` `!=` `<` `<=` `>` `>=` | one at a time |
| Sum | `+` `-` | left to right |
| Product | `*` `/` `%` | left to right |
| Negation | `-` | applies to what follows |

Parentheses come before all of them.

```rubric example
> 1 + 2 * 3 == 7 and not false
true
```

## <a id="types.check"></a>The type checker

Every value now has a type: Int or Bool. Before Rubric runs a line, the type checker works out the type of every part of it, and refuses the line if any operator is given the wrong type. Nothing runs until the whole line checks.

So a line can fail to check even when running it would have stopped earlier for another reason. Here, the division by zero never happens, because the line is refused before it runs:

```rubric error
> 5 / 0 + true
error T001: '+' needs two Ints, not Int and Bool (column 7)
```

Type errors start with T, and point at the operator that can't accept what it was given.

## <a id="types.arithmetic"></a>Arithmetic needs Ints

`+`, `-`, `*`, `/` and `%` take two Ints. Negation takes one.

```rubric error
> 1 + true
error T001: '+' needs two Ints, not Int and Bool (column 3)
```

```rubric error
> -true
error T001: '-' needs an Int, not Bool (column 1)
```

## <a id="types.comparison"></a>Comparison needs matching types

`<`, `<=`, `>` and `>=` take two Ints. Bools have no order.

```rubric error
> true < false
error T002: '<' needs two Ints, not Bool and Bool (column 6)
```

`==` and `!=` take two values of the same type. An Int is never equal to a Bool, and asking is a mistake rather than a `false`.

```rubric error
> 1 == true
error T003: '==' needs two values of the same type, not Int and Bool (column 3)
```

## <a id="types.logic"></a>Logic needs Bools

`and`, `or` and `not` take Bools. Rubric never treats a number as true or false.

```rubric error
> 1 and true
error T004: 'and' needs two Bools, not Int and Bool (column 3)
```

```rubric error
> not 5
error T004: 'not' needs a Bool, not Int (column 1)
```

## What this chapter leaves for later

Rubric has two types and checks them, but a line still can't remember anything. The next chapter adds names for values. After that come blocks, and with them `if`.
