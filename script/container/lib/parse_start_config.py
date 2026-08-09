#!/usr/bin/env python3
import sys

import yaml


def validate_config_value_types(action, base, groups):
    if not action:
        print("ERROR: 'action' is missing or empty", file=sys.stderr)
        sys.exit(1)

    if not isinstance(base, list):
        print("ERROR: 'base' must be a list", file=sys.stderr)
        sys.exit(1)

    if not isinstance(groups, dict) or not groups:
        print("ERROR: 'groups' section is missing or empty", file=sys.stderr)
        sys.exit(1)


def validate_base_values(base):
    for entry in base:
        if not entry.endswith("/*"):
            continue

        prefix = entry[:-2]
        for other in base:
            if other.startswith(prefix + "/") and other != entry:
                print(
                    f"ERROR: base has '{entry}' and '{other}' — '{entry}' already covers all '{prefix}/' services",
                    file=sys.stderr,
                )
                sys.exit(1)


def generate_group_selected_list(groups: dict):
    group_selected_list = set()

    for name, group in groups.items():
        if not isinstance(group, dict):
            print(f'ERROR: group "{name}" is not a mapping', file=sys.stderr)
            sys.exit(1)

        path = group.get("path")
        value = group.get("value")
        presets = group.get("presets") or {}

        if not path:
            print(f'ERROR: group "{name}" missing "path"', file=sys.stderr)
            sys.exit(1)

        if (
            value is None
            or value == ""
            or (isinstance(value, str) and value.lower() == "none")
        ):
            continue

        if value == "all":
            for _, services in presets.items():
                for s in services or []:
                    group_selected_list.add(f"{path}/{s}")
            continue

        if value not in presets:
            known = ", ".join(presets) if presets else "(none)"
            print(
                f'ERROR: group "{name}": preset "{value}" not found (known: {known})',
                file=sys.stderr,
            )
            sys.exit(1)

        for s in presets[value] or []:
            group_selected_list.add(f"{path}/{s}")

    return group_selected_list


def validate_selected_groups_against_base(group_selected_list: set, base: list):
    for entry in base:
        if entry.endswith("/*"):
            prefix = entry[:-2]
            for g in group_selected_list:
                if g.startswith(prefix + "/") and "/" not in g[len(prefix) + 1 :]:
                    print(
                        f"ERROR: service '{g}' is in both base (via '{entry}') and a group",
                        file=sys.stderr,
                    )
                    sys.exit(1)
        else:
            if entry in group_selected_list:
                print(
                    f"ERROR: service '{entry}' is in both base and a group",
                    file=sys.stderr,
                )
                sys.exit(1)


def select_services_from_base(available: set, base: list, selected: set):
    for entry in base:
        if entry.endswith("/*"):
            prefix = entry[:-2]
            for d in available:
                if d.startswith(prefix + "/") and "/" not in d[len(prefix) + 1 :]:
                    selected.add(d)
        else:
            if entry not in available:
                print(f"ERROR: base service not found: {entry}", file=sys.stderr)
                sys.exit(1)
            selected.add(entry)


def select_services_from_groups(
    available: set, group_selected_list: set, selected: set
):
    for full in group_selected_list:
        if full not in available:
            print(
                f"ERROR: group service not found: {full}",
                file=sys.stderr,
            )
            sys.exit(1)
        selected.add(full)


def main():
    config_path = sys.argv[1]
    with open(config_path) as f:
        cfg = yaml.safe_load(f)

    available = {line.strip() for line in sys.stdin if line.strip()}

    action = cfg.get("action", "")
    base = cfg.get("base", [])
    groups = cfg.get("groups")

    validate_config_value_types(action, base, groups)
    validate_base_values(base)

    group_selected_list = generate_group_selected_list(groups)
    validate_selected_groups_against_base(group_selected_list, base)

    selected = set()

    select_services_from_base(available, base, selected)
    select_services_from_groups(available, group_selected_list, selected)

    if not selected:
        print(
            "ERROR: no services selected — check base/groups in config", file=sys.stderr
        )
        sys.exit(1)

    # stdout
    print(action)
    for d in sorted(selected):
        print(d)


if __name__ == "__main__":
    main()
