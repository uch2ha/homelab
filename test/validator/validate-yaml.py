#!/usr/bin/env python3
"""Validate that every tracked .yaml/.yml file in the repo parses as valid YAML."""

import os
import sys

import yaml

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def main():
    files = sorted(_find_yaml_files())
    errors: list[str] = []

    if not files:
        print("ERROR: no files found")
        sys.exit(1)

    for path in files:
        try:
            with open(path) as fh:
                _ = list(yaml.safe_load_all(fh))
        except (yaml.YAMLError, OSError) as e:
            rel = os.path.relpath(path, ROOT)
            print(f"ERROR: {rel}: {e}\n\n----------\n", file=sys.stderr)
            errors.append(rel)

    print(f"yaml: validated {len(files)} file(s)")
    if errors:
        print(f"FAILED ({len(errors)}):", file=sys.stderr)
        for rel in errors:
            print(f"  - {rel}", file=sys.stderr)
        sys.exit(1)


def _find_yaml_files():
    files: list[str] = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        for name in filenames:
            if name.endswith((".yaml", ".yml")):
                files.append(os.path.join(dirpath, name))
    return files


if __name__ == "__main__":
    main()
