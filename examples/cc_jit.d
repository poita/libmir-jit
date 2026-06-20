/**
 * Example: the idiomatic `jit` / `CModule.get` layer over c2mir.
 *
 * Compile a translation unit of C once, then pull out typed native function
 * pointers and call them. Requires the with-c2mir configuration:
 *     dub run :cc
 */
module example.cc_jit;

import std.stdio;
import std.string : fromStringz;
import core.stdc.string : strcmp;
import mirjit;

void main()
{
    // One translation unit, several functions, compiled and optimized at runtime.
    auto m = jit(`
        int    add(int a, int b)   { return a + b; }
        double scale(double x)     { return x * 2.5; }
        long   sumto(long n)       { long s = 0; for (long i = 1; i <= n; i++) s += i; return s; }
        const char* greet(void)    { return "hello from C"; }
    `);

    auto add   = m.get!(int, int, int)("add");
    auto scale = m.get!(double, double)("scale");
    auto sumto = m.get!(long, long)("sumto");
    auto greet = m.get!(const(char)*, void)("greet");

    writefln("add(2, 3)    = %s", add(2, 3));
    writefln("scale(4.0)   = %s", scale(4.0));
    writefln("sumto(100)   = %s", sumto(100));
    writefln("greet()      = %s", greet().fromStringz);

    assert(add(2, 3) == 5);
    assert(scale(4.0) == 10.0);
    assert(sumto(100) == 5050);
    assert(strcmp(greet(), "hello from C") == 0);
    writeln("\nfunctions in module: ", m.functions());
    writeln("OK");
}
