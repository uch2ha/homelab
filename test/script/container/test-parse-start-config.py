#!/usr/bin/env python3
"""Unit tests for script/container/lib/parse_start_config.py."""

import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
PARSER = os.path.join(ROOT, "script", "container", "lib", "parse_start_config.py")

AVAILABLE = [
    "infrastructure/dockhand",
    "infrastructure/portainer",
    "infrastructure/zerobyte",
    "media/immich",
    "media/papra",
    "monitoring/beszel",
    "monitoring/grafana",
    "monitoring/uptime-kuma",
    "networking/pihole",
    "security/vaultwarden",
    "tool/glance",
    "tool/ntfy",
    "private/torrserver",
]


def run_parser(config, available=None):
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as fh:
        fh.write(config)
        config_path = fh.name
    try:
        proc = subprocess.run(
            [sys.executable, PARSER, config_path],
            input="\n".join(available if available is not None else AVAILABLE),
            capture_output=True,
            text=True,
        )
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    finally:
        os.unlink(config_path)


class BaseTest(unittest.TestCase):
    def assert_ok(self, config, available=None):
        code, out, err = run_parser(config, available)
        self.assertEqual(code, 0, f"expected success, stderr: {err}")
        self.assertEqual(err, "")
        return out.splitlines()

    def assert_error(self, config, available=None):
        code, out, err = run_parser(config, available)
        self.assertEqual(code, 1, "expected failure")
        self.assertEqual(out, "")
        self.assertIn("ERROR", err)
        return err


class HappyPathTests(BaseTest):
    def test_base_exact_and_wildcard(self):
        lines = self.assert_ok(
            """
            action: 'up --pull never -d'
            base:
              - infrastructure/zerobyte
              - media/*
            groups:
              docker-managment:
                path: infrastructure
                value: dockhand
                presets:
                  dockhand: [dockhand]
            """
        )
        self.assertEqual(lines[0], "up --pull never -d")
        self.assertEqual(
            set(lines[1:]),
            {
                "infrastructure/zerobyte",
                "media/immich",
                "media/papra",
                "infrastructure/dockhand",
            },
        )

    def test_group_light_picks_only_light(self):
        lines = self.assert_ok(
            """
            action: 'up --pull never -d'
            base: [tool/*]
            groups:
              monitoring:
                path: monitoring
                value: light
                presets:
                  light: [beszel]
                  high: [grafana, prometheus]
            """
        )
        self.assertIn("monitoring/beszel", lines[1:])
        self.assertNotIn("monitoring/grafana", lines[1:])

    def test_group_all_merges_presets_deduped(self):
        lines = self.assert_ok(
            """
            action: 'up --pull never -d'
            base: [tool/*]
            groups:
              monitoring:
                path: monitoring
                value: all
                presets:
                  light: [beszel]
                  high: [beszel, grafana]
            """
        )
        selected = [line for line in lines[1:] if line.startswith("monitoring/")]
        self.assertEqual(sorted(selected), ["monitoring/beszel", "monitoring/grafana"])

    def test_group_none_values_skip_group(self):
        for value in ["none", "''", "null"]:
            with self.subTest(value=value):
                lines = self.assert_ok(
                    f"""
                    action: 'up -d'
                    base: [tool/*]
                    groups:
                      monitoring:
                        path: monitoring
                        value: {value}
                        presets:
                          light: [beszel]
                    """
                )
                self.assertNotIn("monitoring/beszel", lines[1:])

    def test_no_groups_value_means_skip(self):
        lines = self.assert_ok(
            """
            action: 'up -d'
            base: [tool/*]
            groups:
              monitoring:
                path: monitoring
                presets:
                  light: [beszel]
            """
        )
        self.assertNotIn("monitoring/beszel", lines[1:])


class ErrorTests(BaseTest):
    def test_empty_action(self):
        self.assert_error(
            """
            action: ''
            base: [tool/*]
            groups:
              monitoring:
                path: monitoring
                value: light
                presets:
                  light: [beszel]
            """
        )

    def test_base_not_list(self):
        self.assert_error(
            """
            action: 'up -d'
            base: tool/*
            groups:
              monitoring:
                path: monitoring
                value: light
                presets:
                  light: [beszel]
            """
        )

    def test_groups_missing(self):
        self.assert_error(
            """
            action: 'up -d'
            base: [tool/*]
            """
        )

    def test_wildcard_overlap_in_base(self):
        self.assert_error(
            """
            action: 'up -d'
            base:
              - media/*
              - media/immich
            groups:
              monitoring:
                path: monitoring
                value: light
                presets:
                  light: [beszel]
            """
        )

    def test_unknown_preset(self):
        self.assert_error(
            """
            action: 'up -d'
            base: [tool/*]
            groups:
              monitoring:
                path: monitoring
                value: foo
                presets:
                  light: [beszel]
            """
        )

    def test_base_service_not_found(self):
        self.assert_error(
            """
            action: 'up -d'
            base: [infrastructure/missing]
            groups:
              monitoring:
                path: monitoring
                value: light
                presets:
                  light: [beszel]
            """
        )

    def test_group_service_not_found(self):
        self.assert_error(
            """
            action: 'up -d'
            base: [tool/*]
            groups:
              monitoring:
                path: monitoring
                value: light
                presets:
                  light: [missing]
            """
        )

    def test_group_not_mapping(self):
        self.assert_error(
            """
            action: 'up -d'
            base: [tool/*]
            groups:
              monitoring: foo
            """
        )

    def test_overlap_exact(self):
        self.assert_error(
            """
            action: 'up -d'
            base: [infrastructure/zerobyte]
            groups:
              infra:
                path: infrastructure
                value: backup
                presets:
                  backup: [zerobyte]
            """
        )

    def test_overlap_wildcard(self):
        self.assert_error(
            """
            action: 'up -d'
            base: [media/*]
            groups:
              photos:
                path: media
                value: immich
                presets:
                  immich: [immich]
            """
        )

    def test_nothing_selected(self):
        self.assert_error(
            """
            action: 'up -d'
            base: [tool/glance]
            groups:
              monitoring:
                path: monitoring
                value: none
                presets:
                  light: [beszel]
            """,
            available=["monitoring/beszel"],
        )


if __name__ == "__main__":
    unittest.main()
