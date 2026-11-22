# How this book is written

We write the prose first. Each section says what Rubric does and why, and its examples are the contract: a section is done when its examples pass.

## A decision, in brief

We chose Zig to bootstrap the first compiler. It ships as a single archive, compiles to WebAssembly, and is retired once Rubric compiles itself. The alternative was Rust, which is stable but brings a whole toolchain.

The parser rejects a tab inside an indent, and the error names the column.

Each fork lives on its own git branch, and the I/O chapter comes later.
