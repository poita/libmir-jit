# libmir-jit

[![CI](https://github.com/Poita/libmir-jit/actions/workflows/ci.yml/badge.svg)](https://github.com/Poita/libmir-jit/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/Poita/libmir-jit/branch/master/graph/badge.svg)](https://codecov.io/gh/Poita/libmir-jit)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![API docs](https://img.shields.io/badge/docs-API%20reference-blue.svg)](https://poita.github.io/libmir-jit/)

Complete D bindings to [MIR](https://github.com/vnmakarov/mir) — Vladimir
Makarov's lightweight JIT compiler and C11 JIT, built around a medium-level IR
("MIR") with a small but real optimizing pipeline (SSA, GVN, DCE, LICM, and a
linear-scan register allocator). It targets x86-64, **aarch64 (incl. Apple
Silicon)**, ppc64le, s390x, and riscv64.

> Naming note: the `mir-*` packages on code.dlang.org are the unrelated **Mir
> numerics** ecosystem. This is a binding to *vnmakarov/mir*, the JIT — hence
> the distinct name `libmir-jit` and the `mirjit` module namespace.

## What's covered

These are raw, 1:1 `extern(C)` bindings (no opinionated wrapper):

- `mirjit.types` — all scalar typedefs, the five enums (`MIR_insn_code_t` and
  friends, values generated from the configured header and asserted in
  `unittest`), the value structs (`MIR_op_t`, `MIR_mem_t`, `MIR_var_t`,
  `MIR_str_t`, `MIR_imm_t`, `MIR_val_t`, with ABI sizes asserted), and the
  reimplemented inline type/branch-category predicates.
- `mirjit.core` — every `mir.h` function (incl. the `_MIR_*` lower-level API),
  with `MIR_init` / `MIR_init2` reimplemented as D functions (the header
  versions are `static inline`).
- `mirjit.gen` — the JIT generator (`mir-gen.h`).
- `mirjit.c2mir` — the C11→MIR frontend (`c2mir/c2mir.h`); links only when MIR
  is built with c2mir.

Container structs (`MIR_func`, `MIR_item`, `MIR_module`, `MIR_insn`, …) are
opaque handles — the public API hands them back as pointers and provides
accessors (e.g. `MIR_get_item_func`), so their macro-heavy internal layout is
not replicated.

## Requirements

- A D compiler (LDC recommended) and dub.
- A C compiler (`cc`) and `git` — MIR's C sources are fetched (pinned commit)
  and compiled automatically by `scripts/build-mir.sh`, which dub runs via
  `preGenerateCommands`. The objects land in `.mir-build/` and are linked in
  through `lflags`. No system MIR install needed.

## Usage

```d
import mirjit;

alias SumFn = extern (C) long function(long* arr, long n) nothrow @nogc;

auto ctx = MIR_init();
scope (exit) MIR_finish(ctx);

auto m = MIR_new_module(ctx, "m");
MIR_type_t[1] res = [MIR_T_I64];
MIR_var_t[2] vars = [MIR_var_t(MIR_T_P, "arr"), MIR_var_t(MIR_T_I64, "n")];
auto item = MIR_new_func_arr(ctx, "sum", 1, res.ptr, 2, vars.ptr);
auto func = MIR_get_item_func(ctx, item);
// ... append instructions with MIR_new_insn_arr / MIR_new_*_op ...
MIR_finish_func(ctx); MIR_finish_module(ctx);

MIR_load_module(ctx, m);
MIR_gen_init(ctx);
MIR_gen_set_optimize_level(ctx, 2);
MIR_link(ctx, &MIR_set_gen_interface, null);
auto fn = cast(SumFn) MIR_gen(ctx, item);  // native entry point
MIR_gen_finish(ctx);
```

A full, runnable version is in [`examples/sum.d`](examples/sum.d).

## Build & test

```sh
dub build
dub test          # builds MIR, links it, runs the ABI asserts + a JIT sum test
dub run :sum      # (if wired as a subpackage) or build examples/sum.d directly
```

Use the array-based constructors (`MIR_new_func_arr`, `MIR_new_insn_arr`) rather
than the C variadics (`MIR_new_func`, `MIR_new_insn`): passing `MIR_op_t` by
value through C varargs from D is not ABI-safe. The variadic declarations are
present for completeness.

## Regenerating after a MIR update

Enum values are derived from the header. If you bump the pinned MIR commit in
`scripts/build-mir.sh`, re-verify the enums and struct sizes — `dub test` will
fail loudly if any `MIR_op_t`/enum value drifts.

## License

MIT (this binding). MIR itself is MIT-licensed, © Vladimir Makarov.
