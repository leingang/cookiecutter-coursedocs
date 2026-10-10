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

* `course_name`: The full course name, printed on the cover page
  (e.g. `MATH-UA 120 Discrete Mathematics`).

* `short_course_name`: A shorter course name for the page header
  (e.g. `MATH-UA 120`). Defaults to `course_name`. When it differs from
  `course_name`, it is passed as the optional argument:
  `\course[short_course_name]{course_name}`.

* `use_nyu_fonts` [y/n]: Use the NYU fonts NYU Perstare and Frank Ruhl Libre. User is in charge of downloading and installing these fonts.

* `use_barcode`: Pass the `barcode` option to the `nyuexam3` class, which
  puts an Aztec code of the job name in the top right corner of the cover.

* `section_number`: Printed in the Section field of the bubble sheet.

* `use_bubble_sheet`: Include a Gradescope bubble sheet page. Its Name/ID
  fields are highlighted, the Other field is filled with
  `short_course_name`, and unused bubble rows are whited out. The number of
  rows is `num_mcq + 5*num_cata + 2*num_tf`; the whiteout heights are
  computed from that (calibrated on Fall 2026 Discrete Midterm I), but check
  the rendered page.

* `use_formula_sheet`: Include `support/formula_sheet_nyu.pdf` (algebra,
  geometry, and trigonometry reference pages) at the end of the question
  versions. It follows an `\examcleardoublepage`, so it is the front and back
  of the last sheet of paper. It is left out of the solutions.

* `num_mcq`, `points_per_mcq`: Number and point value of multiple choice
  questions.

* `num_cata`: Number of check-all-that-apply *groups*. Each group is five
  Yes/No questions worth 1 point each, so Gradescope can give partial credit.

* `num_tf`: Number of true/false statements. Each is two questions: a truth
  value (1 point) and a reason (Definition/Proven/Vacuous/Sometimes/Never,
  2 points).

* `num_frq`: Number of free response stubs.

* `use_randomlist`: Load the `randomlist` package (and `versionlist`; see
  below). It is loaded regardless when `num_cata` or `num_tf` is positive,
  because those question groups are shuffled with it.

* `has_versions`: Set this to `y` if you want several versions of the same exam.

* `versions_csv`: A comma-separated string list of the version names. They will
  become extra guards in the `.dtx` file. It's up to the author to do something
  different in each version.

* `versions_to_stamp`: A comma-separated list of the versions that get
  individually barcoded copies (see *Stamping barcodes* below). Each one gets
  an entry in `stampjobs` in `build.lua`, with `number_copies` copies and an
  empty first barcode number to fill in. Defaults to none.

## Randomization

The generated file will include a six-digit random number seed. If there are
multiple versions, each will get its own seed.

* `version_randomization_groups`: Comma-separated list of version groups
  (semicolon-separated within a group) that should share the same random
  seed. Defaults to `versions_csv`, meaning every version gets its own seed.
  Example: `"A;B,C,D"` gives A and B the same seed, C and D each their own.

* `\GetVersionItem{<list>}{<macro>}`: with `use_randomlist`, the template also
  defines `\sharedseed` (one seed for all versions) and `\versionindex` (1, 2,
  … per randomization group), and loads `support/versionlist.sty`. This
  drop-in replacement for randomlist's `\GetRandomItem` guarantees each
  randomization group a *different* item from a bank: every version shuffles
  the list the same way and takes the item at position `\versionindex`. The
  list needs at least one item per group, or the build stops with an error.

## Per-version overrides

* `version_course_names`: Comma-separated list of `versions:course_name`
  pairs, overriding `\course` for specific versions (e.g. when the same
  exam is given to multiple sections). Versions can be grouped with
  semicolons to share an override. The base `\course{course_name}` line is
  always emitted; each pair here adds a docstrip-guarded override after it.
  Overrides keep `short_course_name` as the header name.
  Example: `"6A;6B:MATH-UA 122.006 Calculus II,16A;16B:MATH-UA 122.016 Calculus II"`

* `version_times`: Comma-separated list of `version:time` pairs, appended to
  `\date` as per-version docstrip-guarded lines (e.g. for sections that
  share an exam date but meet at different times). When set, `\date` is
  wrapped in `\relax` followed by one guarded line per version; when empty,
  `\date` is just the plain `exam_date`.
  Example: `"6A:11:00 a.m.,16A:3:30 p.m."`

## Stamping barcodes

`l3build stamp` runs [`stampbarcode`](https://github.com/leingang/stampbarcode)
on the built question PDFs, making one copy per barcode number in the
`stamped` directory of the build directory. Which versions are stamped, their
first barcode numbers, and their numbers of copies are in the `stampjobs`
table in `build.lua`. `l3build stamp A B` stamps only those versions, and
`l3build stamp --dry-run` only prints the commands. Options go before
version names: `l3build stamp --dry-run A`.

## Support files

* `command-verbs.tex`: a glossary of IB command terms (explain, prove, …).
  Use `\gls{prove}` / `\Gls{prove}` in questions; the glossary page after
  the cover lists only the terms used.

* `formula_sheet_nyu.pdf`: two reference pages of algebra, geometry, and
  trigonometry formulas in NYU Perstare and the NYU color palette, included
  with `use_formula_sheet`. To change it, edit `formula_sheet_nyu.tex` and
  compile it with `lualatex`.

* `aux_to_csv.lua`: when building solutions with LuaLaTeX, writes
  `\jobname.csv` with each question's correct choice and point value, for
  uploading an answer key to Gradescope.

## Testing

There is a `test/course.yml` file. So you can run:

    cookiecutter --config-file test/config.yml .

And then for subsequent runs:

    cookiecutter --config-file test/config.yml . --replay -f
