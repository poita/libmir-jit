/**
 * mirjit.types — MIR core types, enums, and value structs.
 *
 * Hand-written D bindings to mir.h (https://github.com/vnmakarov/mir).
 * Enum values are generated from the configured header and verified against a
 * C probe; struct ABI sizes are asserted in unittests below.
 *
 * Container structs (MIR_func, MIR_item, MIR_module, MIR_insn, …) are treated
 * as opaque handles: the public API hands them back as pointers and provides
 * accessors, so their internal (macro-heavy) layout is not replicated here.
 */
module mirjit.types;

import core.stdc.stdio : FILE;
import core.stdc.stdarg : va_list;

// ---- scalar typedefs ----
alias MIR_reg_t   = uint;          /// register number (> 0)
alias MIR_alias_t = uint;          /// unique alias-name number
alias MIR_scale_t = ubyte;         /// memory index-register scale
alias MIR_disp_t  = long;          /// memory address displacement
alias MIR_name_t  = const(char)*;
alias htab_hash_t = uint;

// ---- opaque handles (used only via these pointers) ----
struct MIR_context;     alias MIR_context_t    = MIR_context*;
struct MIR_item            // concrete: layout verified by unittest
{
    void* data;
    MIR_module_t mod;            /// owning module (C field 'module')
    MIR_item_t item_link_prev;   /// DLIST_LINK(MIR_item_t).prev
    MIR_item_t item_link_next;   ///                       .next
    MIR_item_type_t item_type;
    uint _pad0;
    MIR_item_t ref_def;
    void* addr;                  /// callable address after gen+link
    char export_p;
    char section_head_p;
    char[6] _pad1;
    void* u;                     /// union {MIR_func_t func; ...} — treated opaquely
}
alias MIR_item_t = MIR_item*;
struct MIR_insn;        alias MIR_insn_t       = MIR_insn*;
alias MIR_label_t = MIR_insn_t;    /// a label is an insn
struct MIR_func;        alias MIR_func_t       = MIR_func*;
struct MIR_proto;       alias MIR_proto_t      = MIR_proto*;
struct MIR_data;        alias MIR_data_t       = MIR_data*;
struct MIR_ref_data;    alias MIR_ref_data_t   = MIR_ref_data*;
struct MIR_lref_data;   alias MIR_lref_data_t  = MIR_lref_data*;
struct MIR_expr_data;   alias MIR_expr_data_t  = MIR_expr_data*;
struct MIR_bss;         alias MIR_bss_t        = MIR_bss*;
struct MIR_alloc;       alias MIR_alloc_t      = MIR_alloc*;
struct MIR_code_alloc;  alias MIR_code_alloc_t = MIR_code_alloc*;
/// MIR_module is a public header struct; we expose its layout (verified by
/// unittest) so the module list (e.g. modules created by c2mir) can be walked.
struct MIR_module
{
    void* data;
    const(char)* name;
    MIR_item_t items_head;     /// DLIST(MIR_item_t).head
    MIR_item_t items_tail;     ///                  .tail
    MIR_module* module_prev;   /// DLIST_LINK(MIR_module_t).prev
    MIR_module* module_next;   ///                         .next
    uint last_temp_item_num;
}
alias MIR_module_t = MIR_module*;

/// DLIST(MIR_module_t) returned by MIR_get_module_list.
struct MIR_module_list { MIR_module_t head; MIR_module_t tail; }

/// Error handler: void (MIR_error_type_t, const char *fmt, ...).
alias MIR_error_func_t = extern (C) void function(MIR_error_type_t, const(char)*, ...) nothrow;

