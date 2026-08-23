#!/usr/bin/env python3
"""Re-apply Fleet's renames after merging upstream cmux.

Upstream keeps adding strings and subcommands that say "cmux". Merging brings
them in verbatim, so this runs after every sync:

    git merge origin/main
    python3 scripts/apply-fleet-branding.py        # rewrite
    python3 scripts/apply-fleet-branding.py --check # report only, exits 1 if work remains

It is idempotent: text already saying Fleet is left alone, so running it twice
changes nothing.

Two passes:

1. Product name in user-facing text — every localization in
   Resources/Localizable.xcstrings plus the Swift `defaultValue:` fallbacks. Both
   halves must move together, or English reads Fleet while Japanese reads cmux.

2. Command name in CLI help text — `cmux <subcommand>` becomes `fleet
   <subcommand>`. The subcommand list is extracted from the actual switch cases
   rather than hardcoded, so subcommands upstream adds later are covered too.

Two regex traps live here, both of which the obvious pattern gets wrong:

  * Excluding a trailing [./:@-] to protect "cmux.com" also skips a
    sentence-final "cmux." — which is how a stale "Notifications are disabled for
    cmux." survived a whole rename pass.
  * `\\bcmux\\b` silently misses "cmuxは" and "cmux에서": Python counts kana and
    Hangul as word characters, so the boundary never matches. Every CJK
    translation would keep the old name.

The working approach substitutes protected strings out first, then matches the
bare name excluding ASCII-suffixed identifiers (which spares cmuxterm,
cmuxd-remote, cmux_port).
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Strings that must keep the upstream name.
#   cmux.com / manaflow-ai/cmux : upstream's site and repo
#   cmux://                     : deep-link scheme upstream owns
#   .cmux/                      : in-repo config convention shared with cmux
#   cmuxd-remote                : remote daemon binary name
#   CMUX_*, cmux_*              : environment variables and identifiers
PROTECTED = ("cmux.com", "manaflow-ai/cmux", "cmux://", ".cmux/", "cmuxd-remote")

# Keys whose value is upstream's license name, not a product reference.
SKIP_KEY_PREFIXES = ("about.licenses",)

BRAND = re.compile(r"cmux(?![A-Za-z0-9_])")
DEFAULT_VALUE = re.compile(r'(defaultValue: ")((?:[^"\\]|\\.)*)(")')


def rebrand(text: str) -> str:
    """Replace the bare product name, leaving protected strings untouched."""
    holds = {}
    out = text
    for index, pattern in enumerate(PROTECTED):
        if pattern in out:
            token = f"\x00{index}\x00"
            holds[token] = pattern
            out = out.replace(pattern, token)
    out = BRAND.sub("Fleet", out)
    for token, pattern in holds.items():
        out = out.replace(token, pattern)
    return out


def rebrand_catalog(check: bool) -> int:
    path = REPO / "Resources/Localizable.xcstrings"
    data = json.loads(path.read_text())
    changed = 0
    for key, entry in data["strings"].items():
        if any(key.startswith(prefix) for prefix in SKIP_KEY_PREFIXES):
            continue
        for payload in entry.get("localizations", {}).values():
            unit = payload.get("stringUnit")
            if not unit or "cmux" not in unit.get("value", ""):
                continue
            new = rebrand(unit["value"])
            if new != unit["value"]:
                changed += 1
                if not check:
                    unit["value"] = new
    if changed and not check:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    return changed


def rebrand_swift_defaults(check: bool) -> int:
    changed = 0
    for root in ("Sources", "Packages", "CLI"):
        for file in (REPO / root).rglob("*.swift"):
            text = file.read_text()
            if "defaultValue:" not in text or "cmux" not in text:
                continue
            hits = 0

            def fix(match):
                nonlocal hits
                body = match.group(2)
                if "cmux" not in body:
                    return match.group(0)
                new_body = rebrand(body)
                if new_body != body:
                    hits += 1
                return match.group(1) + new_body + match.group(3)

            new = DEFAULT_VALUE.sub(fix, text)
            changed += hits
            if hits and not check:
                file.write_text(new)
    return changed


def subcommands() -> list[str]:
    """Real subcommands, from the switch cases that dispatch them."""
    out = subprocess.run(
        ["grep", "-ohE", r'case "[a-z][a-z0-9-]{1,24}"(, "[a-z][a-z0-9-]{1,24}")*:']
        + [str(p) for p in (REPO / "CLI").glob("*.swift")],
        capture_output=True,
        text=True,
    ).stdout
    names = set(re.findall(r'"([a-z][a-z0-9-]{1,24})"', out))
    # Only names that actually appear as "cmux <name>" in help text, so English
    # prose like "cmux always ..." is not mangled into a command invocation.
    used = set()
    for root in ("CLI", "Sources"):
        for file in (REPO / root).rglob("*.swift"):
            used.update(re.findall(r"\bcmux ([a-z][a-z0-9-]+)", file.read_text()))
    return sorted(names & used, key=len, reverse=True)


def rebrand_commands(check: bool) -> int:
    names = subcommands()
    if not names:
        return 0
    pattern = re.compile(r"\bcmux (" + "|".join(re.escape(n) for n in names) + r")\b")
    changed = 0
    for root in ("CLI", "Sources"):
        for file in (REPO / root).rglob("*.swift"):
            text = file.read_text()
            if "cmux " not in text:
                continue
            new, hits = pattern.subn(r"fleet \1", text)
            changed += hits
            if hits and not check:
                file.write_text(new)
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report without writing")
    args = parser.parse_args()

    catalog = rebrand_catalog(args.check)
    swift = rebrand_swift_defaults(args.check)
    commands = rebrand_commands(args.check)
    total = catalog + swift + commands

    verb = "would change" if args.check else "changed"
    print(f"localized values {verb}: {catalog}")
    print(f"swift defaultValue strings {verb}: {swift}")
    print(f"CLI command mentions {verb}: {commands}")

    if args.check and total:
        print(f"\n{total} rename(s) still needed — run without --check.", file=sys.stderr)
        return 1
    if not total:
        print("\nnothing to do; branding is current.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
