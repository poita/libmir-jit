/**
 * Example: JIT `long sum(long* arr, long n)` with MIR, driven from D.
 *
 * Build (standalone, against objects from scripts/build-mir.sh):
 *   ldc2 -O3 -I../source examples/sum.d $(find source -name '*.d') \
 *        .mir-build/mir.o .mir-build/mir-gen.o -of=sum
 */
module example.sum;

import std.stdio;
import mirjit;

alias SumFn = extern (C) long function(long* arr, long n) nothrow @nogc;

SumFn buildSum(MIR_context_t ctx)
{
    auto m = MIR_new_module(ctx, "m");

    MIR_type_t[1] res = [MIR_T_I64];
    MIR_var_t[2] vars = [MIR_var_t(MIR_T_P, "arr"), MIR_var_t(MIR_T_I64, "n")];
    auto item = MIR_new_func_arr(ctx, "sum", 1, res.ptr, 2, vars.ptr);
    auto func = MIR_get_item_func(ctx, item);

    auto arr = MIR_reg(ctx, "arr", func);
    auto n   = MIR_reg(ctx, "n", func);
    auto s   = MIR_new_func_reg(ctx, func, MIR_T_I64, "sum");
    auto i   = MIR_new_func_reg(ctx, func, MIR_T_I64, "i");
    auto tmp = MIR_new_func_reg(ctx, func, MIR_T_I64, "tmp");

    auto cont = MIR_new_label(ctx);
    auto fin  = MIR_new_label(ctx);

    void emit(MIR_insn_code_t code, MIR_op_t[] ops...)
    {
        MIR_append_insn(ctx, item, MIR_new_insn_arr(ctx, code, ops.length, ops.ptr));
    }
    auto reg = (MIR_reg_t r) => MIR_new_reg_op(ctx, r);
    auto imm = (long v) => MIR_new_int_op(ctx, v);

    emit(MIR_MOV, reg(s), imm(0));
    emit(MIR_MOV, reg(i), imm(0));
    emit(MIR_BGE, MIR_new_label_op(ctx, fin), reg(i), reg(n));
    MIR_append_insn(ctx, item, cont);
    emit(MIR_MOV, reg(tmp), MIR_new_mem_op(ctx, MIR_T_I64, 0, arr, i, 8));
    emit(MIR_ADD, reg(s), reg(s), reg(tmp));
    emit(MIR_ADD, reg(i), reg(i), imm(1));
    emit(MIR_BLT, MIR_new_label_op(ctx, cont), reg(i), reg(n));
    MIR_append_insn(ctx, item, fin);
    emit(MIR_RET, reg(s));

    MIR_finish_func(ctx);
    MIR_finish_module(ctx);

    MIR_load_module(ctx, m);
    MIR_gen_init(ctx);
    MIR_gen_set_optimize_level(ctx, 2);
    MIR_link(ctx, &MIR_set_gen_interface, null);
    auto code = MIR_gen(ctx, item);
    MIR_gen_finish(ctx);
    return cast(SumFn) code;
}

void main()
{
    auto ctx = MIR_init();
    scope (exit) MIR_finish(ctx);
    auto fn = buildSum(ctx);

    long[] a = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    long got = fn(a.ptr, a.length), want = 55;
    writefln("sum([1..10]) = %s (want %s) -> %s", got, want, got == want ? "OK" : "FAIL");
    assert(got == want);
}
