# The book's prose checks

Rubric is written as a book, and its prose is checked the way its code is. [Vale](https://vale.sh) runs these rules over every chapter; an error fails the gate.

Two styles apply. Deliverator is the shared house style for Matt's projects, pinned as a copy (see `Deliverator.PIN`). Rubric adds the book's own rules and raises several house rules to errors. The style guide in the Colophon explains the voice these rules protect. The rules only catch what a machine can see; the guide covers the rest.

## The voice

The book speaks as "we": Matt and Claude, writing it together. First-person singular is an error. "You" appears only when the reader is doing something.

## The rules

| Rule | Level | What it catches |
| --- | --- | --- |
| `Deliverator.FirstPerson` | error | `I`, `me`, `my` |
| `Deliverator.Marketing` | error | Marketing claims |
| `Deliverator.Filler` | error | Stock filler phrases |
| `Deliverator.Italics` | error | Italic emphasis in running prose |
| `Deliverator.Labels` | error | Link text that names no destination |
| `Rubric.Headings` | error | Title-case headings; names keep their capitals |
| `Rubric.Normative` | error | RFC capitals such as `MUST`; a plain sentence is the promise |
| `Rubric.Tics` | error | Words that mark prose as machine-written |
| `Rubric.HedgeStack` | error | Two hedges in a row |
| `Deliverator.American` | error | British spellings |
| `Rubric.Inflation` | warning | Inflated words with a plain replacement |
| `Rubric.Condescension` | warning | Telling the reader something is easy or obvious |
| `Rubric.Dashes` | warning | More than one em dash in a sentence |
| `Rubric.SentenceLength` | warning | Sentences over 35 words |
| `Rubric.Exclaim` | warning | Exclamation marks |
| `Rubric.Forks` | warning | "Branch" for a design alternative; that is a fork |
| `Deliverator.Hedges` | suggestion | Weak intensifiers |

Names live in `config/vocabularies/Rubric/accept.txt`. A name that may be capitalized inside a heading also goes in `Rubric/Headings.yml`.

## Testing the rules

`tools/prose-test.sh` proves each rule works. Every line of `tests/prose/bad.md` must trip the rule named for it in `tests/prose/expect.txt`, and `tests/prose/good.md` must be clean. A new rule arrives with a failing line and its expectation. The book's own gate lints the chapters and leaves these fixtures out.
