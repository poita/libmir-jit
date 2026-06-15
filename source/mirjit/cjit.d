/**
 * mirjit.cjit — an idiomatic D interface over c2mir.
 *
 * Compile C source (a string, file, or any range of chars) to native code at
 * runtime and call it, with RAII resource management, D exceptions carrying the
 * compiler's diagnostics, typed function pointers, and automatic resolution of
 * host symbols (so compiled C can call `printf`, your `extern(C)` functions, …).
 *
 * Only active under the `with-c2mir` configuration (which links c2mir and sets
 * `-version=MirjitC2mir`); under the default `bundled` build this module is
 * empty, so it never introduces unresolved c2mir symbols.
 *
 * ---
 * auto jit = CJit.create();
 * alias AddFn = extern (C) int function(int, int) nothrow @nogc;
 * auto add = jit.compileFunction!AddFn("add", "int add(int a, int b){ return a+b; }");
 * assert(add(2, 3) == 5);
 * ---
 */
module mirjit.cjit;

version (MirjitC2mir):

import mirjit;
import std.exception : enforce;
import std.string : toStringz;
import std.traits : isFunctionPointer;
import core.stdc.stdio : FILE, fflush, fclose;
import core.stdc.stdlib : free;

// POSIX: capture c2mir's diagnostics into a growable in-memory buffer.
private extern (C) FILE* open_memstream(char** bufp, size_t* sizep) nothrow @nogc;

/// Thrown when c2mir fails to compile a translation unit; the message carries
/// the compiler's diagnostic output.
class CJitException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow
    {
        super(msg, file, line);
    }
}

/// Compilation options.
struct CJitOptions
{
    uint optimize = 2;              /// MIR generator optimisation level (0..3)
    bool debugInfo = false;         /// emit c2mir debug info
    string[] includeDirs;           /// additional `-I` directories
    string[2][] defines;            /// preprocessor `[name, value]` pairs (value may be "")
    bool resolveHostSymbols = true; /// resolve unresolved externs via the host's symbols
}

/// An in-process C11 -> native compiler backed by MIR + c2mir.
///
/// Owns a MIR context and is non-copyable; all resources are released when it
/// goes out of scope. Create with `CJit.create`.
struct CJit
{
    private MIR_context_t ctx;
    private MIR_module_t lastLoaded;
    private CJitOptions opts;

    @disable this(this);            // non-copyable: owns C resources

    /// Create a compiler. (Factory rather than a constructor so options can
    /// default — a struct constructor may not default all its parameters.)
    static CJit create(CJitOptions opts = CJitOptions.init)
    {
        CJit j;
        j.ctx = MIR_init();
        enforce(j.ctx !is null, "MIR_init failed");
        c2mir_init(j.ctx);
        MIR_gen_init(j.ctx);
        MIR_gen_set_optimize_level(j.ctx, opts.optimize);
        j.opts = opts;
        return j;
    }

    ~this()
    {
        if (ctx is null) return;
        MIR_gen_finish(ctx);
        c2mir_finish(ctx);
        MIR_finish(ctx);
        ctx = null;
    }

    /// Register a host symbol the compiled C may call (e.g. `&someExternCFn`).
    /// Explicit registrations take precedence over host-symbol resolution.
    void define(string name, void* addr)
    {
        enforce(ctx !is null, "CJit not initialised");
        MIR_load_external(ctx, name.toStringz, addr);
    }

    /// Compile a C translation unit into this context. On failure throws a
    /// `CJitException` whose message is the compiler's diagnostics.
    void compile(string source, string sourceName = "<string>")
    {
        enforce(ctx !is null, "CJit not initialised");

        char* buf;
        size_t bufSize;
        FILE* msg = open_memstream(&buf, &bufSize);
        scope (exit) if (buf !is null) free(buf);

        c2mir_options copts;
        copts.message_file = msg;
        copts.debug_p = opts.debugInfo;

        auto incz = new const(char)*[opts.includeDirs.length];
        foreach (i, d; opts.includeDirs)
            incz[i] = d.toStringz;
        copts.include_dirs = incz.ptr;
        copts.include_dirs_num = incz.length;

        auto macros = new c2mir_macro_command[opts.defines.length];
        foreach (i, nv; opts.defines)
        {
            macros[i].def_p = 1;
            macros[i].name = nv[0].toStringz;
            macros[i].def = nv[1].length ? nv[1].toStringz : null;
        }
        copts.macro_commands = macros.ptr;
        copts.macro_commands_num = macros.length;

        auto reader = SourceReader(source);
        const ok = c2mir_compile(ctx, &copts, &readSource, &reader, sourceName.toStringz, null);

        if (msg !is null) { fflush(msg); fclose(msg); }
        if (!ok)
            throw new CJitException(bufSize ? buf[0 .. bufSize].idup
                                            : "c2mir compilation failed");
        loadNewModules();
    }

    /// Look up a compiled function as a typed callable; throws if absent.
    Fn func(Fn)(string name) if (isFunctionPointer!Fn)
    {
        enforce(ctx !is null, "CJit not initialised");
        auto item = mirFindFunc(ctx, name.toStringz);
        enforce!CJitException(item !is null, "function '" ~ name ~ "' not found");
        return cast(Fn) MIR_gen(ctx, item);
    }

    /// Convenience: compile `source`, then return its function `name`.
    Fn compileFunction(Fn)(string name, string source) if (isFunctionPointer!Fn)
    {
        compile(source);
        return func!Fn(name);
    }

    // Load modules added by the last compile, then (re)link to resolve imports.
    private void loadNewModules()
    {
        auto list = MIR_get_module_list(ctx);
        auto start = lastLoaded ? lastLoaded.module_next : (list ? list.head : null);
        bool any;
        for (auto m = start; m !is null; m = m.module_next)
        {
            MIR_load_module(ctx, m);
            lastLoaded = m;
            any = true;
        }
        if (any)
            MIR_link(ctx, &MIR_set_gen_interface,
                     opts.resolveHostSymbols ? &hostResolver : null);
    }
}

// --- c2mir source reader: feed it a D string ---------------------------------
private struct SourceReader { const(char)[] s; size_t pos; }

private extern (C) int readSource(void* data) nothrow @nogc
{
    auto r = cast(SourceReader*) data;
    return r.pos < r.s.length ? cast(int) cast(ubyte) r.s[r.pos++] : -1; // -1 == EOF
}

// --- default import resolver: look symbols up in the host process ------------
private __gshared void* hostHandle;

private extern (C) void* hostResolver(const(char)* name) nothrow
{
    import core.sys.posix.dlfcn : dlopen, dlsym, RTLD_LAZY;
    if (hostHandle is null)
        hostHandle = dlopen(null, RTLD_LAZY); // global symbol scope
    return hostHandle ? dlsym(hostHandle, name) : null;
}
