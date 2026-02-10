from pathlib import Path
import json
import subprocess
import sys
import os
import shutil


REPO_ROOT = Path(__file__).resolve().parent.parent


def default_replay_context(**overrides):
    """Return a minimal valid cookiecutter replay context.

    Accepts overrides for convenience (e.g., has_versions=True).
    """
    ctx = {
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
    # Apply overrides deeply for cookiecutter keys
    if overrides:
        for k, v in overrides.items():
            # if caller passed a full cookiecutter dict, merge it
            if k == "cookiecutter" and isinstance(v, dict):
                ctx["cookiecutter"].update(v)
            else:
                ctx["cookiecutter"][k] = v
    return ctx


def write_replay(tmp_path: Path, context: dict, name: str = "replay.json") -> Path:
    replay = tmp_path / name
    replay.write_text(json.dumps(context))
    return replay


def prepare_env(tmp_path: Path) -> dict:
    env = dict(**{k: v for k, v in os.environ.items()})
    env["HOME"] = str(tmp_path)
    env["XDG_CONFIG_HOME"] = str(tmp_path / ".config")
    return env


def run_cookiecutter_with_replay(
    replay_path: Path, output_dir: Path, env=None
) -> subprocess.CompletedProcess:
    """Run cookiecutter with a replay file and return the CompletedProcess.

    The caller can assert on returncode and inspect stdout/stderr.
    """
    cmd = [
        sys.executable,
        "-m",
        "cookiecutter",
        str(REPO_ROOT),
        "--replay-file",
        str(replay_path),
        "--output-dir",
        str(output_dir),
        "--accept-hooks",
        "no",
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, env=env)
    return proc


def run_l3build_doc(
    replay_path: Path,
    output_dir: Path,
    *,
    exam_code: str = "q01",
    env=None,
    auto_repair: bool = False,
) -> subprocess.CompletedProcess:
    """Render a project with cookiecutter replay and run `l3build doc`.

    - replay_path: path to the replay JSON
    - output_dir: directory where cookiecutter will write the generated project
    - exam_code: the generated project directory name (defaults to q01)
    - env: subprocess env for cookiecutter (if None, the caller's env is used)
    - auto_repair: if True, attempt font-db / luaotfload repairs once on failure

    Returns the CompletedProcess from the final `l3build doc` invocation.
    """
    # Render the template
    proc = run_cookiecutter_with_replay(replay_path, output_dir, env=env)
    if proc.returncode != 0:
        return proc

    gen_dir = output_dir / exam_code
    if not gen_dir.exists():
        # Return an artificial CompletedProcess-like object for caller convenience
        fake = subprocess.CompletedProcess(
            args=["cookiecutter"],
            returncode=1,
            stdout="",
            stderr=f"generated dir not found: {gen_dir}",
        )
        return fake

    # Init git so vc.lua can read metadata
    try:
        subprocess.run(
            ["git", "init"], cwd=str(gen_dir), check=True, capture_output=True
        )
        subprocess.run(
            ["git", "add", "-A"], cwd=str(gen_dir), check=True, capture_output=True
        )
        subprocess.run(
            [
                "git",
                "commit",
                "-m",
                "initial",
                "--author",
                "tester <tester@example.com>",
            ],
            cwd=str(gen_dir),
            check=True,
            capture_output=True,
        )
    except subprocess.CalledProcessError as e:
        # If git fails, continue — l3build/ vc.lua may still work in some cases
        pass

    # Run l3build doc
    cmd = ["l3build", "doc", "--halt-on-error", "--show-log-on-error"]
    proc = subprocess.run(cmd, cwd=str(gen_dir), capture_output=True, text=True)

    # Optionally attempt a simple auto-repair for common font/db issues
    if proc.returncode != 0 and auto_repair:
        combined = (proc.stdout or "") + "\n" + (proc.stderr or "")
        repair_attempted = False
        if ("luaotfload" in combined or "font" in combined) and shutil.which(
            "fc-cache"
        ):
            # refresh font cache and try luaotfload-tool if available
            try:
                subprocess.run(["fc-cache", "-f"], check=True)
            except Exception:
                pass
            if shutil.which("luaotfload-tool"):
                try:
                    subprocess.run(["luaotfload-tool", "--update"], check=True)
                except Exception:
                    pass
            repair_attempted = True

        if repair_attempted:
            # retry once
            proc = subprocess.run(cmd, cwd=str(gen_dir), capture_output=True, text=True)

    return proc


def read_generated_dtx(gen_dir: Path, exam_code: str = "q01") -> str:
    """Read and return the generated `.dtx` file contents for the given exam code.

    Raises FileNotFoundError if the expected .dtx file is not present.
    """
    dtx_path = gen_dir / f"{exam_code}.dtx"
    if not dtx_path.exists():
        raise FileNotFoundError(f"generated .dtx not found: {dtx_path}")
    return dtx_path.read_text(encoding="utf-8")
