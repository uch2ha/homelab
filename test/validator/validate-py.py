#!/usr/bin/env python3
"""Lint every .py file in the repo with ruff."""

import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def main():
    files = sorted(_find_py_files())

    if not files:
        print("ERROR: no files found")
        sys.exit(1)

    result = subprocess.run(["ruff", "check", *files], capture_output=True, text=True)
    if result.stdout:
        print(result.stdout.rstrip())
    if result.returncode != 0:
        print(f"FAILED ({result.returncode}):", file=sys.stderr)
        sys.exit(1)

    print(f"py: linted {len(files)} file(s)")


def _find_py_files():
    files: list[str] = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        for name in filenames:
            if name.endswith(".py"):
                files.append(os.path.join(dirpath, name))
    return files


if __name__ == "__main__":
    main()