/// MIR_error_type_t
alias MIR_error_type_t = int;
enum : MIR_error_type_t
{
    MIR_no_error = 0,
    MIR_syntax_error = 1,
    MIR_binary_io_error = 2,
    MIR_alloc_error = 3,
    MIR_finish_error = 4,
    MIR_no_module_error = 5,
    MIR_nested_module_error = 6,
    MIR_no_func_error = 7,
    MIR_func_error = 8,
    MIR_vararg_func_error = 9,
    MIR_nested_func_error = 10,
    MIR_wrong_param_value_error = 11,
    MIR_hard_reg_error = 12,
    MIR_reserved_name_error = 13,
    MIR_import_export_error = 14,
    MIR_undeclared_func_reg_error = 15,
    MIR_repeated_decl_error = 16,
    MIR_reg_type_error = 17,
    MIR_wrong_type_error = 18,
    MIR_unique_reg_error = 19,
    MIR_undeclared_op_ref_error = 20,
    MIR_ops_num_error = 21,
    MIR_call_op_error = 22,
    MIR_unspec_op_error = 23,
    MIR_wrong_lref_error = 24,
    MIR_ret_error = 25,
    MIR_op_mode_error = 26,
    MIR_out_op_error = 27,
    MIR_invalid_insn_error = 28,
    MIR_ctx_change_error = 29,
}

