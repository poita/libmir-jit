/**
 * mirjit.core — bindings to mir.h (the MIR core API).
 *
 * `static inline` helpers from the header (MIR_init / MIR_init2) are
 * reimplemented as D functions at the bottom; everything else is a 1:1
 * extern(C) declaration.
 */
module mirjit.core;

public import mirjit.types;
import core.stdc.stdio : FILE;
import core.stdc.stdarg : va_list;

// Callback signatures (must use C calling convention).
alias MIR_set_interface_t   = extern (C) void function(MIR_context_t, MIR_item_t);
alias MIR_import_resolver_t  = extern (C) void* function(const(char)*);
alias MIR_writer_func_t     = extern (C) int function(MIR_context_t, ubyte);
alias MIR_reader_func_t     = extern (C) int function(MIR_context_t);

extern (C) nothrow @nogc:

// ---- init / finish ----
double _MIR_get_api_version();
MIR_context_t _MIR_init(MIR_alloc_t alloc, MIR_code_alloc_t code_alloc);
void MIR_finish(MIR_context_t ctx);

// ---- modules & items ----
MIR_module_t MIR_new_module(MIR_context_t ctx, const(char)* name);
DLIST_MIR_module_t* MIR_get_module_list(MIR_context_t ctx);
MIR_item_t MIR_new_import(MIR_context_t ctx, const(char)* name);
MIR_item_t MIR_new_export(MIR_context_t ctx, const(char)* name);
MIR_item_t MIR_new_forward(MIR_context_t ctx, const(char)* name);
MIR_item_t MIR_new_bss(MIR_context_t ctx, const(char)* name, size_t len);
MIR_item_t MIR_new_data(MIR_context_t ctx, const(char)* name, MIR_type_t el_type, size_t nel,
        const(void)* els);
MIR_item_t MIR_new_string_data(MIR_context_t ctx, const(char)* name, MIR_str_t str);
MIR_item_t MIR_new_ref_data(MIR_context_t ctx, const(char)* name, MIR_item_t item, long disp);
MIR_item_t MIR_new_lref_data(MIR_context_t ctx, const(char)* name, MIR_label_t label,
        MIR_label_t label2, long disp);
MIR_item_t MIR_new_expr_data(MIR_context_t ctx, const(char)* name, MIR_item_t expr_item);

MIR_item_t MIR_new_proto_arr(MIR_context_t ctx, const(char)* name, size_t nres,
        MIR_type_t* res_types, size_t nargs, MIR_var_t* vars);
MIR_item_t MIR_new_proto(MIR_context_t ctx, const(char)* name, size_t nres,
        MIR_type_t* res_types, size_t nargs, ...);
MIR_item_t MIR_new_vararg_proto_arr(MIR_context_t ctx, const(char)* name, size_t nres,
        MIR_type_t* res_types, size_t nargs, MIR_var_t* vars);
MIR_item_t MIR_new_vararg_proto(MIR_context_t ctx, const(char)* name, size_t nres,
        MIR_type_t* res_types, size_t nargs, ...);
MIR_item_t MIR_new_func_arr(MIR_context_t ctx, const(char)* name, size_t nres,
        MIR_type_t* res_types, size_t nargs, MIR_var_t* vars);
MIR_item_t MIR_new_func(MIR_context_t ctx, const(char)* name, size_t nres,
        MIR_type_t* res_types, size_t nargs, ...);
MIR_item_t MIR_new_vararg_func_arr(MIR_context_t ctx, const(char)* name, size_t nres,
        MIR_type_t* res_types, size_t nargs, MIR_var_t* vars);
MIR_item_t MIR_new_vararg_func(MIR_context_t ctx, const(char)* name, size_t nres,
        MIR_type_t* res_types, size_t nargs, ...);

const(char)* MIR_item_name(MIR_context_t ctx, MIR_item_t item);
MIR_func_t MIR_get_item_func(MIR_context_t ctx, MIR_item_t item);
MIR_reg_t MIR_new_func_reg(MIR_context_t ctx, MIR_func_t func, MIR_type_t type, const(char)* name);
MIR_reg_t MIR_new_global_func_reg(MIR_context_t ctx, MIR_func_t func, MIR_type_t type,
        const(char)* name, const(char)* hard_reg_name);
void MIR_finish_func(MIR_context_t ctx);
void MIR_finish_module(MIR_context_t ctx);

