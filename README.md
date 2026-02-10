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

## Testing

There is a `test/course.yml` file. So you can run:

    cookiecutter --config-file test/config.yml .

And then for subsequent runs:

    cookiecutter --config-file test/config.yml . --replay -f