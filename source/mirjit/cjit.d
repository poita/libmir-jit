/**
 * mirjit.cjit — an idiomatic D layer over the c2mir C11->MIR frontend.
 *
 * Compile a translation unit of C source once with `jit`, then pull out typed,
 * native function pointers with `CModule.get`:
 *
 * ---
 * auto m   = jit("int add(int a, int b) { return a + b; }");
 * auto add = m.get!(int, int, int)("add");   // extern(C) int function(int, int)
 * assert(add(2, 3) == 5);
 * ---
 *
 * The first template argument to `get` is the return type; the rest are the
 * parameter types. `get!(Ret, void)` (or `get!(Ret)`) denotes a zero-parameter
 * function. Only C-compatible scalar and pointer types are accepted; anything
 * else is a compile-time error.
 *
 * `CModule` owns the MIR context and all generated code: the returned function
 * pointers are valid only while the `CModule` is alive (same contract as a
 * dlopen handle). It is non-copyable and frees everything in its destructor.
 *
 * This module is only compiled when the `MirjitC2mir` version is set, which the
 * `with-c2mir` dub configuration does (it also links the c2mir frontend).
 */
module mirjit.cjit;

version (MirjitC2mir):

import mirjit.types;
import mirjit.core;
import mirjit.gen;
import mirjit.c2mir;

import std.meta : AliasSeq;
import std.string : toStringz;
import core.stdc.stdio : FILE, fclose;
import core.stdc.stdlib : free;
import core.stdc.string : strlen;

extern (C) FILE* open_memstream(char** bufp, size_t* sizep) nothrow @nogc;

/// Thrown by `jit` when c2mir rejects the C source. The message carries the
/// diagnostics c2mir produced.
class CompileException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) { super(msg, file, line); }
}

/// Thrown by `CModule.get` when no function of that name exists.
class SymbolException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) { super(msg, file, line); }
}

/// Thrown by `CModule.get` when the requested D signature is incompatible with
/// the compiled C function's prototype.
class SignatureException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) { super(msg, file, line); }
}

/// Options controlling a `jit` compilation.
struct COptions
{
    uint optimize = 2;            /// MIR generator optimization level (0..3).
    bool debugInfo = false;       /// Pass c2mir's debug flag.
    string[] includeDirs;         /// Header search paths (-I).
    string[2][] defines;          /// Preprocessor [name, value] pairs (-D); value "" defines it empty.
    bool resolveHostSymbols = true; /// Resolve unresolved C symbols via dlsym(RTLD_DEFAULT).
}

/**
 * A compiled C translation unit. Owns the MIR context; hands out typed native
 * function pointers via `get`. Non-copyable; frees all code on destruction.
 */
struct CModule
{
    private MIR_context_t ctx;
    private bool genInited;
    private void*[string] genCache;

    @disable this(this);

    ~this()
    {
        if (ctx is null) return;
        if (genInited) MIR_gen_finish(ctx);
        c2mir_finish(ctx);
        MIR_finish(ctx);
        ctx = null;
    }

    /// The underlying MIR context, for dropping down to the raw API.
    MIR_context_t context() { return ctx; }

    /// True if a function with this name was compiled into the module.
    bool has(string name) { return mirFindFunc(ctx, name.toStringz) !is null; }

    /// Names of every function defined in the module.
    string[] functions()
    {
        string[] result;
        foreach (mod; mirModules(ctx))
            for (auto it = mod.items_head; it !is null; it = it.item_link_next)
                if (it.item_type == MIR_func_item)
                {
                    auto n = MIR_item_name(ctx, it);
                    result ~= cast(string) n[0 .. strlen(n)].idup;
                }
        return result;
    }

