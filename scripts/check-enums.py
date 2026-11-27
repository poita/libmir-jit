#!/usr/bin/env python3
"""Check the enum values in source/mirjit/types.d against the vendored mir.h.

Preprocesses c/mir/mir.h with the system C compiler, reads the members of each
MIR enum in declaration order, and compares them with the constants declared in
types.d. Inserting an opcode upstream shifts every later value, so run this
after updating the vendored MIR snapshot.

Usage: python3 scripts/check-enums.py   (from the repository root)
"""
import re
import subprocess
import sys

ENUMS = ["MIR_error_type_t", "MIR_insn_code_t", "MIR_op_mode_t", "MIR_item_type_t", "MIR_type_t"]


def header_enums():
    cc = subprocess.run(["cc", "-E", "-P", "-Ic/mir", "c/mir/mir.h"],
                        capture_output=True, text=True, check=True)
    result = {}
    for name in ENUMS:
        match = re.search(r"typedef enum\s*(?:\w+\s*)?\{([^}]*)\}\s*" + name + r"\s*;", cc.stdout)
        if not match:
            sys.exit(f"could not find enum {name} in mir.h")
        value = -1
        members = []
        for item in (x.strip() for x in match.group(1).split(",")):
            if not item:
                continue
            if "=" in item:
                member, expr = (y.strip() for y in item.split("=", 1))
                value = int(expr) if expr.isdigit() else eval(expr, {}, dict(members))
            else:
                member = item
                value += 1
            members.append((member, value))
        result[name] = members
    return result


def main():
    source = open("source/mirjit/types.d").read()
    d_values = {m.group(1): int(m.group(2))
                for m in re.finditer(r"\b(MIR_[A-Za-z0-9_]+)\s*=\s*(-?\d+),", source)}
    problems = 0
    for enum, members in header_enums().items():
        for member, value in members:
            if member not in d_values:
                print(f"{enum}: {member} = {value} is missing from types.d")
                problems += 1
            elif d_values[member] != value:
                print(f"{enum}: {member} is {value} in mir.h but {d_values[member]} in types.d")
                problems += 1
    print(f"{sum(len(m) for m in header_enums().values())} enum members checked, {problems} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