MIR_error_func_t MIR_get_error_func(MIR_context_t ctx);
void MIR_set_error_func(MIR_context_t ctx, MIR_error_func_t func);
MIR_alloc_t MIR_get_alloc(MIR_context_t ctx);
int MIR_get_func_redef_permission_p(MIR_context_t ctx);
void MIR_set_func_redef_permission(MIR_context_t ctx, int flag_p);

// ---- instructions ----
MIR_insn_t MIR_new_insn_arr(MIR_context_t ctx, MIR_insn_code_t code, size_t nops, MIR_op_t* ops);
MIR_insn_t MIR_new_insn(MIR_context_t ctx, MIR_insn_code_t code, ...);
MIR_insn_t MIR_new_call_insn(MIR_context_t ctx, size_t nops, ...);
MIR_insn_t MIR_new_jcall_insn(MIR_context_t ctx, size_t nops, ...);
MIR_insn_t MIR_new_ret_insn(MIR_context_t ctx, size_t nops, ...);
MIR_insn_t MIR_copy_insn(MIR_context_t ctx, MIR_insn_t insn);
const(char)* MIR_insn_name(MIR_context_t ctx, MIR_insn_code_t code);
size_t MIR_insn_nops(MIR_context_t ctx, MIR_insn_t insn);
MIR_op_mode_t MIR_insn_op_mode(MIR_context_t ctx, MIR_insn_t insn, size_t nop, int* out_p);
MIR_insn_t MIR_new_label(MIR_context_t ctx);

// ---- registers ----
MIR_reg_t MIR_reg(MIR_context_t ctx, const(char)* reg_name, MIR_func_t func);
MIR_type_t MIR_reg_type(MIR_context_t ctx, MIR_reg_t reg, MIR_func_t func);
const(char)* MIR_reg_name(MIR_context_t ctx, MIR_reg_t reg, MIR_func_t func);
const(char)* MIR_reg_hard_reg_name(MIR_context_t ctx, MIR_reg_t reg, MIR_func_t func);
const(char)* MIR_alias_name(MIR_context_t ctx, MIR_alias_t alias_);
MIR_alias_t MIR_alias(MIR_context_t ctx, const(char)* name);

// ---- operands ----
MIR_op_t MIR_new_reg_op(MIR_context_t ctx, MIR_reg_t reg);
MIR_op_t MIR_new_int_op(MIR_context_t ctx, long v);
MIR_op_t MIR_new_uint_op(MIR_context_t ctx, ulong v);
MIR_op_t MIR_new_float_op(MIR_context_t ctx, float v);
MIR_op_t MIR_new_double_op(MIR_context_t ctx, double v);
MIR_op_t MIR_new_ldouble_op(MIR_context_t ctx, real v);
MIR_op_t MIR_new_ref_op(MIR_context_t ctx, MIR_item_t item);
MIR_op_t MIR_new_str_op(MIR_context_t ctx, MIR_str_t str);
MIR_op_t MIR_new_mem_op(MIR_context_t ctx, MIR_type_t type, MIR_disp_t disp, MIR_reg_t base,
        MIR_reg_t index, MIR_scale_t scale);
MIR_op_t MIR_new_alias_mem_op(MIR_context_t ctx, MIR_type_t type, MIR_disp_t disp, MIR_reg_t base,
        MIR_reg_t index, MIR_scale_t scale, MIR_alias_t alias_, MIR_alias_t noalias);
MIR_op_t MIR_new_label_op(MIR_context_t ctx, MIR_label_t label);
int MIR_op_eq_p(MIR_context_t ctx, MIR_op_t op1, MIR_op_t op2);
htab_hash_t MIR_op_hash_step(MIR_context_t ctx, htab_hash_t h, MIR_op_t op);

// ---- insn list manipulation ----
void MIR_append_insn(MIR_context_t ctx, MIR_item_t func, MIR_insn_t insn);
void MIR_prepend_insn(MIR_context_t ctx, MIR_item_t func, MIR_insn_t insn);
void MIR_insert_insn_after(MIR_context_t ctx, MIR_item_t func, MIR_insn_t after, MIR_insn_t insn);
void MIR_insert_insn_before(MIR_context_t ctx, MIR_item_t func, MIR_insn_t before, MIR_insn_t insn);
void MIR_remove_insn(MIR_context_t ctx, MIR_item_t func, MIR_insn_t insn);
void MIR_change_module_ctx(MIR_context_t old_ctx, MIR_module_t m, MIR_context_t new_ctx);
MIR_insn_code_t MIR_reverse_branch_code(MIR_insn_code_t code);