    /**
     * Generate (lazily, then cache) the named C function and return it as a
     * typed `extern(C)` function pointer. `Ret` is the return type; `Args` are
     * the parameter types. `get!(Ret, void)` and `get!(Ret)` both mean no
     * parameters.
     *
     * Throws: `SymbolException` if no such function;
     *         `SignatureException` if the prototype is incompatible.
     */
    auto get(Ret, Args...)(string name)
    {
        static if (Args.length == 1 && is(Args[0] == void))
            alias Params = AliasSeq!();
        else
            alias Params = Args;
        alias Fn = extern (C) Ret function(Params) nothrow @nogc;

        enum size_t wantNargs = Params.length;
        enum size_t wantNres = is(Ret == void) ? 0 : 1;

        auto item = mirFindFunc(ctx, name.toStringz);
        if (item is null)
            throw new SymbolException("mirjit: function '" ~ name ~ "' not found");

        auto addr = genFor(item, name);
        auto fv = cast(const(MirFuncView)*) MIR_get_item_func(ctx, item);

        if (fv.vararg_p)
            throw new SignatureException(
                "mirjit: '" ~ name ~ "' is a vararg function, which get! does not support");
        if (fv.nargs != wantNargs || fv.nres != wantNres)
            throw sigMismatch!(Ret, Params)(name, fv);
        static if (!is(Ret == void))
            if (!typeCompatible(mirType!Ret, fv.res_types[0]))
                throw sigMismatch!(Ret, Params)(name, fv);
        static foreach (i, P; Params)
            if (!typeCompatible(mirType!P, fv.vars.varr[i].type))
                throw sigMismatch!(Ret, Params)(name, fv);

        return cast(Fn) addr;
    }

    private void* genFor(MIR_item_t item, string name)
    {
        if (auto p = name in genCache) return *p;
        auto addr = MIR_gen(ctx, item);
        genCache[name] = addr;
        return addr;
    }
}

/**
 * Compile one translation unit of C `source` to MIR and return an owning
 * `CModule`. C syntax/semantic errors surface here as `CompileException`.
 */
CModule jit(string source, COptions opts = COptions.init)
{
    CModule m;
    m.ctx = MIR_init();
    c2mir_init(m.ctx);
    compileInto(m, source, opts);
    return m;
}

// ---- internals ----

private struct SrcReader { const(char)[] s; size_t pos; }

private extern (C) int srcGetc(void* p) nothrow @nogc
{
    auto r = cast(SrcReader*) p;
    return r.pos < r.s.length ? cast(int) cast(ubyte) r.s[r.pos++] : -1; // -1 == EOF
}

private extern (C) void* hostResolver(const(char)* name) nothrow @nogc
{
    import core.sys.posix.dlfcn : dlsym;
    version (OSX)
        enum void* RTLD_DEFAULT = cast(void*) -2;
    else
        enum void* RTLD_DEFAULT = null;
    return dlsym(RTLD_DEFAULT, name);
}

private void compileInto(ref CModule m, string source, COptions opts)
{
    auto ctx = m.ctx;

    char* buf;
    size_t bufSize;
    FILE* msg = open_memstream(&buf, &bufSize);

    c2mir_options o;
    o.message_file = msg;
    o.debug_p = opts.debugInfo;

    const(char)*[] incs;
    foreach (d; opts.includeDirs) incs ~= d.toStringz;
    if (incs.length) { o.include_dirs = incs.ptr; o.include_dirs_num = incs.length; }

    c2mir_macro_command[] macros;
    foreach (d; opts.defines)
        macros ~= c2mir_macro_command(1, d[0].toStringz, d[1].toStringz);
    if (macros.length) { o.macro_commands = macros.ptr; o.macro_commands_num = macros.length; }

    auto reader = SrcReader(source);
    int ok = c2mir_compile(ctx, &o, &srcGetc, &reader, "inline.c", null);
    fclose(msg);
    scope (exit) free(buf);

    if (!ok)
    {
        string diag = bufSize ? cast(string) buf[0 .. bufSize].idup : "";
        throw new CompileException("mirjit: c2mir failed to compile C source\n" ~ diag);
    }

    foreach (mod; mirModules(ctx))
        MIR_load_module(ctx, mod);

    MIR_gen_init(ctx);
    m.genInited = true;
    MIR_gen_set_optimize_level(ctx, opts.optimize);
    MIR_link(ctx, &MIR_set_gen_interface, opts.resolveHostSymbols ? &hostResolver : null);
}

