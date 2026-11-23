# Colophon

A colophon closes a book and says how it was made. This one covers who writes Rubric, how a chapter moves from idea to working code, and the voice every chapter is written in.

## Who writes it

Rubric is a collaboration between Matt Kelly and Claude, the AI model. Matt steers, designs the language and makes every choice. Claude is the tool that carries those choices out, in prose and in code. "We" in this book means the two of us, working together.

Commits carry no AI credit lines. This page is where the book says how it is made, once and plainly.

## How a chapter is made

1. **Prose first.** We write the chapter's prose and its examples, and commit them. The examples fail, because nothing implements them yet.
2. **Markup.** Matt reads the chapter and marks it up. It changes until Matt accepts it.
3. **Code.** Claude writes the code that makes the examples pass, inside the chapter, in blocks that name their language and the file or slot they belong to. Matt reviews it, and it is committed once. Nobody regenerates it later: two runs from the same prose give different code, so the reviewed version is the one that stays.
4. **Extraction.** A tool pulls the code out of every chapter into a folder of ordinary Zig source, and each file names the chapter and line it came from. That folder is committed. The build regenerates it and fails if the two differ.

## The gate

Every commit passes the same checks, or it does not land:

- Every code block names its language. Implementation blocks also name the `file=` or `slot=` they belong to. Rubric programs are `rubric example`, `rubric error` or `rubric setup`.
- Every `rubric example` runs and passes. Every `rubric error` runs and fails with exactly the error shown. No example passes without running.
- Every rule has at least one example, or a test named for it. A rule is a section whose heading carries an ID, written as an anchor that readers never see: `## <a id="lexer.integers"></a>Integer literals`. A decision's ID starts with `decision.`; it records a choice, so it needs no check, only an ID used once.
- No two slots share a name, and every slot a block fills exists.
- The program as it stands at the end of each chapter builds and passes that chapter's examples.
- The code is formatted exactly as `zig fmt` formats it.
- The prose passes the style checks described below.

The bootstrap compiler is Zig 0.17.1, pinned by version and hash. Prose is checked by Vale 3.28.1.

## The voice

We write the way a good teacher talks to a colleague: plainly, specifically and without performance. The reader is smart and busy.

### Who is speaking

- The book speaks as "we". First-person singular never appears.
- "You" means the reader, and appears only when the reader is doing something: running an example, reading code, making a choice.
- Matt and Claude are named when it matters who did something. Most of the time it doesn't.

### What a sentence promises

- A plain statement is a rule. "An integer literal is a run of decimal digits" is a promise, and an example below it proves it. We don't write `MUST` or `SHALL`.
- Every rule earns an example. If we can't show it, we haven't decided it.
- When something is undecided, we say so, and say what would decide it. We don't hedge twice: `may` is enough, `may possibly` is not.
- When a choice is left to implementations, we say so outright, as the Go spec does. Vague is not the same as free.

### Order

- Show, then name. An example comes before the term that describes it, when the reader can follow it without the term.
- One idea per paragraph. A paragraph that needs a second heading gets one.
- Every chapter starts by saying what the reader will be able to do at the end of it.

### Words

- Plain words over grand ones: `use`, not `leverage`; `start`, not `commence`.
- No words that tell the reader how to feel about the material: not `simply`, `obviously`, `just` or `easy`. If it is easy, the reader will notice.
- Name things once and keep the name. A fork is always a fork, never a `branch` or a `variant`.
- American spelling. Sentence case in headings; names keep their capitals.
- One dash per sentence at most, few exclamation marks and few italics. Sentences stay under 35 words.

### Decisions and forks

A decision section records a choice with a real alternative. It is frozen once accepted; a later change is a new decision that points back to it. Its parts, in order:

- **Status:** proposed, accepted, rejected or superseded, with a date.
- **Context:** what forced the question.
- **Forces:** what pulls each way.
- **Options:** the serious ones, briefly.
- **Choice:** what we chose, in one sentence.
- **Consequences:** what it costs and what it makes possible, with links to the rules it shapes.
- **Forks:** links to any fork that explored an option.

A fork verdict closes a fork. It states the question the fork asked, what we built, what the reference programs showed, the verdict, and anything the fork taught that the canon kept.

## What is checked and what is judged

Vale enforces the mechanical part of this guide: first person, `MUST` capitals, stock phrases, hedge stacks, inflated words, condescension, dashes, long sentences, exclamation marks, the word "branch", American spelling, heading case and italics. The full rule table is in `styles/README.md`.

The rest is judged by a reader: whether an example comes before its term, whether a paragraph holds one idea, whether a rule is true. A clean lint run is not a review.
