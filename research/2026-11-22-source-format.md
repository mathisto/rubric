# Source format: file names and code fences

Researched 2026-11-22, before the repo exists. The question: what file name and code-block convention lets every chapter render as ordinary GitHub-flavored Markdown on GitHub, with no setup, while the tangler still knows which code is Rubric?

## How GitHub decides what to render

We read the source rather than trust summaries.

- GitHub's renderer, [github/markup](https://github.com/github/markup/blob/master/lib/github/markup.rb), does not look at the extension directly. It asks [Linguist](https://github.com/github-linguist/linguist) which language the file is in, then renders it as Markdown only if that language is Markdown, MDX or Literate CoffeeScript ([markdown.rb](https://github.com/github/markup/blob/master/lib/github/markup/markdown.rb), lines 117 to 119).
- Linguist tries every suffix, longest first, and takes the first one it knows ([language.rb](https://github.com/github-linguist/linguist/blob/master/lib/linguist/language.rb), `find_by_extension`). `chapter.rubric.md` falls through to `.md` and renders. So does Agda's `.lagda.md`.
- Markdown is a prose language in Linguist, so `.md` files never count in the repo's language bar ([overrides.md](https://github.com/github-linguist/linguist/blob/master/docs/overrides.md)). A `.gitattributes` override cannot fix that until Rubric is a registered language.
- Registering a language needs real usage: at least 2,000 indexed files per extension, spread across many users ([CONTRIBUTING.md](https://github.com/github-linguist/linguist/blob/master/CONTRIBUTING.md)).

## The snafus

- **Literate CoffeeScript** has two extensions, `.litcoffee` first and `.coffee.md` later ([literate docs](https://github.com/jashkenas/coffeescript/blob/main/documentation/sections/literate.md)). Linguist registered both as a programming language, which would have stopped GitHub rendering them. GitHub patched its renderer with a special case naming the language. That exception is still in the code today.
- **R Markdown and Quarto** (`.rmd`, `.qmd`) are registered as their own language with no such exception, so GitHub shows them as raw source.
- **Literate Haskell** (`.lhs`) has two incompatible styles, Bird tracks and `\begin{code}`, and GHC's preprocessor breaks on Markdown `#` headings ([GHC #4836](https://mail.haskell.org/pipermail/ghc-tickets/2014-June/013129.html)). Linguist registers `.lhs` as a programming language, so it no longer renders as Markdown.
- **Agda** debated in 2014 whether `.lagda` should guess its format. It settled on one extension per format: `.lagda.tex`, `.lagda.md`, `.lagda.rst` and more ([Agda docs](https://agda.readthedocs.io/en/latest/tools/literate-programming.html)).
- **Jupytext** uses `.md` for two different Markdown dialects, and the wrong one fails silently.

The common thread: a literate format renders on GitHub only while Linguist treats it as plain Markdown. A language that later registers its own literate extension can lose its rendering, as CoffeeScript nearly did.

## What we tested

We sent sample fences through GitHub's Markdown API (`gh api markdown`, GFM mode):

| Fence opening | Result on GitHub |
| --- | --- |
| `rubric example` | Language `rubric`; `example` kept out of sight as metadata. Plain text, since GitHub has no Rubric grammar. |
| `python example` | Full Python highlighting; the extra word does not interfere. |
| `{.python #id}` (Pandoc style) | Broken: the language becomes `{.python`, and highlighting is lost. |

## Section IDs

Tested the same way. A Pandoc-style heading ID, `## Integer literals {#lexer.integers}`, shows the braces literally on GitHub. An HTML comment above the heading is invisible but gives no link target. An empty anchor inside the heading, `## <a id="lexer.integers"></a>Integer literals`, is invisible and linkable; GitHub prefixes the ID with `user-content-` and its page script resolves `#lexer.integers` links. Matt adopted this form for rule IDs on 2026-11-22.

## Tooling with a double extension

- Python's `Path.suffix` and Zig's `std.fs.path.extension` both return `.md` for `chapter.rubric.md` ([`pathlib`](https://docs.python.org/3/library/pathlib.html), [`path.zig`](https://github.com/ziglang/zig/blob/master/lib/std/fs/path.zig)). Code that wants `.rubric.md` must check for it explicitly.
- Git attributes and Vale globs match `*.rubric.md` literally, so a double extension works there.
- VS Code: a separate language id for `*.rubric.md` would likely lose the built-in Markdown preview. Agda's VS Code mode does this and ships its own grammar. Injecting a grammar into Markdown fences tagged `rubric` keeps the preview and works in any `.md` file ([fence injection example](https://github.com/mjbvz/vscode-fenced-code-block-grammar-injection-example)).
- GitHub Pages renders `.md` without front matter, so `chapter.rubric.md` becomes `chapter.rubric.html`. Only a plain `README.md` becomes a folder's index.

## Recommendation

Chapters are plain `.md` files in the book's folder. The fence tag, not the file name, says what is Rubric. This follows Idris 2, which treats Markdown files as literate source and compiles only fences tagged `idris` ([Idris 2 docs](https://idris2.readthedocs.io/en/stable/reference/literate.html)).

| Fence opening | Meaning |
| --- | --- |
| `rubric` | Code the tangler extracts into the implementation |
| `rubric example` | An example that must run and pass |
| `rubric error` | An example that must fail with the error shown |

Why this over `.rubric.md`:

- It renders everywhere that renders Markdown, and stays that way even if Rubric is registered with Linguist one day. Registering the fence name `rubric` gives GitHub highlighting without touching file rendering.
- `README.md` can be a real chapter (the Incipit) with no special case, and stays the repo's landing page and the Pages index.
- One extension, chosen once. No second extension added later, as CoffeeScript did.
- Editors keep their Markdown preview; a Rubric editor extension adds highlighting inside the fences.

The cost: on GitHub, Rubric code shows without color until the language has enough public use for Linguist. The book site highlights it from day one. A tangler rule that only `rubric` fences count keeps any other Markdown in the repo from being read as source.

Rejected: `.rubric.md`. It works today, but code must special-case it, editors lose the preview if it gets its own language id, and its rendering depends on Linguist never claiming it. Also rejected: a custom extension such as `.rbc`, which GitHub shows as raw text, and Pandoc attribute fences, which break on GitHub.