/// MIR_insn_code_t
alias MIR_insn_code_t = int;
enum : MIR_insn_code_t
{
    MIR_MOV = 0,
    MIR_FMOV = 1,
    MIR_DMOV = 2,
    MIR_LDMOV = 3,
    MIR_EXT8 = 4,
    MIR_EXT16 = 5,
    MIR_EXT32 = 6,
    MIR_UEXT8 = 7,
    MIR_UEXT16 = 8,
    MIR_UEXT32 = 9,
    MIR_I2F = 10,
    MIR_I2D = 11,
    MIR_I2LD = 12,
    MIR_UI2F = 13,
    MIR_UI2D = 14,
    MIR_UI2LD = 15,
    MIR_F2I = 16,
    MIR_D2I = 17,
    MIR_LD2I = 18,
    MIR_F2D = 19,
    MIR_F2LD = 20,
    MIR_D2F = 21,
    MIR_D2LD = 22,
    MIR_LD2F = 23,
    MIR_LD2D = 24,
    MIR_NEG = 25,
    MIR_NEGS = 26,
    MIR_FNEG = 27,
    MIR_DNEG = 28,
    MIR_LDNEG = 29,
    MIR_ADDR = 30,
    MIR_ADDR8 = 31,
    MIR_ADDR16 = 32,
    MIR_ADDR32 = 33,
    MIR_ADD = 34,
    MIR_ADDS = 35,
    MIR_FADD = 36,
    MIR_DADD = 37,
    MIR_LDADD = 38,
    MIR_SUB = 39,
    MIR_SUBS = 40,
    MIR_FSUB = 41,
    MIR_DSUB = 42,
    MIR_LDSUB = 43,
    MIR_MUL = 44,
    MIR_MULS = 45,
    MIR_FMUL = 46,
    MIR_DMUL = 47,
    MIR_LDMUL = 48,
    MIR_DIV = 49,
    MIR_DIVS = 50,
    MIR_UDIV = 51,
    MIR_UDIVS = 52,
    MIR_FDIV = 53,
    MIR_DDIV = 54,
    MIR_LDDIV = 55,
    MIR_MOD = 56,
    MIR_MODS = 57,
    MIR_UMOD = 58,
    MIR_UMODS = 59,
    MIR_AND = 60,
    MIR_ANDS = 61,
    MIR_OR = 62,
    MIR_ORS = 63,
    MIR_XOR = 64,
    MIR_XORS = 65,
    MIR_LSH = 66,
    MIR_LSHS = 67,
    MIR_RSH = 68,
    MIR_RSHS = 69,
    MIR_URSH = 70,
    MIR_URSHS = 71,
    MIR_EQ = 72,
    MIR_EQS = 73,
    MIR_FEQ = 74,
    MIR_DEQ = 75,
    MIR_LDEQ = 76,
    MIR_NE = 77,
    MIR_NES = 78,
    MIR_FNE = 79,
    MIR_DNE = 80,
    MIR_LDNE = 81,
    MIR_LT = 82,
    MIR_LTS = 83,
    MIR_ULT = 84,
    MIR_ULTS = 85,
    MIR_FLT = 86,
    MIR_DLT = 87,
    MIR_LDLT = 88,
    MIR_LE = 89,
    MIR_LES = 90,
    MIR_ULE = 91,
    MIR_ULES = 92,
    MIR_FLE = 93,
    MIR_DLE = 94,
    MIR_LDLE = 95,
    MIR_GT = 96,
    MIR_GTS = 97,
    MIR_UGT = 98,
    MIR_UGTS = 99,
    MIR_FGT = 100,
    MIR_DGT = 101,
    MIR_LDGT = 102,
    MIR_GE = 103,
    MIR_GES = 104,
    MIR_UGE = 105,
    MIR_UGES = 106,
    MIR_FGE = 107,
    MIR_DGE = 108,
    MIR_LDGE = 109,
    MIR_ADDO = 110,
    MIR_ADDOS = 111,
    MIR_SUBO = 112,
    MIR_SUBOS = 113,
    MIR_MULO = 114,
    MIR_MULOS = 115,
    MIR_UMULO = 116,
    MIR_UMULOS = 117,
    MIR_JMP = 118,
    MIR_BT = 119,
    MIR_BTS = 120,
    MIR_BF = 121,
    MIR_BFS = 122,
    MIR_BEQ = 123,
    MIR_BEQS = 124,
    MIR_FBEQ = 125,
    MIR_DBEQ = 126,
    MIR_LDBEQ = 127,
    MIR_BNE = 128,
    MIR_BNES = 129,
    MIR_FBNE = 130,
    MIR_DBNE = 131,
    MIR_LDBNE = 132,
    MIR_BLT = 133,
    MIR_BLTS = 134,
    MIR_UBLT = 135,
    MIR_UBLTS = 136,
    MIR_FBLT = 137,
    MIR_DBLT = 138,
    MIR_LDBLT = 139,
    MIR_BLE = 140,
    MIR_BLES = 141,
    MIR_UBLE = 142,
    MIR_UBLES = 143,
    MIR_FBLE = 144,
    MIR_DBLE = 145,
    MIR_LDBLE = 146,
    MIR_BGT = 147,
    MIR_BGTS = 148,
    MIR_UBGT = 149,
    MIR_UBGTS = 150,
    MIR_FBGT = 151,
    MIR_DBGT = 152,
    MIR_LDBGT = 153,
    MIR_BGE = 154,
    MIR_BGES = 155,
    MIR_UBGE = 156,
    MIR_UBGES = 157,
    MIR_FBGE = 158,
    MIR_DBGE = 159,
    MIR_LDBGE = 160,
    MIR_BO = 161,
    MIR_UBO = 162,
    MIR_BNO = 163,
    MIR_UBNO = 164,
    MIR_CALL = 167,
    MIR_INLINE = 168,
    MIR_JCALL = 169,
    MIR_BSTART = 174,
    MIR_BEND = 175,
    MIR_PRSET = 182,
    MIR_PRBEQ = 183,
    MIR_PRBNE = 184,
    MIR_LADDR = 165,
    MIR_JMPI = 166,
    MIR_SWITCH = 170,
    MIR_RET = 171,
    MIR_JRET = 172,
    MIR_ALLOCA = 173,
    MIR_VA_ARG = 176,
    MIR_VA_BLOCK_ARG = 177,
    MIR_VA_START = 178,
    MIR_VA_END = 179,
    MIR_LABEL = 180,
    MIR_UNSPEC = 181,
    MIR_USE = 185,
    MIR_PHI = 186,
    MIR_INVALID_INSN = 187,
    MIR_INSN_BOUND = 188,
}

/// MIR_op_mode_t
alias MIR_op_mode_t = int;
enum : MIR_op_mode_t
{
    MIR_OP_UNDEF = 0,
    MIR_OP_REG = 1,
    MIR_OP_VAR = 2,
    MIR_OP_INT = 3,
    MIR_OP_UINT = 4,
    MIR_OP_FLOAT = 5,
    MIR_OP_DOUBLE = 6,
    MIR_OP_LDOUBLE = 7,
    MIR_OP_REF = 8,
    MIR_OP_STR = 9,
    MIR_OP_MEM = 10,
    MIR_OP_VAR_MEM = 11,
    MIR_OP_LABEL = 12,
    MIR_OP_BOUND = 13,
}