// ---- textual output ----
const(char)* MIR_type_str(MIR_context_t ctx, MIR_type_t tp);
void MIR_output_str(MIR_context_t ctx, FILE* f, MIR_str_t str);
void MIR_output_op(MIR_context_t ctx, FILE* f, MIR_op_t op, MIR_func_t func);
void MIR_output_insn(MIR_context_t ctx, FILE* f, MIR_insn_t insn, MIR_func_t func, int newline_p);
void MIR_output_item(MIR_context_t ctx, FILE* f, MIR_item_t item);
void MIR_output_module(MIR_context_t ctx, FILE* f, MIR_module_t mod);
void MIR_output(MIR_context_t ctx, FILE* f);

// ---- binary I/O (compiled in unless MIR_NO_IO) ----
void MIR_write(MIR_context_t ctx, FILE* f);
void MIR_write_module(MIR_context_t ctx, FILE* f, MIR_module_t mod);
void MIR_read(MIR_context_t ctx, FILE* f);
void MIR_write_with_func(MIR_context_t ctx, MIR_writer_func_t writer_func);
void MIR_write_module_with_func(MIR_context_t ctx, MIR_writer_func_t writer_func, MIR_module_t mod);
void MIR_read_with_func(MIR_context_t ctx, MIR_reader_func_t reader_func);

// ---- text scan (compiled in unless MIR_NO_SCAN) ----
void MIR_scan_string(MIR_context_t ctx, const(char)* str);

// ---- load / link ----
MIR_item_t MIR_get_global_item(MIR_context_t ctx, const(char)* name);
void MIR_load_module(MIR_context_t ctx, MIR_module_t m);
void MIR_load_external(MIR_context_t ctx, const(char)* name, void* addr);
void MIR_link(MIR_context_t ctx, MIR_set_interface_t set_interface,
        MIR_import_resolver_t import_resolver);

// ---- interpreter ----
void MIR_interp(MIR_context_t ctx, MIR_item_t func_item, MIR_val_t* results, size_t nargs, ...);
void MIR_interp_arr(MIR_context_t ctx, MIR_item_t func_item, MIR_val_t* results, size_t nargs,
        MIR_val_t* vals);
void MIR_interp_arr_varg(MIR_context_t ctx, MIR_item_t func_item, MIR_val_t* results, size_t nargs,
        MIR_val_t* vals, va_list va);
void MIR_set_interp_interface(MIR_context_t ctx, MIR_item_t func_item);

// ---- lower-level / internal API (_MIR_*) ----
const(char)* _MIR_uniq_string(MIR_context_t ctx, const(char)* str);
int _MIR_reserved_ref_name_p(MIR_context_t ctx, const(char)* name);
int _MIR_reserved_name_p(MIR_context_t ctx, const(char)* name);
long _MIR_addr_offset(MIR_context_t ctx, MIR_insn_code_t code);
void _MIR_free_insn(MIR_context_t ctx, MIR_insn_t insn);
MIR_reg_t _MIR_new_temp_reg(MIR_context_t ctx, MIR_type_t type, MIR_func_t func);
size_t _MIR_type_size(MIR_context_t ctx, MIR_type_t type);
MIR_op_mode_t _MIR_insn_code_op_mode(MIR_context_t ctx, MIR_insn_code_t code, size_t nop, int* out_p);
MIR_insn_t _MIR_new_unspec_insn(MIR_context_t ctx, size_t nops, ...);
void _MIR_register_unspec_insn(MIR_context_t ctx, ulong code, const(char)* name, size_t nres,
        MIR_type_t* res_types, size_t nargs, int vararg_p, MIR_var_t* args);
void _MIR_duplicate_func_insns(MIR_context_t ctx, MIR_item_t func_item);
void _MIR_restore_func_insns(MIR_context_t ctx, MIR_item_t func_item);
void _MIR_get_temp_item_name(MIR_context_t ctx, MIR_module_t mod, char* buff, size_t buff_len);
MIR_op_t _MIR_new_var_op(MIR_context_t ctx, MIR_reg_t var);
MIR_op_t _MIR_new_var_mem_op(MIR_context_t ctx, MIR_type_t type, MIR_disp_t disp, MIR_reg_t base,
        MIR_reg_t index, MIR_scale_t scale);
