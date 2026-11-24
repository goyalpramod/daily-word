#!/usr/bin/env python3
"""Validate Resources/Words/*.json against docs/WORD_SCHEMA.md.

Usage: python3 scripts/validate_words.py
Exits non-zero if any entry is invalid or an id is duplicated across files.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "Resources" / "Words"
REQUIRED = ["id", "term", "kind", "partOfSpeech", "definition", "example", "etymology", "category"]
ID_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

errors, warnings = [], []
seen: dict[str, str] = {}
terms: dict[str, str] = {}
total = 0

for path in sorted(ROOT.glob("*.json")):
    try:
        entries = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        errors.append(f"{path.name}: invalid JSON: {e}")
        continue
    category = path.stem
    for i, e in enumerate(entries):
        where = f"{path.name}[{i}] {e.get('id', '?')}"
        for field in REQUIRED:
            if not e.get(field):
                errors.append(f"{where}: missing '{field}'")
        if e.get("kind") not in ("word", "phrase"):
            errors.append(f"{where}: kind must be word|phrase")
        if e.get("category") != category:
            errors.append(f"{where}: category '{e.get('category')}' != file '{category}'")
        eid = e.get("id", "")
        if not ID_RE.match(eid):
            errors.append(f"{where}: id must be lowercase ascii kebab-case")
        if eid in seen:
            errors.append(f"{where}: duplicate id (also in {seen[eid]})")
        seen[eid] = path.name
        term_key = e.get("term", "").lower()
        if term_key in terms and terms[term_key] != path.name:
            warnings.append(f"{where}: same term also in {terms[term_key]}")
        terms[term_key] = path.name
        if len(e.get("definition", "")) > 140:
            warnings.append(f"{where}: definition is long ({len(e['definition'])} chars)")
        root = e.get("root")
        if root is not None and not (isinstance(root, dict) and root.get("form")):
            errors.append(f"{where}: root must be null or have 'form'")
        for rw in e.get("relatedWords") or []:
            if not isinstance(rw, dict) or not rw.get("term"):
                errors.append(f"{where}: relatedWords items need 'term'")
        total += 1

for w in warnings:
    print("warning:", w)
for err in errors:
    print("error:", err)
print(f"{total} entries in {len(list(ROOT.glob('*.json')))} files, {len(errors)} errors, {len(warnings)} warnings")
sys.exit(1 if errors else 0)
