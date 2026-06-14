/**
 * mirjit.gen — bindings to mir-gen.h (the MIR JIT generator).
 */
module mirjit.gen;

public import mirjit.types;
import core.stdc.stdio : FILE;

extern (C) nothrow @nogc:

void MIR_gen_init(MIR_context_t ctx);
void MIR_gen_set_debug_file(MIR_context_t ctx, FILE* f);
void MIR_gen_set_debug_level(MIR_context_t ctx, int debug_level);
void MIR_gen_set_optimize_level(MIR_context_t ctx, uint level);
void* MIR_gen(MIR_context_t ctx, MIR_item_t func_item);
void MIR_set_gen_interface(MIR_context_t ctx, MIR_item_t func_item);
void MIR_set_lazy_gen_interface(MIR_context_t ctx, MIR_item_t func_item);
void MIR_set_lazy_bb_gen_interface(MIR_context_t ctx, MIR_item_t func_item);
void MIR_gen_finish(MIR_context_t ctx);
