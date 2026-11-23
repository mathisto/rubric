# Rubric

Rubric is a programming language, written as a book.

Each chapter says in plain prose what the language does. The examples in a chapter are its tests: they run on every commit, and when one stops passing, the build stops. The code that implements a chapter lives inside it, next to the prose that explains it. The book is the language's specification, its implementation and its history, all in one place.

This page is the first chapter, the Incipit. No other chapter exists yet. The book grows in public, one commit at a time.

## Why a book

Most languages keep three things apart: a specification, an implementation and the story of how they came to be. They drift. The specification says one thing, the compiler does another, and the reasons behind both end up scattered across old issue threads.

Rubric keeps them together. A rule written in prose has an example under it, the example runs, and the code that makes it pass sits a few lines away. When the prose and the code disagree, the build fails and someone has to decide which one is wrong.

The idea is old. Donald Knuth named it literate programming in 1984, and wrote TeX that way. What is new here is the order: the prose comes first, and the code is written to match it.

## How it is made

Every chapter goes through the same steps:

1. We write the chapter's prose and examples, and commit them. At this point the examples fail, because nothing implements them yet.
2. Matt reads the chapter and marks it up. It changes until he accepts it.
3. Claude writes the code that makes the examples pass, inside the chapter. Matt reviews it, and it is committed.
4. A tool pulls the code out of every chapter into a folder of ordinary Zig source. That folder is committed too, so anyone can browse the implementation on its own. The build regenerates it and fails if the two differ, so nobody can edit the generated code by hand.

"We" in this book means Matt Kelly and Claude, the AI model, working together. Matt steers: he designs the language and makes every choice. Claude is the tool that carries it out, in prose and in code. The Colophon, the closing appendix, describes the process in full.

## How to read it

Read it on GitHub, in order, starting here and continuing with [The book reads itself](book/code.md). Each chapter is an ordinary Markdown file and renders here as a page.

The line that opens a code block says what the block is:

| Block opens with | What it is |
| --- | --- |
| `zig file=src/lexer.zig` | Implementation code, and the file it belongs to |
| `zig slot=lexer.cases` | Implementation code that fills a slot an earlier chapter left open |
| `rubric example` | A Rubric program that must run and pass |
| `rubric error` | A Rubric program that must fail, with the error shown under it |

The implementation is written in Zig until Rubric can compile itself, so for now its blocks say `zig`. GitHub doesn't know Rubric yet, so Rubric programs show without color. The rendered edition, with search and a print view, is at [rubric.mattkelly.io](https://rubric.mattkelly.io/).

The history is part of the book. Each chapter arrives as its own commits, prose first, so the log shows what we promised before it shows what we built.

## Forks

Designing a language means making choices, and each choice closes a door. We want readers to be able to look through the doors we closed.

When a decision has a serious alternative, the book records it as a decision: what forced the choice, what we considered, what we chose and what it cost. Some alternatives get explored as forks, side branches built far enough to learn something real. Every fork ends with a written verdict, and the canon links to it. Every fork must express the same set of small reference programs, so the verdicts compare like with like.

Rejected ideas stay in the book. A list of them, and a list of what Rubric will never try to be, will grow alongside the chapters.

## Status

The first chapter, [The book reads itself](book/code.md), builds the extractor: the tool that pulls code out of the chapters into `gen`, and checks on every commit that the two agree. The language itself has no syntax yet, no interpreter and no examples. The tool that runs examples arrives with the first chapter that can run a Rubric program.

The bootstrap is written in Zig 0.17.1, pinned. Zig is the scaffolding, not the destination.
