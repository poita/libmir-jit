/**
 * Functional tests — compiled only under -unittest (i.e. `dub test`), never
 * shipped in normal builds. Requires the MIR objects to be linked.
 */
module mirjit.tests;

version (unittest):

import mirjit;

// JIT `long sum(long* arr, long n)` and check it against a known result.
unittest
{
    alias SumFn = extern (C) long function(long*, long) nothrow @nogc;

    auto ctx = MIR_init();
    scope (exit) MIR_finish(ctx);

    auto m = MIR_new_module(ctx, "t");
    MIR_type_t[1] res = [MIR_T_I64];
    MIR_var_t[2] vars = [MIR_var_t(MIR_T_P, "arr"), MIR_var_t(MIR_T_I64, "n")];
    auto item = MIR_new_func_arr(ctx, "sum", 1, res.ptr, 2, vars.ptr);
    auto func = MIR_get_item_func(ctx, item);

    auto arr = MIR_reg(ctx, "arr", func), n = MIR_reg(ctx, "n", func);
    auto s = MIR_new_func_reg(ctx, func, MIR_T_I64, "s");
    auto i = MIR_new_func_reg(ctx, func, MIR_T_I64, "i");
    auto tmp = MIR_new_func_reg(ctx, func, MIR_T_I64, "tmp");
    auto cont = MIR_new_label(ctx), fin = MIR_new_label(ctx);

    void emit(MIR_insn_code_t c, MIR_op_t[] ops...)
    { MIR_append_insn(ctx, item, MIR_new_insn_arr(ctx, c, ops.length, ops.ptr)); }
    auto R = (MIR_reg_t r) => MIR_new_reg_op(ctx, r);

    emit(MIR_MOV, R(s), MIR_new_int_op(ctx, 0));
    emit(MIR_MOV, R(i), MIR_new_int_op(ctx, 0));
    emit(MIR_BGE, MIR_new_label_op(ctx, fin), R(i), R(n));
    MIR_append_insn(ctx, item, cont);
    emit(MIR_MOV, R(tmp), MIR_new_mem_op(ctx, MIR_T_I64, 0, arr, i, 8));
    emit(MIR_ADD, R(s), R(s), R(tmp));
    emit(MIR_ADD, R(i), R(i), MIR_new_int_op(ctx, 1));
    emit(MIR_BLT, MIR_new_label_op(ctx, cont), R(i), R(n));
    MIR_append_insn(ctx, item, fin);
    emit(MIR_RET, R(s));
    MIR_finish_func(ctx);
    MIR_finish_module(ctx);

    assert(MIR_get_module_item(ctx, m, "sum") is item);
    assert(MIR_get_global_item(ctx, "sum") is item);
    assert(MIR_get_global_item(ctx, "nope") is null);

    MIR_load_module(ctx, m);
    MIR_gen_init(ctx);
    MIR_gen_set_optimize_level(ctx, 2);
    MIR_link(ctx, &MIR_set_gen_interface, null);
    auto fn = cast(SumFn) MIR_gen(ctx, item);
    MIR_gen_finish(ctx);

    long[] a = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    assert(fn(a.ptr, a.length) == 55);
    assert(fn(a.ptr, 0) == 0);          // empty: loop exits immediately
}

// Reimplemented inline predicates behave as in the header.
unittest
{
    assert(MIR_int_type_p(MIR_T_I64) && MIR_int_type_p(MIR_T_P));
    assert(!MIR_int_type_p(MIR_T_F));
    assert(MIR_fp_type_p(MIR_T_D));
    assert(MIR_call_code_p(MIR_CALL) && MIR_call_code_p(MIR_JCALL));
    assert(MIR_call_code_p(MIR_INLINE) && MIR_call_code_p(MIR_INLAY));
    assert(MIR_branch_code_p(MIR_JMP) && MIR_branch_code_p(MIR_BLT));
    assert(!MIR_branch_code_p(MIR_ADD));
}
