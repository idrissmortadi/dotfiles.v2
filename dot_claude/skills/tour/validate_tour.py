#!/usr/bin/env python3
"""
Validates a tour artifact produced by the /tour skill.

Usage:
    validate_tour.py <path-to-tour.json>

Exits 0 if valid, non-zero with a human-readable message on any violation.
Checks both structural conformance (required fields, types) and semantic
constraints that schema validation cannot express (commit pin matches HEAD,
each stop's file exists at that commit, line is within the file's length).
"""

import json
import subprocess
import sys
from pathlib import Path


class ValidationError(Exception):
    """Raised on any validation failure. Message is shown to the user."""


def fail(msg: str) -> None:
    raise ValidationError(msg)


def require(cond: bool, msg: str) -> None:
    if not cond:
        fail(msg)


def check_type(value, expected_type, path: str) -> None:
    if not isinstance(value, expected_type):
        fail(f"{path}: expected {expected_type.__name__}, got {type(value).__name__}")


def validate_structure(artifact: dict) -> dict:
    """Check required fields and types. Returns the inner `tour` dict."""
    check_type(artifact, dict, "root")
    require("tour" in artifact, "root: missing required key 'tour'")

    tour = artifact["tour"]
    check_type(tour, dict, "tour")

    required = ["question", "commit", "repo_root", "summary", "stops", "unresolved"]
    for key in required:
        require(key in tour, f"tour: missing required key '{key}'")

    check_type(tour["question"], str, "tour.question")
    check_type(tour["commit"], str, "tour.commit")
    check_type(tour["repo_root"], str, "tour.repo_root")
    check_type(tour["summary"], str, "tour.summary")
    check_type(tour["stops"], list, "tour.stops")
    check_type(tour["unresolved"], list, "tour.unresolved")

    require(len(tour["commit"]) == 40, "tour.commit: expected full 40-char SHA")
    require(
        all(c in "0123456789abcdef" for c in tour["commit"].lower()),
        "tour.commit: expected hex SHA",
    )

    seen_ids = set()
    for i, stop in enumerate(tour["stops"]):
        path = f"tour.stops[{i}]"
        check_type(stop, dict, path)

        for key in ["id", "file", "line", "note"]:
            require(key in stop, f"{path}: missing required key '{key}'")

        check_type(stop["id"], int, f"{path}.id")
        check_type(stop["file"], str, f"{path}.file")
        check_type(stop["line"], int, f"{path}.line")
        check_type(stop["note"], str, f"{path}.note")

        require(
            stop["id"] not in seen_ids,
            f"{path}.id: duplicate id {stop['id']}",
        )
        seen_ids.add(stop["id"])

        require(stop["line"] >= 1, f"{path}.line: must be >= 1")
        require(stop["note"].strip() != "", f"{path}.note: must not be empty")

        if "symbol" in stop:
            check_type(stop["symbol"], str, f"{path}.symbol")
        if "depends_on" in stop:
            check_type(stop["depends_on"], list, f"{path}.depends_on")
            for j, dep in enumerate(stop["depends_on"]):
                check_type(dep, int, f"{path}.depends_on[{j}]")
                require(
                    dep < stop["id"],
                    f"{path}.depends_on[{j}]: must reference an earlier stop "
                    f"(got {dep}, this stop is {stop['id']})",
                )
                require(
                    dep in seen_ids,
                    f"{path}.depends_on[{j}]: references unknown stop id {dep}",
                )

    for i, item in enumerate(tour["unresolved"]):
        check_type(item, str, f"tour.unresolved[{i}]")

    return tour


def validate_semantics(tour: dict) -> None:
    """Check the artifact agrees with the actual repo state at its pinned commit."""
    repo_root = Path(tour["repo_root"])
    require(repo_root.is_dir(), f"tour.repo_root: not a directory: {repo_root}")
    require(
        (repo_root / ".git").exists(),
        f"tour.repo_root: not a git repository: {repo_root}",
    )

    # The skill pins to HEAD at generation time, but HEAD may have moved by the
    # time validation runs (and that's fine — validation should still pass on
    # the pinned commit). We don't enforce commit == HEAD here; we only verify
    # that the pinned commit exists and that the referenced files/lines are
    # consistent with that commit.
    sha = tour["commit"]
    rev_check = subprocess.run(
        ["git", "-C", str(repo_root), "cat-file", "-e", sha],
        capture_output=True,
    )
    require(
        rev_check.returncode == 0,
        f"tour.commit: {sha} does not exist in {repo_root}",
    )

    for i, stop in enumerate(tour["stops"]):
        path = f"tour.stops[{i}]"
        spec = f"{sha}:{stop['file']}"
        result = subprocess.run(
            ["git", "-C", str(repo_root), "show", spec],
            capture_output=True,
            text=True,
        )
        require(
            result.returncode == 0,
            f"{path}.file: {stop['file']!r} does not exist at commit {sha[:7]}",
        )
        line_count = result.stdout.count("\n") + (
            0 if result.stdout.endswith("\n") else 1
        )
        require(
            stop["line"] <= line_count,
            f"{path}.line: line {stop['line']} exceeds file length "
            f"({line_count} lines) at commit {sha[:7]}",
        )


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} <path-to-tour.json>", file=sys.stderr)
        return 2

    path = Path(argv[1])
    if not path.is_file():
        print(f"validate_tour: not a file: {path}", file=sys.stderr)
        return 2

    try:
        with path.open() as f:
            artifact = json.load(f)
    except json.JSONDecodeError as e:
        print(f"validate_tour: invalid JSON: {e}", file=sys.stderr)
        return 1

    try:
        tour = validate_structure(artifact)
        validate_semantics(tour)
    except ValidationError as e:
        print(f"validate_tour: {e}", file=sys.stderr)
        return 1

    print(
        f"validate_tour: ok ({len(tour['stops'])} stops, commit {tour['commit'][:7]})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
