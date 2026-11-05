#!/usr/bin/env texlua

module = "{{cookiecutter.exam_code}}"
bundle = "{{cookiecutter.bundle_name}}"
maindir = ".."

version = "0.0"
versiondate = "2026-01-30"


unpackfiles  = {"*.dtx"}
unpackexe    = "latex" -- required because of the \ProvidesFile

supportdir = "support"
typesetfiles = {"*.*.tex"}
typesetexe = "lualatex"
typesetsuppfiles = {"*.png", "*.pdf", "*.sty", "*.lua", "*.cls"}

tagfiles = {"*.dtx", "*.lua"}

-- print if the debug options is set
function print_debug(s)
    if options['debug'] then
        print(s)
    end
end

-- capture the output from a shell command
-- Thanks Norman Ramsey https://stackoverflow.com/a/326715/297797
-- there is also the shell() function from l3build-upload.lua
-- it doesn't trim leading/training whitespace.
function os.capture(cmd, raw)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    if raw then return s end
    s = string.gsub(s, '^%s+', '')
    s = string.gsub(s, '%s+$', '')
    s = string.gsub(s, '[\n\r]+', ' ')
    return s
end

-- TYPESET FILES

-- Typeset with latexmk. latexmkrc runs lualatex with --shell-escape,
-- which markversion needs to ask git for the revision.
table.insert(typesetsuppfiles,"latexmkrc")
function typeset(file)
    local name = jobname(file)
    local cmd = "latexmk -r latexmkrc " .. file
    print("Running '" .. cmd .. "'")
    errorlevel = run(typesetdir,cmd)
    assert(errorlevel == 0, 
        "Failed with status " .. errorlevel .. ": " .. cmd)
    return errorlevel
end


-- TAG FILES
-- decorator to only run if repo is clean
function only_if_clean(f)
    return function(x)
        assert(os.capture("git status --porcelain") == "",
            "Repository is dirty")
        print_debug("Repository is clean")
        return f(x)
    end 
end

-- tag = only_if_clean(tag)
target_list.tag.pre = only_if_clean(target_list.tag.pre)

-- Bump version LaTeX style:
-- 0.1 -> 0.1a -> 0.1b -> 0.2 -> ... -> 1.0 -> 1.1 -> 1.1a -> ...
function next_version_latex(parts)
    -- parts is an array of arguments; we want the first if it exists
    local part = nil
    if parts then
        part = parts[1]
    end
    local version = version or "0.1"
    local patches = "abcdefghijklmnopqrstuvwxyz"
    major, minor, patch = string.match(version, "^v?(%d+)%.(%d+)(%a?)")
    print_debug("current version = " .. version)
    print_debug(string.format("major=%d, minor=%d, patch=\"%s\"",major,minor,patch))
    if (part == "major") then
        major = major + 1
        minor = 0
        patch = ""
    elseif (part == "minor" or part == nil) then
        minor = minor + 1
        patch = ""    
    elseif (part == "patch") then
        if (patch == "") then
            patch = "a"
        else
            -- get next letter in the sequence
            -- https://stackoverflow.com/q/23120266/297797
            patch = patches:match(patch .. '(.)')
        end
    else    
        print("bad version part!")
        return
    end
    version = string.format( "%i.%i%s", major,minor,patch)
    print_debug("new version = " .. version)
    return version
end 

function bump_version(part)
    tagname = next_version(part)
    if options['dry-run'] then
        print("- l3build tag " .. tagname)
    else
        main("tag",{tagname})
    end
end

target_list.bump = {
    func = bump_version,
    help = "Bump the version, tag, and commit"
}

function update_tag(file,content,tagname,tagdate)
    -- TeX dates are in yyyy/mm/dd format.  tagdate is in yyyy-mm-dd format.
    tagdate_tex = string.gsub(tagdate,'-','/')
    if string.match(file, "%.dtx$") then
        content = string.gsub(content,
            "\n *%[%d%d%d%d/%d%d/%d%d v.- ",
            "\n  [" .. tagdate_tex .. " v" .. tagname .. " "
        )
        content = string.gsub(content,
            "\n%% \\changes{unreleased}",
            "\n%% \\changes{v" .. tagname .. "}"
        )
    elseif string.match(file,"%.lua") then
        content = string.gsub(content,
            '\nversion = ".-"',
            '\nversion = "' .. tagname .. '"'
        )
        content = string.gsub(content,
            '\nversiondate = ".-"',
            '\nversiondate = "' .. tagdate .. '"'
        )
    end
    return content
