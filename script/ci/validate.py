#!/usr/bin/env python3
"""CI validation for the homelab repo.

Runs repo-specific sanity checks that generic linters cannot:
  1. Orchestration config (start-config.yaml) vs. actual service dirs
  2. Glance $include: references resolve to real files
  3. Env var consistency: ${VAR} used in compose/widgets is documented in .env.example
  4. Service-dir completeness: docker-compose <-> .env.example pairing
  5. Network consistency: external homelab_* networks (network_mode: host allowed)

Exit code is non-zero if any check fails.
"""

import os
import re
import subprocess
import sys

import yaml

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GITIGNORED = {"private"}

ERRORS = []


def err(message):
    ERRORS.append(message)
    print(f"ERROR: {message}", file=sys.stderr)


def tracked_paths():
    """All files that would be present on a fresh checkout (excl. .git)."""
    result = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d != ".git"]
        for name in filenames:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, ROOT)
            if rel.split(os.sep)[0] in GITIGNORED:
                continue
            result.append(full)
    return result


def find_files(pattern_re, suffix=()):
    files = []
    for full in tracked_paths():
        if pattern_re.match(full):
            files.append(full)
    return files


def compose_files():
    return find_files(re.compile(r".*docker-compose\.ya?ml$"))


def service_dirs():
    dirs = set()
    for f in compose_files():
        dirs.add(os.path.relpath(os.path.dirname(f), ROOT))
    return dirs


# ---------------------------------------------------------------- orchestration
def check_orchestration():
    config = os.path.join(ROOT, "script", "container", "config", "start-config.yaml")
    parser = os.path.join(
        ROOT, "script", "container", "lib", "parse_start_config.py"
    )
    if not os.path.exists(config) or not os.path.exists(parser):
        err("orchestration: missing start-config.yaml or parse_start_config.py")
        return

    available = sorted(service_dirs())
    try:
        proc = subprocess.run(
            [sys.executable, parser, config],
            input="\n".join(available),
            text=True,
            capture_output=True,
        )
    except subprocess.SubprocessError as e:
        err(f"orchestration: could not run parser: {e}")
        return

    if proc.returncode != 0:
        for line in proc.stderr.strip().splitlines():
            err(f"orchestration: {line}")
        return

    count = len([line for line in proc.stdout.splitlines() if line]) - 1
    print(f"ok: orchestration selected {count} service(s)")


# ---------------------------------------------------------------- glance includes
INCLUDE_KEY = "$include"


def walk_includes(node, visitor):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == INCLUDE_KEY:
                visitor(str(v))
            else:
                walk_includes(v, visitor)
    elif isinstance(node, list):
        for item in node:
            walk_includes(item, visitor)


def check_glance_includes():
    base = os.path.join(ROOT, "tool", "glance")
    if not os.path.isdir(base):
        return

    seen = set()

    def resolve(base_dir, include):
        target = os.path.normpath(os.path.join(base_dir, include))
        rel = os.path.relpath(target, ROOT)
        if rel in seen:
            return
        seen.add(rel)
        if not os.path.isfile(target):
            err(f"glance: $include '{include}' (from {base_dir}) does not exist")
            return
        try:
            with open(target) as f:
                data = yaml.safe_load(f)
        except yaml.YAMLError as e:
            err(f"glance: cannot parse {rel}: {e}")
            return
        walk_includes(data, lambda inc: resolve(os.path.dirname(target), inc))

    for f in compose_like_glance(base):
        try:
            with open(f) as fh:
                data = yaml.safe_load(fh)
        except yaml.YAMLError as e:
            err(f"glance: cannot parse {f}: {e}")
            continue
        walk_includes(data, lambda inc: resolve(os.path.dirname(f), inc))

    print(f"ok: glance $include references ({len(seen)} files) resolve")


def compose_like_glance(base):
    files = []
    for dirpath, _, filenames in os.walk(base):
        for name in filenames:
            if name.endswith((".yaml", ".yml")):
                files.append(os.path.join(dirpath, name))
    return files


# ---------------------------------------------------------------- env var consistency
VAR_RE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?:[-:+?][^}]*)?\}")


def extract_vars(text):
    return set(VAR_RE.findall(text))


def read_env_example_keys(path):
    if not os.path.isfile(path):
        return None
    keys = set()
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[len("export "):].strip()
            m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*=", line)
            if m:
                keys.add(m.group(1))
    return keys


def check_env_vars():
    checked = 0

    for full in compose_files():
        d = os.path.dirname(full)
        rel = os.path.relpath(d, ROOT)
        env_example = os.path.join(d, ".env.example")
        keys = read_env_example_keys(env_example)
        if keys is None:
            continue  # dir completeness check covers the missing file
        with open(full) as f:
            used = extract_vars(f.read())
        used -= {"VERSION"}
        missing = used - keys
        if missing:
            for v in sorted(missing):
                err(f"env: {rel}/docker-compose.yaml uses ${v} not in .env.example")
        checked += 1

    glance_base = os.path.join(ROOT, "tool", "glance")
    if os.path.isdir(glance_base):
        env_example = os.path.join(glance_base, ".env.example")
        keys = read_env_example_keys(env_example)
        if keys is not None:
            used = set()
            for f in compose_like_glance(glance_base):
                with open(f) as fh:
                    used |= extract_vars(fh.read())
            missing = used - keys
            for v in sorted(missing):
                err(f"env: glance files use ${v} not in .env.example")
            checked += 1

    print(f"ok: env var consistency checked across {checked} locations")


# ---------------------------------------------------------------- dir completeness
def check_dir_completeness():
    comp = set(os.path.dirname(f) for f in compose_files())
    env_ex = {
        os.path.dirname(f)
        for f in tracked_paths()
        if os.path.basename(f) == ".env.example"
    }
    for d in sorted(comp - env_ex):
        err(f"completeness: {os.path.relpath(d, ROOT)} has compose but no .env.example")
    for d in sorted(env_ex - comp):
        err(f"completeness: {os.path.relpath(d, ROOT)} has .env.example but no compose")
    print("ok: service-dir completeness")


# ---------------------------------------------------------------- networks
def check_networks():
    for full in compose_files():
        with open(full) as f:
            try:
                data = yaml.safe_load(f)
            except yaml.YAMLError as e:
                err(f"networks: cannot parse {full}: {e}")
                continue

        services = data.get("services") or {}
        uses_host = any(
            svc.get("network_mode") == "host" for svc in services.values()
        )
        if uses_host:
            continue

        nets = data.get("networks") or {}
        if not nets:
            err(f"networks: {os.path.relpath(full, ROOT)} declares no networks")
            continue

        for name, spec in nets.items():
            if not name.startswith("homelab_"):
                err(f"networks: {os.path.relpath(full, ROOT)}: '{name}' not homelab_*")
            if not (isinstance(spec, dict) and spec.get("external")):
                err(
                    f"networks: {os.path.relpath(full, ROOT)}: '{name}' not external: true"
                )
    print("ok: network consistency")


def main():
    check_orchestration()
    check_glance_includes()
    check_env_vars()
    check_dir_completeness()
    check_networks()

    if ERRORS:
        print(f"\nFAILED with {len(ERRORS)} error(s)", file=sys.stderr)
        sys.exit(1)
    print("\nAll homelab checks passed")


if __name__ == "__main__":
    main()
