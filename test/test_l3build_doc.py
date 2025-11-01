"""Integration test: render the template and run `l3build doc` in the result.

This test does the following:
 - writes a valid replay file into the pytest tmp path
 - runs `python -m cookiecutter` to render the template into the tmp path
 - initializes a git repository and makes an initial commit in the generated
   project directory (so `vc.lua` can read git metadata)
 - runs `l3build doc --halt-on-error --show-log-on-error` inside the generated
   project and asserts it exits with code 0.

The test will be skipped if required external commands are not available.
"""
from pathlib import Path
import json
import subprocess
import os
import sys
import shutil
import pytest


REPO_ROOT = Path(__file__).resolve().parent.parent


def _check_command(name: str) -> bool:
    return shutil.which(name) is not None


@pytest.mark.skipif(not _check_command("git"), reason="git is required for this test")
@pytest.mark.skipif(not _check_command(sys.executable), reason="Python executable not found")
def test_l3build_doc_success(tmp_path: Path):
    # Ensure cookiecutter importable (we use python -m cookiecutter but still
    # guard against missing package)
    try:
        import cookiecutter  # noqa: F401
    except Exception:
        pytest.skip("cookiecutter package is not importable")

    # Create a minimal valid replay file. The template uses `exam_code` as the
    # output directory name; set it to a deterministic value.
    replay = tmp_path / "replay.json"
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
            "has_versions": False,
            "use_nyu_fonts": False,
            "versions_csv": "",
            "bundle_name": "",
            "install_dir": "",
            "_extensions": ["local_extensions.localize_date", "local_extensions.embrace"],
        }
    }
    replay.write_text(json.dumps(valid_context))

    out_dir = tmp_path / "out"
    out_dir.mkdir()

    # Run cookiecutter to render the template
    cmd = [
        sys.executable,
        "-m",
        "cookiecutter",
        str(REPO_ROOT),
        "--replay-file",
        str(replay),
        "--output-dir",
        str(out_dir),
        "--accept-hooks",
        "no",
    ]

    # Run cookiecutter and downstream commands directly in the
    # developer's environment (no test-level isolation). This keeps the
    # behavior identical to how you would run the commands locally.
    # NOTE: This test intentionally uses your real environment (HOME, PATH,
    # etc.). It will read your user config and binaries — that is the
    # intended behavior so the test mirrors your local runs.
    # Any failures will be surfaced directly.
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        pytest.fail(f"cookiecutter failed: stdout:\n{proc.stdout}\nstderr:\n{proc.stderr}")

    gen_dir = out_dir / "q01"
    assert gen_dir.exists(), f"generated directory not found: {gen_dir}"

    try:
        # Init git so vc.lua can get metadata
        subprocess.run(["git", "init"], cwd=str(gen_dir), check=True)
        subprocess.run(["git", "add", "-A"], cwd=str(gen_dir), check=True)
        subprocess.run(["git", "commit", "-m", "initial", "--author", "tester <tester@example.com>"], cwd=str(gen_dir), check=True)

        # Run l3build doc in the developer environment and fail the test on
        # any non-zero exit so the output mirrors what you would see locally.
        cmd = ["l3build", "doc", "--halt-on-error", "--show-log-on-error"]
        proc = subprocess.run(cmd, cwd=str(gen_dir), capture_output=True, text=True)
        if proc.returncode != 0:
            pytest.fail(f"l3build doc failed (rc={proc.returncode})\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}")

        # Success: optionally assert that some expected PDF exists (e.g., sol.pdf)
        sol_pdf = gen_dir / "q01.sol.pdf"
        assert sol_pdf.exists(), f"expected solutions PDF not found at {sol_pdf}"
    finally:
        # Clean up generated project directory to keep test isolation tight.
        import shutil
        if gen_dir.exists():
            shutil.rmtree(gen_dir)