MIR_op_t _MIR_new_alias_var_mem_op(MIR_context_t ctx, MIR_type_t type, MIR_disp_t disp,
        MIR_reg_t base, MIR_reg_t index, MIR_scale_t scale, MIR_alias_t alias_, MIR_alias_t no_alias);
MIR_item_t _MIR_builtin_proto(MIR_context_t ctx, MIR_module_t mod, const(char)* name, size_t nres,
        MIR_type_t* res_types, size_t nargs, ...);
MIR_item_t _MIR_builtin_func(MIR_context_t ctx, MIR_module_t mod, const(char)* name, void* addr);
void _MIR_flush_code_cache(void* start, void* bound);
ubyte* _MIR_publish_code(MIR_context_t ctx, const(ubyte)* code, size_t code_len);
ubyte* _MIR_get_new_code_addr(MIR_context_t ctx, size_t size);
ubyte* _MIR_publish_code_by_addr(MIR_context_t ctx, void* addr, const(ubyte)* code, size_t code_len);
void _MIR_change_code(MIR_context_t ctx, ubyte* addr, const(ubyte)* code, size_t code_len);
void _MIR_update_code_arr(MIR_context_t ctx, ubyte* base, size_t nloc, const(MIR_code_reloc_t)* relocs);
void _MIR_update_code(MIR_context_t ctx, ubyte* base, size_t nloc, ...);
void* va_arg_builtin(void* p, ulong t);
void va_block_arg_builtin(void* res, void* p, size_t s, ulong t);
void va_start_interp_builtin(MIR_context_t ctx, void* p, void* a);
void va_end_interp_builtin(MIR_context_t ctx, void* p);
void* _MIR_get_bstart_builtin(MIR_context_t ctx);
void* _MIR_get_bend_builtin(MIR_context_t ctx);
void* _MIR_get_ff_call(MIR_context_t ctx, size_t nres, MIR_type_t* res_types, size_t nargs,
        _MIR_arg_desc_t* arg_descs, size_t arg_vars_num);
void* _MIR_get_interp_shim(MIR_context_t ctx, MIR_item_t func_item, void* handler);
void* _MIR_get_thunk(MIR_context_t ctx);
void* _MIR_get_thunk_addr(MIR_context_t ctx, void* thunk);
void _MIR_redirect_thunk(MIR_context_t ctx, void* thunk, void* to);
void* _MIR_get_jmpi_thunk(MIR_context_t ctx, void** res_loc, void* res, void* cont);
void* _MIR_get_wrapper(MIR_context_t ctx, MIR_item_t called_func, void* hook_address);
void* _MIR_get_wrapper_end(MIR_context_t ctx);
void* _MIR_get_bb_thunk(MIR_context_t ctx, void* bb_version, void* handler);
void _MIR_replace_bb_thunk(MIR_context_t ctx, void* thunk, void* to);
void* _MIR_get_bb_wrapper(MIR_context_t ctx, void* data, void* hook_address);
int _MIR_name_char_p(MIR_context_t ctx, int ch, int first_p);
void _MIR_dump_code(const(char)* name, ubyte* code, size_t code_len);
int _MIR_get_hard_reg(MIR_context_t ctx, const(char)* hard_reg_name);
void* _MIR_get_module_global_var_hard_regs(MIR_context_t ctx, MIR_module_t mod);

// ---- reimplemented static-inline header helpers (D linkage) ----
extern (D):

/// Create a context with custom allocators, checking the API version.
MIR_context_t MIR_init2(MIR_alloc_t alloc, MIR_code_alloc_t code_alloc) nothrow @nogc
{
    import core.stdc.stdio : stderr, fprintf;
    import core.stdc.stdlib : exit;
    if (MIR_API_VERSION != _MIR_get_api_version())
    {
        fprintf(stderr, "mir.h header version %g differs from mir lib version %g -- good bye!\n",
                MIR_API_VERSION, _MIR_get_api_version());
        exit(1);
    }
    return _MIR_init(alloc, code_alloc);
}

/// Create a context with default allocators.
MIR_context_t MIR_init() nothrow @nogc { return MIR_init2(null, null); }
