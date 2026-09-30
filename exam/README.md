# cookiecutter-exam
Cookiecutter for an l3build module for an exam

## Usage

To create a new exam:

    cookiecutter --config-file config.yml gh:leingang/cookiecutter-exam

This will generate an `l3build` module. 

## Variables

* `exam_code`: Basically the “project slug” of the document

* `exam_name`: The name which goes on the title page of the exam

* `exam_date` (YYYY-MM-DD): The date of the exam

* `exam_duration`: Length of the exam in minutes.

* `use_nyu_fonts` [y/n]: Use the NYU fonts NYU Perstare and Frank Ruhl Libre. User is in charge of downloading and installing these fonts.

* `has_versions`: Set this to `y` if you want several versions of the same exam.

* `versions_csv`: A comma-separated string list of the version names. They will
  become extra guards in the `.dtx` file. It's up to the author to do something
  different in each version.

## Randomization

The generated file will include a six-digit random number seed. If there are
multiple versions, each will get its own seed.

* `version_randomization_groups`: Comma-separated list of version groups
  (semicolon-separated within a group) that should share the same random
  seed. Defaults to `versions_csv`, meaning every version gets its own seed.
  Example: `"A;B,C,D"` gives A and B the same seed, C and D each their own.

## Per-version overrides

* `version_course_names`: Comma-separated list of `versions:course_name`
  pairs, overriding `\course` for specific versions (e.g. when the same
  exam is given to multiple sections). Versions can be grouped with
  semicolons to share an override. The base `\course{course_name}` line is
  always emitted; each pair here adds a docstrip-guarded override after it.
  Example: `"6A;6B:MATH-UA 122.006 Calculus II,16A;16B:MATH-UA 122.016 Calculus II"`

* `version_times`: Comma-separated list of `version:time` pairs, appended to
  `\date` as per-version docstrip-guarded lines (e.g. for sections that
  share an exam date but meet at different times). When set, `\date` is
  wrapped in `\relax` followed by one guarded line per version; when empty,
  `\date` is just the plain `exam_date`.
  Example: `"6A:11:00 a.m.,16A:3:30 p.m."`

## Testing

There is a `test/course.yml` file. So you can run:

    cookiecutter --config-file test/config.yml .

And then for subsequent runs:

    cookiecutter --config-file test/config.yml . --replay -f
