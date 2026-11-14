#!/usr/bin/env python3
"""Resolve the OpenMinis fork/upstream merge conflicts mechanically.

Rules:
  * .gitignore                -> keep both sides (ours + theirs)
  * project.pbxproj           -> take upstream, but keep our PRODUCT_BUNDLE_IDENTIFIER
  * MemoryManagementView.swift-> take upstream (it fixed the same bug properly)
"""
import re
import sys

CONFLICT_RE = re.compile(
    r"<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n", re.S
)


def split_sides(text):
    ours, theirs, buf, mode = [], [], [], "common"
    for line in text.splitlines(keepends=True):
        if line.startswith("<<<<<<< "):
            mode = "ours"
            continue
        if line.startswith("=======") and mode == "ours":
            mode = "theirs"
            continue
        if line.startswith(">>>>>>> ") and mode == "theirs":
            mode = "common"
            continue
        (ours if mode == "ours" else theirs if mode == "theirs" else buf).append(line)
    return buf, ours, theirs


ASSIGN_RE = re.compile(r"^(\s*)([A-Z_0-9]+) = (.*)$")


def resolve_pbxproj(text):
    def repl(m):
        ours = m.group(1).splitlines()
        theirs = m.group(2).splitlines()
        ours_map = {}
        for line in ours:
            hit = ASSIGN_RE.match(line)
            if hit and not line.rstrip().endswith("("):
                ours_map[hit.group(2)] = line
        out = []
        replaced = set()
        for line in theirs:
            hit = ASSIGN_RE.match(line)
            if hit and hit.group(2) in ours_map:
                out.append(ours_map[hit.group(2)])
                replaced.add(hit.group(2))
            else:
                out.append(line)
        for key, line in ours_map.items():
            if key not in replaced:
                out.append(line)
        return "\n".join(out) + "\n"

    return CONFLICT_RE.sub(repl, text)


def resolve_union(text):
    def repl(m):
        return m.group(1) + m.group(2)
    return CONFLICT_RE.sub(repl, text)


def resolve_theirs(text):
    def repl(m):
        return m.group(2)
    return CONFLICT_RE.sub(repl, text)


PLAN = {
    "src/ios/Minis.xcodeproj/project.pbxproj": resolve_pbxproj,
    ".gitignore": resolve_union,
    "src/ios/Views/Settings/MemoryManagementView.swift": resolve_theirs,
}

rc = 0
for path, fn in PLAN.items():
    with open(path, encoding="utf-8") as fh:
        src = fh.read()
    if "<<<<<<<" not in src:
        print(f"skip (no markers): {path}")
        continue
    out = fn(src)
    if "<<<<<<<" in out or ">>>>>>>" in out:
        print(f"FAILED still has markers: {path}")
        rc = 1
        continue
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(out)
    print(f"resolved: {path}")
sys.exit(rc)
