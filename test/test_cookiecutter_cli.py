"""Tests that exercise the cookiecutter CLI using replay files.

Two tests are provided:
- `test_cookiecutter_replay_fails`: creates an invalid replay file (missing the
  top-level "cookiecutter" key) and asserts that running cookiecutter with
  `--replay-file` exits with a positive (non-zero) return code.
- `test_cookiecutter_replay_succeeds`: creates a valid replay file with the
  expected `cookiecutter` mapping and asserts that cookiecutter returns 0.

Both tests run cookiecutter via `python -m cookiecutter` so the same Python
interpreter is used. The generated project is written to a temporary output
directory (so the repository is not modified).
"""

from pathlib import Path
import json
import subprocess
from test.test_utils import (
    REPO_ROOT,
    default_replay_context,
    write_replay,
    prepare_env,
    run_cookiecutter_with_replay,
    read_generated_dtx,
)


def test_cookiecutter_replay_fails(tmp_path: Path):
    """Run cookiecutter with an invalid replay file and expect a non-zero exit.

    The invalid replay file lacks the required top-level 'cookiecutter' key,
    which should cause cookiecutter to error when loading the replay file.
    """
    replay = tmp_path / "invalid_replay.json"
    replay.write_text(json.dumps({}))
    output_dir = tmp_path / "out_fail"
    output_dir.mkdir()

    env = prepare_env(tmp_path)
    try:
        proc = run_cookiecutter_with_replay(replay, output_dir, env=env)
        assert (
            proc.returncode > 0
        ), "Expected cookiecutter to exit with a non-zero return code"
    finally:
        if output_dir.exists():
            import shutil

            shutil.rmtree(output_dir)


def test_cookiecutter_replay_succeeds(tmp_path: Path):
    """Run cookiecutter with a valid replay file and expect success (rc == 0).

    The replay JSON mirrors the keys present in `cookiecutter.json` so the
    template can render without interactive prompts.
    """
    # Minimal valid context based on repository's cookiecutter.json
    valid_context = {
        "cookiecutter": {
            "quiz_number": 1,
            "exam_code": "q01",
            "exam_name": "Quiz 1",
            "exam_date": "2025-10-31",
            "course_name": "",
            "instructor_name": "",
            "term_name": "",
            "site_id": "",
            "number_copies": 45,
            "use_nyu_fonts": False,
            "has_versions": False,
            "versions_csv": "",
            "versions_with_solutions": "",
            "version_randomization_groups": "",
            "bundle_name": "",
            "install_dir": "",
            "_extensions": [
                "local_extensions.localize_date",
                "local_extensions.embrace",
            ],
        }
    }

    replay = write_replay(tmp_path, valid_context, name="valid_replay.json")
    output_dir = tmp_path / "out_success"
    output_dir.mkdir()

    env = prepare_env(tmp_path)
    try:
        proc = run_cookiecutter_with_replay(replay, output_dir, env=env)
        if proc.returncode != 0:
            print("--- cookiecutter stdout ---")
            print(proc.stdout)
            print("--- cookiecutter stderr ---")
            print(proc.stderr)
        assert (
            proc.returncode == 0
        ), "Expected cookiecutter to succeed (return code 0) with a valid replay file"
    finally:
        if output_dir.exists():
            import shutil

            shutil.rmtree(output_dir)


def test_cookiecutter_replay_versions_with_solutions(tmp_path: Path):
    """Run cookiecutter with a replay file that enables versions and
    specifies which versions should include solution files.

    This ensures cookiecutter doesn't choke when `has_versions` is true and
    `versions_with_solutions` is provided in the replay context.
    """
    valid_context = {
        "cookiecutter": {
            "quiz_number": 1,
            "exam_code": "q01",
            "exam_name": "Quiz 1",
            "exam_date": "2025-10-31",
            "course_name": "",
            "instructor_name": "",
            "term_name": "",
            "site_id": "",
            "number_copies": 45,
            "use_nyu_fonts": False,
            "has_versions": True,
            "versions_csv": "A,B,C",
            "versions_with_solutions": "A,B",
            "version_randomization_groups": "",
            "bundle_name": "",
            "install_dir": "",
            "_extensions": [
                "local_extensions.localize_date",
                "local_extensions.embrace",
            ],
        }
    }

    replay = write_replay(tmp_path, valid_context, name="valid_replay_versions.json")
    output_dir = tmp_path / "out_success_versions"
    output_dir.mkdir()

    env = prepare_env(tmp_path)
    try:
        proc = run_cookiecutter_with_replay(replay, output_dir, env=env)
        if proc.returncode != 0:
            print("--- cookiecutter stdout ---")
            print(proc.stdout)
            print("--- cookiecutter stderr ---")
            print(proc.stderr)
        assert (
            proc.returncode == 0
        ), "Expected cookiecutter to succeed (return code 0) with versions_with_solutions provided"

        # Inspect the generated project to ensure the template honored
        # `versions_with_solutions`. The generated project should contain
        # a `q01.dtx` (exam_code + .dtx). Verify that docstrip markers for
        # versions A and B include solutions, and C does not.
        gen_dir = output_dir / "q01"
        assert gen_dir.exists(), f"generated directory not found: {gen_dir}"

        dtx_txt = read_generated_dtx(gen_dir, exam_code="q01")

        # docstrip markers look like: %<A&questions&solutions> or similar
        assert "%<A&questions&solutions" in dtx_txt
        assert "%<B&questions&solutions" in dtx_txt
        # Version C should not have a solutions marker
        assert "%<C&questions&solutions" not in dtx_txt
    finally:
        if output_dir.exists():
            import shutil

            shutil.rmtree(output_dir)