end


function git_tag(version,tagdate)
    -- create the name of the git tag from the version and tagdate
    local module = module or nil
    if (module) then
        -- module version with name prepe
        return string.format("%s-v%s",module,version)
    else
        -- calver
        return tagdate
    end
end

function tag_hook(version,tagdate)
    -- tag repository
    tagname = git_tag(version,tagdate)
    os.execute("git add .")
    os.execute("git commit -m \"Log changes for version " .. version .. "\"")
    return os.execute("git tag -a -m \"Tag version " .. tagname .. "\" " .. tagname)
end

next_version = next_version_latex


-- GRADESCOPE
-- `l3build gradescope` sets the exam up on Gradescope with
-- `edubag gradescope client setup-exam`: it creates each version's
-- assignment, saves the outline and imports the rubrics that exam-gradescope
-- wrote next to the PDFs in the build directory, and groups the versions in a
-- version set.  The config it gives edubag is written there too
-- (<module>.yml).  Every step is skipped if it is already done, so it can be
-- run again.  `l3build gradescope --dry-run` only reports what would change,
-- and `l3build gradescope replace-rubrics headed` passes --replace-rubrics
-- and --headed to edubag (options go before those words).
-- `l3build gradescope delete` deletes the exam from Gradescope instead: its
-- version set (`edubag gradescope client delete-assignment-container`), then
-- its versions' assignments (`... delete-assignment`), with their outlines,
-- rubrics and any submissions.  Each step lists what it would delete and asks
-- first; anything with submissions is refused unless you add `force`.
-- `l3build gradescope --dry-run delete` only lists them.
-- Run `l3build doc` first: this uses the files it made.
-- Questions on the bubble sheet are not on Gradescope; their answer key is
-- <module>-<version>.qns.key.csv in the build directory.

-- The command to run edubag; EDUBAG=... overrides it.
gradescopecmd = os.getenv("EDUBAG") or "edubag"
-- The Gradescope course ID.
gradescopecourse = "{{ cookiecutter.gradescope_course_id }}"
-- The title of the version set.
gradescopetitle = "{{ cookiecutter.exam_name }}"
-- Each version and the title of its assignment, in order (made from
-- gradescope_assignment_format when the template was used).  An exam without
-- versions uses the version "".
gradescopeversions = {
{%- set gsversions = cookiecutter.versions_csv.split(',') | map('trim') | select | list %}
{%- set gstimes = {} %}
{%- for pair in cookiecutter.version_times.split(',') if ':' in pair %}
{%- set _ = gstimes.update({pair.split(':', 1)[0] | trim: pair.split(':', 1)[1] | trim}) %}
{%- endfor %}
{%- for v in gsversions %}
    {"{{ v }}", "{{ cookiecutter.gradescope_assignment_format | replace('{exam_name}', cookiecutter.exam_name) | replace('{version}', v) | replace('{time}', gstimes.get(v, v)) }}"},
{%- else %}
    {"", "{{ cookiecutter.exam_name }}"},
{%- endfor %}
}
-- What students see of the rubric on their graded work, when some question
-- on Gradescope is free response: all, applied, by_scoring or hidden.
-- nil leaves Gradescope's setting alone.
gradescopevisibility = "applied"

local function yaml_string(s)
    return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Delete the exam from Gradescope: the version set, then the assignments.
