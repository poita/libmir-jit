/**
 * Example: the idiomatic `CJit` interface — compile C source strings to native
 * code at runtime and call them, including compiled C that calls back into the
 * host (here, libc's printf via host-symbol resolution).
 *
 *     dub run :cstr
 */
module example.c2mir_string;

import std.stdio;
import mirjit;          // raw bindings
import mirjit.cjit;     // idiomatic wrapper (active under with-c2mir)

void main()
{
    auto jit = CJit.create();              // RAII: tears down MIR/c2mir on scope exit

    // 1) compile a function from a string and call it as a typed delegate.
    alias AddFn = extern (C) int function(int, int) nothrow @nogc;
    auto add = jit.compileFunction!AddFn("add",
        "int add(int a, int b) { return a + b; }");
    writefln("add(2, 3)  = %s (want 5)", add(2, 3));
    writefln("add(40, 2) = %s (want 42)", add(40, 2));
    assert(add(2, 3) == 5 && add(40, 2) == 42);

    // 2) compiled C calling back into the host (printf resolved automatically).
    alias GreetFn = extern (C) void function() nothrow @nogc;
    auto greet = jit.compileFunction!GreetFn("greet", `
        extern int printf(const char *, ...);
        void greet(void) { printf("  hello from JIT-compiled C!\n"); }
    `);
    greet();

    // 3) compile errors surface as exceptions with the compiler's diagnostics.
    try
        jit.compile("int oops(void) { return nope; }");
    catch (CJitException e)
        writefln("caught expected compile error: %s", e.msg.length ? "yes" : "no");

    writeln("OK");
}
