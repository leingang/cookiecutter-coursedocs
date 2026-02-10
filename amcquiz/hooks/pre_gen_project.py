import re
import sys

has_versions = {{ cookiecutter['has_versions'] }}
versions_csv = "{{ cookiecutter['versions_csv'] }}"
versions_with_solutions = "{{ cookiecutter['versions_with_solutions'] }}"
{% if cookiecutter.get('version_randomization_groups') -%}
version_randomization_groups = "{{ cookiecutter['version_randomization_groups'] }}"
{%- else -%}
version_randomization_groups = None
{%- endif %}



def is_valid_version(x: str) -> bool:
    """Check if x is a valid version code

    The version code becomes a boolean option in a DocStrip file.
    The DocStrip documentation says any sequence of *letters* is valid,
    but numbers seem to be acceptable too.

    The special characters `*`, `!`, `/`, `|`, and `&` are used by
    DocStrip, so they probably shouldn't be option names.

    The underscore (`_`), dollar sign (`$`), and carat (`^`) are used in
    LaTeX math mode, so they probably shouldn't be option names either.

    The special characters `,` and `;` are reserved by this cookiecutter
    to parse a string into versions or sets of versions.

    So just to be safe, we'll allow only alphanumeric version codes.

    >>> is_valid_version('v1')
    True
    >>> is_valid_version('version_2')
    False
    >>> is_valid_version('123')
    True
    >>> is_valid_version('v1.0')
    False
    >>> is_valid_version('v1,v2')
    False
    >>> is_valid_version('v1;v2')
    False
    >>> is_valid_version('*')
    False
    >>> is_valid_version('')
    False
    """
    if not x:
        return False
    return bool(re.match(r"^[a-zA-Z0-9]+$", x))

if (__name__ == '__main__'):
    if has_versions:
        versions = [v.strip() for v in versions_csv.split(",")]
        invalid_versions = [v for v in versions if not is_valid_version(v)]
        if invalid_versions:
            print(
                f"Error: The following version codes are invalid: {', '.join(invalid_versions)}"
            )
            print("Version codes must be alphanumeric (letters and/or digits only).")
            sys.exit(1)
        # If the user provided a `versions_with_solutions` CSV, ensure every
        # version listed there is one of the declared versions in
        # `versions_csv`.
        if versions_with_solutions:
            vws = [v.strip() for v in versions_with_solutions.split(",") if v.strip()]
            missing = [v for v in vws if v not in versions]
            if missing:
                print(
                    f"Error: The following versions listed in 'versions_with_solutions' are not present in 'versions_csv': {', '.join(missing)}"
                )
                print("Please ensure all versions_with_solutions entries appear in versions_csv.")
                sys.exit(1)
        # If the user provided a `version_randomization_groups` version string, 
        # ensure every version listed there is one of the declared verisons in 
        # versions_csv.
        if version_randomization_groups:
            vrgs = [v.strip() for v in version_randomization_groups.split(",") if v.strip()]
            for vrg in vrgs:
                vs = [v.strip() for v in vrg.split(";") if v.strip()]
                missing = [v for v in vs if v not in versions]
                if missing:
                    print(
                        f"Error: The following versions listed in 'version_randomization_groups' are not present in 'versions_csv': {', '.join(missing)}"
                    )
                    print("Please ensure all version_randomization_groups entries appear in versions_csv.")
                    sys.exit(1)
                