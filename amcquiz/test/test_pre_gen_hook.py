import sys
import subprocess
from pathlib import Path

import jinja2
import pytest


ROOT = Path(__file__).resolve().parents[1]
HOOK_PATH = ROOT / "hooks" / "pre_gen_project.py"


def render_hook(template_text: str, cookiecutter_context: dict) -> str:
    env = jinja2.Environment(undefined=jinja2.StrictUndefined)
    tmpl = env.from_string(template_text)
    return tmpl.render(cookiecutter=cookiecutter_context)


def run_rendered_hook(
    rendered_text: str, tmp_path: Path
) -> subprocess.CompletedProcess:
    target = tmp_path / "pre_gen_project_rendered.py"
    target.write_text(rendered_text, encoding="utf8")
    # Run as a script so the main block executes
    return subprocess.run([sys.executable, str(target)], capture_output=True, text=True)


@pytest.mark.parametrize(
    "versions_csv, versions_with_solutions, version_randomization_groups, expect_success",
    [
        ("A,B,C", "A,B", "", True),
        ("A,B", "C", "", False),
        ("A,B,C", "", "A;B,C", True),
        ("A,B,C", "", "A;D,C", False),
    ],
)
def test_pre_gen_project_validation(
    tmp_path: Path,
    versions_csv,
    versions_with_solutions,
    version_randomization_groups,
    expect_success,
):
    template_text = HOOK_PATH.read_text(encoding="utf8")

    cookiecutter_ctx = {
        "has_versions": True,
        "versions_csv": versions_csv,
        # note: the hook expects the literal string for versions_with_solutions
        "versions_with_solutions": versions_with_solutions,
        "version_randomization_groups": version_randomization_groups
    }

    rendered = render_hook(template_text, cookiecutter_ctx)

    proc = run_rendered_hook(rendered, tmp_path)

    if expect_success:
        assert (
            proc.returncode == 0
        ), f"Expected success, got {proc.returncode}\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}"
        # should not print the validation error
        assert "not present in" not in proc.stdout
    else:
        assert (
            proc.returncode != 0
        ), f"Expected failure, got 0\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}"
        assert "not present in" in proc.stdout
