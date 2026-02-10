"""pytest runner that executes doctests found in all python modules in the repo.

This test will:
 - discover .py files under the repository root (excluding hidden dirs, __pycache__, and test files),
 - import each module dynamically, and
 - run doctest.testmod on the imported module.

The test fails if any doctest failure is reported or if a module fails to import.
"""
from pathlib import Path
import importlib.util
import doctest
import traceback
import pytest
import json
import subprocess
import sys
import jinja2


ROOT = Path(__file__).resolve().parent.parent


def _iter_python_files(root: Path = ROOT):
    """Yield candidate Python files to check for doctests.

    Excludes:
      - files in hidden directories (starting with .)
      - __pycache__ directories
      - files in the top-level `test` directory (to avoid test modules)
      - files named like test_*.py
    """
    for p in root.rglob("*.py"):
        # Skip files in hidden directories
        if any(part.startswith(".") for part in p.parts):
            continue
        # Skip caches and obvious packaging dirs
        if "__pycache__" in p.parts or "site-packages" in p.parts:
            continue
        # Skip top-level test directory and test files
        if "test" in p.parts and p.parent.name == "test":
            continue
        if p.name.startswith("test_"):
            continue
        # Skip files that appear to be Jinja/Cookiecutter templates. Some
        # repository files (hooks, templates) include `{{ cookiecutter.* }}`
        # markers which are not valid Python until rendered. Avoid importing
        # those template sources during doctest discovery.
        try:
            txt = p.read_text()
        except Exception:
            # If we can't read the file for any reason, skip it.
            continue
        if ("{{ cookiecutter" in txt) or ("{{" in txt and "}}" in txt) or ("{%" in txt):
            continue
        yield p


def _load_module_from_path(path: Path, root: Path = ROOT):
    """Import a module from a file path under a unique, deterministic name.

    Returns the imported module object. Raises on import errors.
    """
    # Create a stable module name from the path relative to repo root
    rel = path.relative_to(root).as_posix()
    mod_name = "doctest_mod_" + rel.replace("/", "_").replace(".", "_")
    spec = importlib.util.spec_from_file_location(mod_name, str(path))
    module = importlib.util.module_from_spec(spec)
    # Execute module code (this runs top-level statements; import errors will surface)
    spec.loader.exec_module(module)
    return module


# Build the list of module files at import time so pytest can parametrize them.
MODULE_PATHS = sorted([p for p in _iter_python_files()], key=lambda p: p.as_posix())


@pytest.mark.parametrize("path", MODULE_PATHS)
def test_doctests_per_module(path: Path):
    """Run doctests found in a single module specified by `path`.

    Import errors and doctest failures are reported as test failures with helpful
    messages including the module path.
    """
    try:
        module = _load_module_from_path(path)
    except Exception:
        pytest.fail(f"Import error in {path}:\n{traceback.format_exc()}")

    failures, attempted = doctest.testmod(
        module, optionflags=doctest.ELLIPSIS | doctest.NORMALIZE_WHITESPACE
    )
    assert failures == 0, f"{failures} doctest failure(s) in {path} (out of {attempted} tests)"


@pytest.mark.usefixtures()
def test_doctests_hooks_in_rendered_template(tmp_path: Path):
    """Render the cookiecutter template into a temp dir and run doctests
    found in the generated project's `hooks/` Python modules.

    This ensures hook scripts in the rendered project don't contain
    template placeholders at import-time and that their doctests pass.
    """
    # Ensure cookiecutter importable (we use python -m cookiecutter)
    try:
        import cookiecutter  # noqa: F401
    except Exception:
        pytest.skip("cookiecutter package is not importable")

    # Render hook templates from the project template's `hooks/` directory
    # using Jinja2 and the same cookiecutter context, then import and
    # run doctests against the rendered hook modules. Hooks are executed
    # during cookiecutter generation but are not copied into the final
    # generated project, so we render them here for testing.
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

    template_hooks = ROOT / "hooks"
    if not template_hooks.exists():
        pytest.skip("template has no hooks/ directory; nothing to doctest")

    rendered_dir = tmp_path / "rendered_hooks"
    rendered_dir.mkdir()

    env = jinja2.Environment(undefined=jinja2.StrictUndefined)

    py_files = []
    for p in sorted(template_hooks.rglob("*.py")):
        src = p.read_text()
        try:
            tmpl = env.from_string(src)
            rendered = tmpl.render(cookiecutter=valid_context["cookiecutter"])
        except Exception as e:
            pytest.fail(f"Failed to render template hook {p}: {e}")

        out_path = rendered_dir / p.name
        out_path.write_text(rendered)
        py_files.append(out_path)

    if not py_files:
        pytest.skip("no Python hook templates found to render")

    try:
        for p in py_files:
            try:
                module = _load_module_from_path(p, root=rendered_dir)
            except Exception:
                pytest.fail(f"Import error in rendered hook module {p}:\n{traceback.format_exc()}")

            failures, attempted = doctest.testmod(
                module, optionflags=doctest.ELLIPSIS | doctest.NORMALIZE_WHITESPACE
            )
            assert failures == 0, f"{failures} doctest failure(s) in rendered hook {p} (out of {attempted} tests)"
    finally:
        import shutil as _sh
        if rendered_dir.exists():
            _sh.rmtree(rendered_dir)