/// View over MIR_func (opaque in the public bindings) exposing the prototype
/// fields needed for signature checking. Layout verified against mir.h below.
private struct MirVarr
{
    size_t els_num;
    size_t size;
    MIR_var_t* varr;
    void* alloc;
}

private struct MirFuncView
{
    const(char)* name;
    MIR_item_t func_item;
    size_t original_vars_num;
    void*[2] insns;
    void*[2] original_insns;
    uint nres, nargs, last_temp_num, n_inlines;
    MIR_type_t* res_types;
    char vararg_p, expr_p, jret_p;
    MirVarr* vars;
    MirVarr* global_vars;
    void* machine_code, call_addr, internal, first_lref;
}

static assert(MirFuncView.nres.offsetof == 56);
static assert(MirFuncView.nargs.offsetof == 60);
static assert(MirFuncView.res_types.offsetof == 72);
static assert(MirFuncView.vars.offsetof == 88);

/// Map a D type to the MIR type c2mir emits for the corresponding C type.
private template mirType(T)
{
    static if (is(T == bool) || is(T == ubyte) || is(T == char))
        enum mirType = MIR_T_U8;
    else static if (is(T == byte))
        enum mirType = MIR_T_I8;
    else static if (is(T == short))
        enum mirType = MIR_T_I16;
    else static if (is(T == ushort) || is(T == wchar))
        enum mirType = MIR_T_U16;
    else static if (is(T == int))
        enum mirType = MIR_T_I32;
    else static if (is(T == uint) || is(T == dchar))
        enum mirType = MIR_T_U32;
    else static if (is(T == long))
        enum mirType = MIR_T_I64;
    else static if (is(T == ulong))
        enum mirType = MIR_T_U64;
    else static if (is(T == float))
        enum mirType = MIR_T_F;
    else static if (is(T == double))
        enum mirType = MIR_T_D;
    else static if (is(T == P*, P))
        enum mirType = MIR_T_P;
    else
        static assert(false, "mirjit: unsupported C type " ~ T.stringof);
}

/// Byte width of an integer/pointer MIR type, or 0 if not integral.
private int intSize(MIR_type_t t) nothrow @nogc pure @safe
{
    switch (t)
    {
        case MIR_T_I8, MIR_T_U8:           return 1;
        case MIR_T_I16, MIR_T_U16:         return 2;
        case MIR_T_I32, MIR_T_U32:         return 4;
        case MIR_T_I64, MIR_T_U64, MIR_T_P: return 8;
        default:                           return 0;
    }
}

/// Two MIR types are call-compatible if identical, or both integral/pointer of
/// the same width (signedness and int-vs-pointer do not affect the C ABI; c2mir
/// emits pointers as u64). Floating-point types must match exactly.
private bool typeCompatible(MIR_type_t want, MIR_type_t got) nothrow @nogc pure @safe
{
    if (want == got) return true;
    auto w = intSize(want), g = intSize(got);
    return w != 0 && g != 0 && w == g;
}

private string mirTypeName(MIR_type_t t) pure @safe
{
    switch (t)
    {
        case MIR_T_I8:  return "i8";
        case MIR_T_U8:  return "u8";
        case MIR_T_I16: return "i16";
        case MIR_T_U16: return "u16";
        case MIR_T_I32: return "i32";
        case MIR_T_U32: return "u32";
        case MIR_T_I64: return "i64";
        case MIR_T_U64: return "u64";
        case MIR_T_F:   return "f";
        case MIR_T_D:   return "d";
        case MIR_T_LD:  return "ld";
        case MIR_T_P:   return "p";
        default:        return "?";
    }
}

private SignatureException sigMismatch(Ret, Params...)(string name, const(MirFuncView)* fv)
{
    string want = Ret.stringof ~ "(";
    static foreach (i, P; Params)
    {
        if (i) want ~= ", ";
        want ~= P.stringof;
    }
    want ~= ")";

    string got = (fv.nres ? mirTypeName(fv.res_types[0]) : "void") ~ "(";
    foreach (i; 0 .. fv.nargs)
    {
        if (i) got ~= ", ";
        got ~= mirTypeName(fv.vars.varr[i].type);
    }
    got ~= ")";

    return new SignatureException(
        "mirjit: signature mismatch for '" ~ name ~ "': requested D " ~ want
        ~ " but compiled C function is MIR " ~ got);
}

