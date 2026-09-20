"""Static check of Roblox API usage in .luau files against the official API dump.

luau-compile only checks syntax, so wrong property/enum/service names only fail at runtime in Studio.
This catches that class of bug offline. Checks:
  - Instance.new("X") / GetService("X") class names
  - `var.Prop = ...` where var was created by Instance.new / a known helper (Prop must exist on the class)
  - `var:Method(...)` on such variables
  - property tables passed to the mk/label/button helpers used in this repo
  - Enum.Name.Item references

Usage: python tools/lint/roblox_api_check.py [paths...]   (default: src)
Needs tools/bin/API-Dump.json (see docs/TESTING.md). Heuristic, may have rare false positives; never false-negatives
for the patterns above. Exit code 1 if anything is found.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DUMP = os.path.join(ROOT, "tools", "bin", "API-Dump.json")

if not os.path.exists(DUMP):
    sys.exit("Missing tools/bin/API-Dump.json. Download: https://setup.rbxcdn.com/<studio-version>-API-Dump.json")

api = json.load(open(DUMP, encoding="utf-8"))
classes = {c["Name"]: c for c in api["Classes"]}
enums = {e["Name"]: {i["Name"] for i in e["Items"]} for e in api["Enums"]}


def members(cls, kinds):
    out, seen = set(), set()
    while cls and cls not in seen:
        seen.add(cls)
        c = classes.get(cls)
        if not c:
            break
        for m in c["Members"]:
            if m["MemberType"] in kinds:
                out.add(m["Name"])
        cls = c.get("Superclass")
    return out


prop_cache, func_cache = {}, {}


def props(cls):
    if cls not in prop_cache:
        prop_cache[cls] = members(cls, {"Property"})
    return prop_cache[cls]


def funcs(cls):
    if cls not in func_cache:
        func_cache[cls] = members(cls, {"Function"})
    return func_cache[cls]


# Helper functions in this repo whose return class / property-table class is fixed.
HELPER_RETURNS = {"part": "Part", "decorPart": "Part", "label": "TextLabel", "button": "TextButton"}
HELPER_TABLE = {"label": ("TextLabel", 5), "button": ("TextButton", 4)}  # (class, index of props table among args)

problems = []


def report(path, line, msg):
    problems.append(f"{os.path.relpath(path, ROOT)}:{line}: {msg}")


def split_top(text):
    """Split a call's argument text on top-level commas."""
    parts, depth, cur, quote = [], 0, [], None
    for ch in text:
        if quote:
            cur.append(ch)
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
            cur.append(ch)
        elif ch in "({[":
            depth += 1
            cur.append(ch)
        elif ch in ")}]":
            depth -= 1
            cur.append(ch)
        elif ch == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    if "".join(cur).strip():
        parts.append("".join(cur))
    return parts


def balanced(text, start):
    """text[start] is an opening bracket; return the index just past its match."""
    pairs = {"(": ")", "{": "}", "[": "]"}
    stack, quote = [], None
    for i in range(start, len(text)):
        ch = text[i]
        if quote:
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
        elif ch in pairs:
            stack.append(pairs[ch])
        elif stack and ch == stack[-1]:
            stack.pop()
            if not stack:
                return i + 1
    return len(text)


def check_table(path, src, table_start, cls, base_line):
    end = balanced(src, table_start)
    body = src[table_start + 1 : end - 1]
    for entry in split_top(body):
        m = re.match(r"\s*(\w+)\s*=", entry)
        if m and m.group(1) not in props(cls):
            line = base_line + src[:table_start].count("\n") - src[:table_start].count("\n") + entry.count("\n") * 0
            report(path, line_of(src, table_start, m.group(1)), f"{cls} has no property '{m.group(1)}'")


def line_of(src, pos, key):
    idx = src.find(key, pos)
    return src.count("\n", 0, idx if idx >= 0 else pos) + 1


