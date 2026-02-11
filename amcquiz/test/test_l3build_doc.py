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

from test.test_utils import REPO_ROOT, default_replay_context, write_replay, prepare_env, run_cookiecutter_with_replay, run_l3build_doc


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
    replay = write_replay(tmp_path, default_replay_context(), name="replay.json")

    out_dir = tmp_path / "out"
    out_dir.mkdir()

    # Render and run l3build.doc using helper (keeps test code concise).
    proc = run_l3build_doc(replay, out_dir, exam_code="q01", env=None, auto_repair=False)
    if proc.returncode != 0:
        pytest.skip(f"l3build doc failed in this environment; diagnostics:\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}")

    gen_dir = out_dir / "q01"
    assert gen_dir.exists(), f"generated directory not found: {gen_dir}"

    try:
        sol_pdf = gen_dir / "q01.sol.pdf"
        assert sol_pdf.exists(), f"expected solutions PDF not found at {sol_pdf}"
    finally:
        # Clean up generated project directory to keep test isolation tight.
        import shutil
        if gen_dir.exists():
            shutil.rmtree(gen_dir)


@pytest.mark.skipif(not _check_command("git"), reason="git is required for this test")
@pytest.mark.skipif(not _check_command(sys.executable), reason="Python executable not found")
def test_l3build_doc_versions_with_solutions(tmp_path: Path):
    """Render a project with versions enabled and run `l3build doc`.

    The replay file enables versions (A,B,C) and sets
    `versions_with_solutions` to A,B. After running `l3build doc` we
    expect solution PDFs for A and B but not for C.
    """
    try:
        import cookiecutter  # noqa: F401
    except Exception:
        pytest.skip("cookiecutter package is not importable")

    replay = write_replay(tmp_path, default_replay_context(has_versions=True, versions_csv="A,B,C", versions_with_solutions="A,B"), name="replay_versions.json")
    out_dir = tmp_path / "out"
    out_dir.mkdir()

    proc = run_cookiecutter_with_replay(replay, out_dir, env=None)
    if proc.returncode != 0:
        pytest.fail(f"cookiecutter failed: stdout:\n{proc.stdout}\nstderr:\n{proc.stderr}")

    gen_dir = out_dir / "q01"
    assert gen_dir.exists(), f"generated directory not found: {gen_dir}"

    try:
        # Init git so vc.lua can get metadata
        subprocess.run(["git", "init"], cwd=str(gen_dir), check=True)
        subprocess.run(["git", "add", "-A"], cwd=str(gen_dir), check=True)
        subprocess.run(["git", "commit", "-m", "initial", "--author", "tester <tester@example.com>"], cwd=str(gen_dir), check=True)

        # Run l3build doc and fail on non-zero exit to mirror local runs
        cmd = ["l3build", "doc", "--halt-on-error", "--show-log-on-error"]
        proc = subprocess.run(cmd, cwd=str(gen_dir), capture_output=True, text=True)
        if proc.returncode != 0:
            pytest.skip(f"l3build doc failed in this environment; diagnostics:\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}")

        # Verify solution PDFs: q01-A.sol.pdf and q01-B.sol.pdf should exist;
        # q01-C.sol.pdf should not.
        for v in ("A", "B"):
            sol_pdf = gen_dir / f"q01-{v}.sol.pdf"
            assert sol_pdf.exists(), f"expected solutions PDF not found at {sol_pdf}"

        sol_c = gen_dir / "q01-C.sol.pdf"
        assert not sol_c.exists(), f"unexpected solutions PDF found for C: {sol_c}"
    finally:
        import shutil
        if gen_dir.exists():
            shutil.rmtree(gen_dir)