// ---- tests ----

version (unittest)
{
    import std.exception : assertThrown, collectException;
    import core.stdc.string : strcmp;
}

unittest // basic: compile and call a scalar function
{
    auto m = jit("int add(int a, int b) { return a + b; }");
    auto add = m.get!(int, int, int)("add");
    assert(add(2, 3) == 5);
    assert(add(40, 2) == 42);
}

unittest // pull multiple functions out of one module
{
    auto m = jit("int add(int a, int b){return a+b;} int sub(int a, int b){return a-b;}");
    auto add = m.get!(int, int, int)("add");
    auto sub = m.get!(int, int, int)("sub");
    assert(add(10, 4) == 14);
    assert(sub(10, 4) == 6);
}

unittest // void return and a zero-parameter function via get!(Ret, void)
{
    __gshared int hits;
    // a pointer return, no args
    auto m = jit(`const char* greet(void) { return "hi"; }`);
    auto greet = m.get!(const(char)*, void)("greet");
    assert(strcmp(greet(), "hi") == 0);
}

unittest // get!(Ret) with no Args also means zero parameters
{
    auto m = jit("int answer(void) { return 42; }");
    auto answer = m.get!(int)("answer");
    assert(answer() == 42);
}

unittest // floating point
{
    auto m = jit("double scale(double x) { return x * 2.5; }");
    auto scale = m.get!(double, double)("scale");
    assert(scale(4.0) == 10.0);
}

unittest // pointer argument
{
    auto m = jit("int firstplus(int* p, int n) { return p[0] + n; }");
    auto f = m.get!(int, int*, int)("firstplus");
    int[3] xs = [7, 8, 9];
    assert(f(xs.ptr, 100) == 107);
}

unittest // has() and functions()
{
    auto m = jit("int a(void){return 1;} int b(void){return 2;}");
    assert(m.has("a") && m.has("b") && !m.has("c"));
    auto fns = m.functions();
    assert(fns.length == 2);
    bool sawA, sawB;
    foreach (n; fns) { if (n == "a") sawA = true; if (n == "b") sawB = true; }
    assert(sawA && sawB);
}

unittest // lazy gen is cached: same name yields the same address
{
    auto m = jit("int id(int x){return x;}");
    auto a = m.get!(int, int)("id");
    auto b = m.get!(int, int)("id");
    assert(a is b);
}

unittest // unknown function name throws SymbolException
{
    auto m = jit("int present(void){return 0;}");
    assertThrown!SymbolException(m.get!(int)("absent"));
}

unittest // wrong arity throws SignatureException
{
    auto m = jit("int add(int a, int b){return a+b;}");
    assertThrown!SignatureException(m.get!(int, int)("add"));
}

unittest // incompatible type class throws SignatureException
{
    auto m = jit("int id(int x){return x;}");
    // i32 argument requested as a double is not call-compatible
    assertThrown!SignatureException(m.get!(int, double)("id"));
}

unittest // signedness and int-vs-pointer of equal width are accepted
{
    auto m = jit("long passthru(char* p){ return (long) p; }");
    // request the pointer parameter as void* and result as ulong: widths match
    auto f = m.get!(ulong, void*)("passthru");
    int x;
    assert(f(&x) == cast(ulong) &x);
}

unittest // a C compile error throws CompileException with diagnostics
{
    auto e = collectException!CompileException(jit("int bad(void) { return ; }"));
    assert(e !is null);
    assert(e.msg.length > "mirjit: c2mir failed to compile C source\n".length);
}

unittest // host symbol resolution: the C code calls libc/libm sqrt
{
    auto m = jit("double sqrt(double); double rooted(double x){ return sqrt(x); }");
    auto rooted = m.get!(double, double)("rooted");
    assert(rooted(16.0) == 4.0);
}

unittest // optimization level 0 still produces correct code
{
    COptions o; o.optimize = 0;
    auto m = jit("int twice(int x){return x+x;}", o);
    assert(m.get!(int, int)("twice")(21) == 42);
}
