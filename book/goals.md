# What Rubric is for

By the end of this chapter, you will know what Rubric is trying to be, what it refuses to be, and which programs every version of it must be able to write. There is no code here. Every later chapter makes trade-offs, and this chapter fixes the scale they are weighed on.

Three decisions come first, all made on 2026-11-22. After them come the goals and non-goals, and the reference programs. Those are proposals until Matt accepts them, and their status says so.

## <a id="decision.purpose"></a>Decision: a general-purpose language

**Status:** accepted, 2026-11-22.

**Context.** Rubric replaces Sienna, Matt's earlier language. Sienna runs Campo, the web server behind Matt's sites, and Glowdeep, a text adventure for many players. Whatever Rubric is for decides how much it has to carry.

**Forces.**

- A teaching language can stay small and spend everything on clarity, as Hedy and Pyret do.
- A scripting language can start fast and lean on its host, as Lua does.
- A general-purpose language needs the most: speed, concurrency, a standard library and a compiler. In return, it can replace Sienna.

**Options.** General-purpose; a teaching language; a scripting language.

**Choice.** General-purpose: a language for real programs, which will one day run Campo and Glowdeep.

**Consequences.**

- Speed, concurrency and a standard library all arrive eventually, each in its own part of the book.
- The early chapters still stay small, because the book adds one feature at a time.
- From teaching languages we keep what matters most to a reader: plain syntax and error messages that say what to do next.

## <a id="decision.types"></a>Decision: static types, mostly inferred

**Status:** accepted, 2026-11-22.

**Context.** Every value has a type. The question is when the language checks it: before the program runs, while it runs, or only where the programmer asks.

**Forces.**

- Checking before the program runs catches mistakes early, documents the code, and lets a compiler produce fast code. Sienna has a type checker of its own.
- Written-out types are noise when the reader can see the type anyway. Inference removes most of them.
- Adding static types to a dynamic language later is notoriously hard. Python's type hints and TypeScript both took years, and neither is complete.
- Dynamic types would let the first examples run sooner.

**Options.** Static types with inference; dynamic types; gradual types, dynamic by default with optional checked annotations.

**Choice.** Static types, mostly inferred. Rubric checks every program before running it.

**Consequences.**

- The interpreter gets a type checker from the first chapter that has more than one type.
- Type errors are part of the language, so they appear in the book as `rubric error` examples with their exact messages.
- How far inference reaches, and where types must be written, is decided when functions arrive.

## <a id="decision.execution"></a>Decision: an interpreter first

**Status:** accepted, 2026-11-22.

**Context.** The bootstrap is written in Zig. Examples are the book's tests, so the sooner a Rubric program can run, the sooner the book can check what it says.

**Forces.**

- An interpreter that walks the program's syntax tree is the shortest path from prose to a passing example.
- A compiler, from the start, avoids writing an interpreter that is later replaced. Sienna took this path.
- A bytecode virtual machine sits between the two: faster than walking a tree, more work, and a natural fit for running Rubric in a web browser later.

**Options.** A tree-walking interpreter first; a compiler from the start; a bytecode virtual machine.

**Choice.** A tree-walking interpreter in Zig first. A compiler comes in a later part of the book.

**Consequences.**

- The interpreter is scaffolding, like Zig and mdBook.
- When the compiler arrives, every example in the book becomes its test. The compiler must agree with the interpreter on all of them, so the book doubles as a conformance suite.
- A bytecode machine stays open as a fork, for the day the book wants to run Rubric in the browser.

**Forks.** None yet.

## Goals

**Status:** proposed, for Matt's markup.

1. **Readable.** Rubric code should read as plainly as the prose around it. When a construct needs a paragraph to explain, we look for a simpler construct.
2. **Checked before it runs.** A program that type-checks has no type errors at run time, and no value is ever missing without the type saying so.
3. **Errors that teach.** Every error message says what went wrong, where, and what to do next. Each one appears in the book as an example, so its wording is tested.
4. **Small enough to hold.** A working programmer should be able to keep the whole language in mind. A feature earns its place by appearing in a reference program.
5. **Fast enough for real work.** Campo and Glowdeep, written in Rubric, should be at least as fast as they are in Sienna.
6. **Explained, every part.** Every feature arrives with prose, examples and, when there was a real alternative, a decision. Nothing in the language is there without a written reason.

## Non-goals

**Status:** proposed, for Matt's markup.

Rubric will not try to be:

- **A teaching language first.** It keeps their best habits, but real programs come first.
- **A systems language for every machine.** Kernels, microcontrollers and hard real-time work need control that would cost Rubric its readability.
- **Compatible with another language.** Rubric borrows ideas freely, but no syntax is kept for the sake of familiarity, and no other language's code runs unchanged.
- **Terse.** A shorter program is not a better one. When brevity and clarity disagree, clarity wins.
- **Surprising.** No implicit conversions between types, and no behavior that depends on what the compiler happens to do.

## Reference programs

**Status:** proposed, for Matt's markup.

These programs are the yardstick. Every version of Rubric, the canon and every fork, must be able to write all of them, and every fork's verdict cites what they showed. They are small, but each is a program someone would want, because a benchmark of toy tasks drifts into testing toys. The 7GUIs project compared GUI toolkits this way, and its author later found some of its tasks artificial.

| Program | What it does | What it exercises |
| --- | --- | --- |
| Greeting | Greets the name it is given, or the world | Arguments, strings, output |
| Word count | Reads a text file and prints its ten most common words | Files, maps, sorting, string splitting |
| Ledger | Applies deposits and withdrawals to accounts, refusing overdrafts | Records, invariants, errors as values |
| Calculator | Reads arithmetic like `(1 + 2) * 3` and prints the result | Variants, pattern matching, recursion |
| Rooms | Walks a small map of connected rooms from typed commands | Graphs, parsing commands, loops: a seed of Glowdeep |
| Queens | Prints every way to place eight queens safely on a chessboard | Arrays, recursion, speed |
| Workers | Fetches several pages at once and reports their sizes | Concurrency, waiting, failure |
| Server | Answers web requests for a page and a status route | Sockets, a standard library: a seed of Campo |

Each program will live in its own folder with the output it must produce, so that it is a test as well as a measure. The first ones appear as soon as Rubric can run them.

## Questions for later chapters

These matter as much as anything above, and each gets its own decision when the chapter that needs it arrives:

- **Memory.** Garbage collection, reference counting or ownership.
- **Errors.** How a function reports failure: a result value, exceptions, or something else.
- **Concurrency.** Threads, tasks, channels, or a mix.
- **Modules.** How code is split into files and shared.
- **Syntax.** Starting with how a block begins and ends.