/// MIR_item_type_t
alias MIR_item_type_t = int;
enum : MIR_item_type_t
{
    MIR_func_item = 0,
    MIR_proto_item = 1,
    MIR_import_item = 2,
    MIR_export_item = 3,
    MIR_forward_item = 4,
    MIR_data_item = 5,
    MIR_ref_data_item = 6,
    MIR_lref_data_item = 7,
    MIR_expr_data_item = 8,
    MIR_bss_item = 9,
}

/// MIR_type_t
alias MIR_type_t = int;
enum : MIR_type_t
{
    MIR_T_I8 = 0,
    MIR_T_U8 = 1,
    MIR_T_I16 = 2,
    MIR_T_U16 = 3,
    MIR_T_I32 = 4,
    MIR_T_U32 = 5,
    MIR_T_I64 = 6,
    MIR_T_U64 = 7,
    MIR_T_F = 8,
    MIR_T_D = 9,
    MIR_T_LD = 10,
    MIR_T_P = 11,
    MIR_T_BLK = 12,
    MIR_T_RBLK = 17,
    MIR_T_UNDEF = 18,
    MIR_T_BOUND = 19,
}


// ---- manifest constants ----
enum double      MIR_API_VERSION = 0.2;
enum MIR_reg_t   MIR_MAX_REG_NUM = uint.max;
enum MIR_reg_t   MIR_NON_VAR     = uint.max;
enum int         MIR_BLK_NUM     = 5;
enum MIR_scale_t MIR_MAX_SCALE   = ubyte.max;

// ---- value structs (ABI layout asserted in unittests) ----

/// Immediate value union.
union MIR_imm_t { long i; ulong u; float f; double d; real ld; }

/// Counted string.
struct MIR_str_t { size_t len; const(char)* s; }

/// Function parameter: type + name (+ size for block types).
struct MIR_var_t
{
    MIR_type_t type;     /// MIR_T_BLK..MIR_T_RBLK only for args
    const(char)* name;
    size_t size;         /// ignored unless type is a block type
}

/// Memory operand: type[base + index*scale + disp].
struct MIR_mem_t
{
    ubyte type;          /// MIR_type_t in low 8 bits (C bitfield ': 8')
    MIR_scale_t scale;
    ubyte[2] _pad0;
    MIR_alias_t alias_;  /// C field 'alias' (D keyword)
    MIR_alias_t nonalias;
    uint nloc;           /// internal
    MIR_reg_t base;
    MIR_reg_t index;
    MIR_disp_t disp;
}

/// An instruction operand (tagged union).
struct MIR_op_t
{
    void* data;
    ubyte mode;          /// MIR_op_mode_t (C bitfield ': 8')
    ubyte value_mode;    /// MIR_op_mode_t (C bitfield ': 8')
    ubyte[2] _pad0;
    union U
    {
        MIR_reg_t reg;
        long i;
        ulong u;
        float f;
        double d;
        real ld;
        MIR_item_t ref_; /// C field 'ref' (D keyword)
        MIR_str_t str;
        MIR_mem_t mem;
        MIR_mem_t var_mem;
        MIR_label_t label;
    }
    U u;
}

/// Interpreter value union.
union MIR_val_t { MIR_insn_code_t ic; void* a; long i; ulong u; float f; double d; real ld; }

/// Code relocation entry.
struct MIR_code_reloc_t { size_t offset; const(void)* value; }

/// Argument descriptor used by the foreign-call helper.
struct _MIR_arg_desc_t { MIR_type_t type; size_t size; }

