/**
 * Example: compile a C source STRING to native code at runtime with c2mir,
 * then call it — all in-process, no subprocess or temp files.
 *
 * Requires the with-c2mir configuration (links c2mir.o):
 *     dub run :cstr
 */
module example.c2mir_string;

import std.stdio;
import mirjit;

// c2mir reads source through a char-at-a-time callback; this one reads a string.
struct StrReader { const(char)[] s; size_t pos; }
extern (C) int strGetc(void* p) nothrow @nogc
{
    auto r = cast(StrReader*) p;
    return r.pos < r.s.length ? cast(int) cast(ubyte) r.s[r.pos++] : -1; // -1 = EOF
}

/// Compile a single C function from `src` and JIT it to a callable `Fn`.
Fn compileC(Fn)(MIR_context_t ctx, string funcName, string src)
{
    auto reader = StrReader(src);
    c2mir_options opts;                 // zero-initialised
    opts.message_file = stderr.getFP;   // surface any diagnostics

    if (!c2mir_compile(ctx, &opts, &strGetc, &reader, "inline.c", null))
        throw new Exception("c2mir failed to compile the source");

    // Load every module c2mir produced into the context.
    foreach (m; mirModules(ctx))
        MIR_load_module(ctx, m);

    MIR_gen_init(ctx);
    MIR_gen_set_optimize_level(ctx, 2);
    MIR_link(ctx, &MIR_set_gen_interface, null);

    auto item = mirFindFunc(ctx, funcName.toStringz);
    if (item is null)
        throw new Exception("function '" ~ funcName ~ "' not found after compile");
    return cast(Fn) MIR_gen(ctx, item);
}

import std.string : toStringz;

void main()
{
    auto ctx = MIR_init();
    scope (exit) MIR_finish(ctx);
    c2mir_init(ctx);
    scope (exit) c2mir_finish(ctx);

    // A C function built (and optimised) entirely at runtime.
    alias AddFn = extern (C) int function(int, int) nothrow @nogc;
    auto add = compileC!AddFn(ctx, "add",
        "int add(int a, int b) { return a + b; }\n");

    writefln("add(2, 3)   = %s (want 5)", add(2, 3));
    writefln("add(40, 2)  = %s (want 42)", add(40, 2));
    assert(add(2, 3) == 5 && add(40, 2) == 42);
    writeln("OK");
}
