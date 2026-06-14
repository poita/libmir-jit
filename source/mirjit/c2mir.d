/**
 * mirjit.c2mir — bindings to c2mir/c2mir.h (the C11 -> MIR frontend).
 *
 * Available only when MIR is built with c2mir (compile c2mir/c2mir.c into the
 * link). See the :c2mir dub configuration.
 */
module mirjit.c2mir;

public import mirjit.types;
import core.stdc.stdio : FILE;

enum const(char)* COMMAND_LINE_SOURCE_NAME = "<command-line>";
enum const(char)* STDIN_SOURCE_NAME        = "<stdin>";

extern (C):

struct c2mir_macro_command
{
    int def_p;            /// #define (true) or #undef (false)
    const(char)* name;
    const(char)* def;    /// used only when def_p is true
}

struct c2mir_options
{
    FILE* message_file;
    int debug_p, verbose_p, ignore_warnings_p, no_prepro_p, prepro_only_p;
    int syntax_only_p, pedantic_p, asm_p, object_p;
    size_t module_num;
    FILE* prepro_output_file; /// non-null for prepro_only_p
    const(char)* output_file_name;
    size_t macro_commands_num, include_dirs_num;
    c2mir_macro_command* macro_commands;
    const(char)** include_dirs;
}

/// Reader callback: returns the next char of source, or EOF.
alias c2mir_getc_func_t = extern (C) int function(void* data);

void c2mir_init(MIR_context_t ctx) nothrow @nogc;
void c2mir_finish(MIR_context_t ctx) nothrow @nogc;
int c2mir_compile(MIR_context_t ctx, c2mir_options* ops, c2mir_getc_func_t getc_func,
        void* getc_data, const(char)* source_name, FILE* output_file);