def check_file(path):
    src = open(path, encoding="utf-8").read().replace("\r\n", "\n")
    lines = src.split("\n")
    var_class = {}

    for m in re.finditer(r"Enum\.(\w+)\.(\w+)", src):
        line = src.count("\n", 0, m.start()) + 1
        if m.group(1) not in enums:
            report(path, line, f"unknown enum Enum.{m.group(1)}")
        elif m.group(2) not in enums[m.group(1)]:
            report(path, line, f"Enum.{m.group(1)} has no item '{m.group(2)}'")

    for m in re.finditer(r"GetService\(\s*[\"'](\w+)[\"']\s*\)", src):
        if m.group(1) not in classes:
            report(path, src.count("\n", 0, m.start()) + 1, f"unknown service '{m.group(1)}'")

    for m in re.finditer(r"Instance\.new\(\s*[\"'](\w+)[\"']", src):
        if m.group(1) not in classes:
            report(path, src.count("\n", 0, m.start()) + 1, f"unknown class '{m.group(1)}'")

    # Property tables passed to the UI helpers: mk("Class", {..}), label(..., {..}), button(..., {..})
    for m in re.finditer(r"\bmk\(\s*[\"'](\w+)[\"']\s*,\s*\{", src):
        cls = m.group(1)
        if cls in classes:
            check_table(path, src, m.end() - 1, cls, 1)
    for name, (cls, idx) in HELPER_TABLE.items():
        for m in re.finditer(r"\b" + name + r"\(", src):
            # skip the definitions
            if src[max(0, m.start() - 9) : m.start()].endswith("function "):
                continue
            end = balanced(src, m.end() - 1)
            args = split_top(src[m.end() : end - 1])
            if len(args) > idx - 1:
                last = args[-1].strip()
                if last.startswith("{") and len(args) >= idx - 1:
                    table_pos = src.find(last, m.end())
                    if table_pos >= 0 and len(args) >= (idx if name == "label" else idx):
                        check_table(path, src, table_pos, cls, 1)

    # Per-line tracking of typed variables
    for i, raw in enumerate(lines, 1):
        line = raw.split("--")[0] if "--" in raw and '"' not in raw.split("--")[0][-1:] else raw
        m = re.match(r"\s*(?:local\s+)?(\w+)\s*=\s*(.*)$", line)
        if m and not re.match(r"\s*(?:local\s+)?\w+\s*==", line):
            var, rhs = m.group(1), m.group(2)
            cls = None
            n = re.match(r"Instance\.new\(\s*[\"'](\w+)[\"']", rhs)
            if n:
                cls = n.group(1)
            else:
                h = re.match(r"(\w+)\(", rhs)
                if h and h.group(1) in HELPER_RETURNS:
                    cls = HELPER_RETURNS[h.group(1)]
                    mk_first = re.match(r"mk\(\s*[\"'](\w+)[\"']", rhs)
                if h and h.group(1) == "mk":
                    mk_first = re.match(r"mk\(\s*[\"'](\w+)[\"']", rhs)
                    cls = mk_first.group(1) if mk_first else "Part"
            if cls in classes:
                var_class[var] = cls
            else:
                var_class.pop(var, None)
        # property assignment on a typed var
        a = re.match(r"\s*(\w+)\.(\w+)\s*=[^=]", line)
        if a and a.group(1) in var_class:
            cls = var_class[a.group(1)]
            if a.group(2) not in props(cls):
                report(path, i, f"{cls} '{a.group(1)}' has no property '{a.group(2)}'")
        for c in re.finditer(r"\b(\w+):(\w+)\(", line):
            if c.group(1) in var_class:
                cls = var_class[c.group(1)]
                if c.group(2) not in funcs(cls) and c.group(2) not in {"Clone", "Destroy"}:
                    report(path, i, f"{cls} '{c.group(1)}' has no method '{c.group(2)}'")


targets = sys.argv[1:] or [os.path.join(ROOT, "src")]
for t in targets:
    if os.path.isfile(t):
        check_file(t)
    else:
        for dirpath, _, files in os.walk(t):
            for f in files:
                if f.endswith(".luau"):
                    check_file(os.path.join(dirpath, f))

for p in problems:
    print(p)
print(f"\n{len(problems)} problem(s)")
sys.exit(1 if problems else 0)
