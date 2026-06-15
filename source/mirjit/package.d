/**
 * mirjit — complete D bindings to MIR (https://github.com/vnmakarov/mir),
 * Vladimir Makarov's lightweight JIT compiler.
 *
 * `import mirjit;` pulls in the core API, the JIT generator, and the value
 * types. The C11->MIR frontend lives in `mirjit.c2mir` and is only linkable
 * when MIR is built with c2mir (see README / the :c2mir dub configuration).
 *
 * These are raw 1:1 bindings. See README.md for build/linking and a usage
 * example.
 */
module mirjit;

public import mirjit.types;
public import mirjit.core;
public import mirjit.gen;
public import mirjit.c2mir;
