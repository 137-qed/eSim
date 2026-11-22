#!/usr/bin/env python3
"""Merge the eSim 2.5 symbols into the active KiCad library table."""

import argparse
from pathlib import Path
import re
import tempfile


def register_symbols(table, template, installed_dir, bundled_dir):
    original = table if table.exists() else template
    content = original.read_text()
    row_names = set(re.findall(r'\(lib\s*\(name\s+"([^"]+)"\)', content))
    rows = []
    for symbol in sorted(bundled_dir.glob("eSim_*.kicad_sym")):
        if symbol.stem in row_names:
            continue
        uri = installed_dir / symbol.name
        if not uri.is_file():
            raise ValueError(f"Missing installed symbol library: {uri}")
        rows.append(
            f'  (lib (name "{symbol.stem}")(type "KiCad")(uri "{uri}")'
            '(options "")(descr "FOSSEE eSim"))\n'
        )
    if not rows:
        return
    if not content.lstrip().startswith("(sym_lib_table") or not content.rstrip().endswith(")"):
        raise ValueError(f"Invalid KiCad symbol table: {original}")
    table.parent.mkdir(parents=True, exist_ok=True)
    # Leave the old table readable until the complete replacement has been written.
    with tempfile.NamedTemporaryFile(mode="w", dir=table.parent, delete=False) as output:
        temp_path = Path(output.name)
        output.write(content.rstrip()[:-1] + "".join(rows) + ")\n")
    temp_path.replace(table)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("table", "template", "installed_dir", "bundled_dir"):
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    register_symbols(args.table, args.template, args.installed_dir, args.bundled_dir)


if __name__ == "__main__":
    main()