local function gradescope_delete(args)
    local titles = {}
    for _, pair in ipairs(gradescopeversions) do
        table.insert(titles, shell_quote(pair[2]))
    end
    local client = gradescopecmd .. " gradescope client "
    local cmds = {
        client .. "delete-assignment-container " .. gradescopecourse .. " "
            .. shell_quote(gradescopetitle) .. args,
        client .. "delete-assignment " .. gradescopecourse .. " "
            .. table.concat(titles, " ") .. args,
    }
    for _, cmd in ipairs(cmds) do
        print("Running '" .. cmd .. "'")
        local errorlevel = run(".", cmd)
        if errorlevel ~= 0 then return errorlevel end
    end
    return 0
end

function gradescope(names)
    -- `delete` deletes the exam instead of setting it up; the other words are
    -- edubag flags.
    local delete = false
    local flags = {["replace-rubrics"] = "--replace-rubrics", headed = "--headed",
        force = "--force"}
    local args = options['dry-run'] and " --dry-run" or ""
    for _, name in ipairs(names or {}) do
        if name == "delete" then
            delete = true
        else
            args = args .. " " .. assert(flags[name], "Unknown word '" .. name
                .. "' (use delete, force, replace-rubrics or headed)")
        end
    end
    assert(string.match(gradescopecourse, "^%d+$"),
        "Fill in gradescopecourse, the Gradescope course ID, in build.lua")
    if delete then return gradescope_delete(args) end
    local entries, frq = {}, false
    for _, pair in ipairs(gradescopeversions) do
        local v, title = pair[1], pair[2]
        local job = module .. (v ~= "" and ("-" .. v) or "") .. ".qns"
        assert(fileexists(typesetdir .. "/" .. job .. ".pdf"),
            job .. ".pdf is not in " .. typesetdir .. "; run l3build doc first")
        -- A version without an outline has nothing on Gradescope.
        if fileexists(typesetdir .. "/" .. job .. ".outline.json") then
            table.insert(entries, string.format("  %s: {pdf: %s, assignment: %s}",
                yaml_string(v ~= "" and v or module), yaml_string(job .. ".pdf"),
                yaml_string(title)))
            local f = io.open(typesetdir .. "/" .. job .. ".json")
            if f then
                local manifest = f:read("a")
                f:close()
                frq = frq or string.find(manifest,
                    '"type": "frq",%s*"destination": "gradescope"') ~= nil
            end
        end
    end
    if #entries == 0 then
        print("Nothing in " .. module .. " is graded on Gradescope.")
        return 0
    end
    local config = module .. ".yml"
    local f = assert(io.open(typesetdir .. "/" .. config, "w"))
    f:write("# Written by `l3build gradescope` from build.lua.\n",
        "course: ", yaml_string(gradescopecourse), "\n",
        "title: ", yaml_string(gradescopetitle), "\n")
    if frq and gradescopevisibility then
        f:write("student_visibility: ", gradescopevisibility, "\n")
    end
    f:write("versions:\n", table.concat(entries, "\n"), "\n")
    f:close()
    local cmd = gradescopecmd .. " gradescope client setup-exam " .. config .. args
    print("Running '" .. cmd .. "' in " .. typesetdir)
    local errorlevel = run(typesetdir, cmd)
    assert(errorlevel == 0, "Failed with status " .. errorlevel .. ": " .. cmd)
    return 0
end

target_list.gradescope = {
    func = gradescope,
    help = "Set the exam up on Gradescope (or delete it from there, with `delete`)"
}


-- PERSONALIZED COPIES
-- `l3build personalize` makes copies with students' names and NetIDs from a
-- file outside the repository.  See support/personalize.lua.
-- The student file; STUDENTS=/path/to/file.csv overrides it.
personalfile = "../../../Students/personalized-exams.csv"
-- TeX code put before \documentclass in each copy, after the definitions of
-- \StudentName and \StudentNetID.  The class prints the name and NetID set
-- with \setstudentname and \setstudentid.
personalsetup = [[\AddToHook{begindocument/before}{\setstudentname{\StudentName}\setstudentid{\StudentNetID}}]]
dofile(supportdir .. "/transparency.lua")
dofile(supportdir .. "/personalize.lua")

-- l3build install --full will install the pdfs in the directory below
options['texmfhome'] = "../../../Share/"
-- TODO set sourcefiles to nil only during installation
tdslocations = {'*.*.pdf',"*.dtx"}