// ---- inline type/category predicates (reimplemented from mir.h) ----
pragma(inline, true) @safe @nogc nothrow pure
{
    bool MIR_int_type_p(MIR_type_t t)     { return (MIR_T_I8 <= t && t <= MIR_T_U64) || t == MIR_T_P; }
    bool MIR_fp_type_p(MIR_type_t t)      { return MIR_T_F <= t && t <= MIR_T_LD; }
    bool MIR_blk_type_p(MIR_type_t t)     { return MIR_T_BLK <= t && t <  MIR_T_RBLK; }
    bool MIR_all_blk_type_p(MIR_type_t t) { return MIR_T_BLK <= t && t <= MIR_T_RBLK; }

    bool MIR_call_code_p(MIR_insn_code_t c)
    { return c == MIR_CALL || c == MIR_INLINE || c == MIR_JCALL; }

    bool MIR_addr_code_p(MIR_insn_code_t c)
    { return c == MIR_ADDR || c == MIR_ADDR8 || c == MIR_ADDR16 || c == MIR_ADDR32; }

    bool MIR_overflow_insn_code_p(MIR_insn_code_t c)
    {
        return c == MIR_ADDO || c == MIR_ADDOS || c == MIR_SUBO || c == MIR_SUBOS
            || c == MIR_MULO || c == MIR_MULOS || c == MIR_UMULO || c == MIR_UMULOS;
    }

    bool MIR_FP_branch_code_p(MIR_insn_code_t c)
    {
        return c == MIR_FBEQ || c == MIR_DBEQ || c == MIR_LDBEQ || c == MIR_FBNE
            || c == MIR_DBNE || c == MIR_LDBNE || c == MIR_FBLT || c == MIR_DBLT
            || c == MIR_LDBLT || c == MIR_FBLE || c == MIR_DBLE || c == MIR_LDBLE
            || c == MIR_FBGT || c == MIR_DBGT || c == MIR_LDBGT || c == MIR_FBGE
            || c == MIR_DBGE || c == MIR_LDBGE;
    }

    bool MIR_int_branch_code_p(MIR_insn_code_t c)
    {
        return c == MIR_BT || c == MIR_BTS || c == MIR_BF || c == MIR_BFS || c == MIR_BEQ
            || c == MIR_BEQS || c == MIR_BNE || c == MIR_BNES || c == MIR_BLT
            || c == MIR_BLTS || c == MIR_UBLT || c == MIR_UBLTS || c == MIR_BLE
            || c == MIR_BLES || c == MIR_UBLE || c == MIR_UBLES || c == MIR_BGT
            || c == MIR_BGTS || c == MIR_UBGT || c == MIR_UBGTS || c == MIR_BGE
            || c == MIR_BGES || c == MIR_UBGE || c == MIR_UBGES || c == MIR_BO
            || c == MIR_UBO || c == MIR_BNO || c == MIR_UBNO;
    }

    bool MIR_branch_code_p(MIR_insn_code_t c)
    { return c == MIR_JMP || MIR_int_branch_code_p(c) || MIR_FP_branch_code_p(c); }

    bool MIR_any_branch_code_p(MIR_insn_code_t c)
    { return MIR_branch_code_p(c) || c == MIR_JMPI || c == MIR_SWITCH; }
}

// ---- ABI verification ----
unittest
{
    static assert(MIR_op_t.sizeof == 48, "MIR_op_t must be 48 bytes");
    static assert(MIR_mem_t.sizeof == 32, "MIR_mem_t must be 32 bytes");
    static assert(MIR_str_t.sizeof == 16, "MIR_str_t must be 16 bytes");
    static assert(MIR_reg_t.sizeof == 4 && MIR_disp_t.sizeof == 8);
    static assert(MIR_T_I64 == 6 && MIR_T_P == 11 && MIR_T_RBLK == 17);
    static assert(MIR_MOV == 0 && MIR_ADD == 34 && MIR_BGE == 154 && MIR_RET == 171);
    static assert(MIR_module.sizeof == 56, "MIR_module must be 56 bytes");
    static assert(MIR_module.module_next.offsetof == 40, "module_next at offset 40");
    static assert(MIR_item.sizeof == 72, "MIR_item must be 72 bytes");
    static assert(MIR_item.item_link_next.offsetof == 24 && MIR_item.item_type.offsetof == 32);
}
