"""Fails when a key used as 'key'.tr in lib/ has no <string> in the XML files.

Usage: python tool/check_strings.py   (exit code 1 when keys are missing)
"""
import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
LOCALES = ("values", "values-vi")


def keys_of(locale):
    path = os.path.join(ROOT, "lib", "xml_strings", locale, "strings.xml")
    with open(path, encoding="utf8") as f:
        return set(re.findall(r'<string\s+name="([^"]+)"', f.read()))


used = set()
for f in glob.glob(os.path.join(ROOT, "lib", "**", "*.dart"), recursive=True):
    with open(f, encoding="utf8") as fh:
        s = fh.read()
    used |= {m.group(1) for m in re.finditer(r"'([a-z][a-z0-9_]*)'\.tr(Params)?\b", s)}
    # keys stored in enums/const lists and translated later (labelKey etc.)
    used |= {m.group(1) for m in re.finditer(r"(?:labelKey|titleKey|key)\s*[:=]\s*'([a-z][a-z0-9_]*)'", s)}

failed = False
for loc in LOCALES:
    have = keys_of(loc)
    missing = sorted(k for k in used if k not in have and "_" in k)
    print(f"{loc}: missing {missing}")
    failed = failed or bool(missing)
sys.exit(1 if failed else 0)
