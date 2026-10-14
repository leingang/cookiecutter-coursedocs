-- PERSONALIZED COPIES
-- Load from build.lua with `dofile(supportdir .. "/personalize.lua")`.
--
-- `l3build personalize` makes a copy of a version with a student's name and
-- NetID on it, for students who take the exam or quiz somewhere else (the
-- testing center, a proctored makeup, ...).
-- `l3build personalize abc123` makes only that student's copy, and
-- `l3build personalize --dry-run` only shows the plan.
-- Run `l3build doc` first: the copies are made from its generated files.
--
-- The students are listed in a CSV file outside the repository, so that no
-- student data is committed.  To use another file:
--     STUDENTS=/path/to/file.csv l3build personalize
-- The columns are exam,netid,name,version.
-- * exam: globs separated by spaces, matched against the module name:
--   "*" for every exam and quiz, "mt* final" for the major exams only,
--   "q*" for the quizzes, "mt1" for one exam.
-- * version: the versions to copy, separated by spaces.  The first one that
--   this module has is used, so "A 1100" gives exam version A and the
--   1100 version of a quiz.  A module without versions ignores it.
-- A student can have several rows, as long as only one matches each module.
--
-- Each copy is the generated .qns.tex file of the version, with
-- \StudentName and \StudentNetID defined at the top, followed by
-- `personalsetup`.  The .dtx or the class prints them.
--
-- The copies go to `personaldir`, never to the module directory or the
-- install directory.  `l3build clean` removes them.
personalfile = personalfile or "../../../Students/personalized-exams.csv"
personaldir = personaldir -- nil means the "personalized" directory in builddir
personalsetup = personalsetup or ""

-- Split a CSV file into rows of fields.  Fields may be quoted, with "" for a
-- quotation mark inside quotes.
local function read_csv(path)
    local f = assert(io.open(path, "r"), "Cannot read " .. path)
    local text = f:read("a")
    f:close()
    text = text:gsub("^\239\187\191", ""):gsub("\r\n?", "\n") -- BOM, CRLF
    local rows, row, field = {}, {}, ""
    local i, n, quoted = 1, #text, false
    while i <= n do
        local c = text:sub(i, i)
        if quoted then
            if c == '"' and text:sub(i + 1, i + 1) == '"' then
                field = field .. '"'
                i = i + 1
            elseif c == '"' then
                quoted = false
            else
                field = field .. c
            end
        elseif c == '"' then
            quoted = true
        elseif c == "," then
            table.insert(row, field)
            field = ""
        elseif c == "\n" then
            table.insert(row, field)
            table.insert(rows, row)
            row, field = {}, ""
        else
            field = field .. c
        end
        i = i + 1
    end
    if field ~= "" or #row > 0 then
        table.insert(row, field)
        table.insert(rows, row)
    end
    return rows
end

-- Does a space-separated list of globs match the whole name?
local function globs_match(globs, name)
    for glob in string.gmatch(globs, "%S+") do
        local pattern = "^" .. glob:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0")
            :gsub("%*", ".*"):gsub("%?", ".") .. "$"
        if string.match(name, pattern) then return true end
    end
    return false
end

-- Escape the characters that are special in TeX.
local function tex_escape(s)
    local replacements = {
        ["\\"] = "\\textbackslash{}", ["{"] = "\\{", ["}"] = "\\}",
        ["$"] = "\\$", ["&"] = "\\&", ["#"] = "\\#", ["%"] = "\\%",
        ["_"] = "\\_", ["^"] = "\\textasciicircum{}",
        ["~"] = "\\textasciitilde{}",
    }
    return (s:gsub("[\\{}$&#%%_^~]", replacements))
end

-- The rows of the student file for this module, as {netid, name, version}.
local function personal_rows()
    local path = os.getenv("STUDENTS")
    if not path or path == "" then path = personalfile end
    assert(fileexists(path), "No student file " .. path
        .. "; set STUDENTS to its path")
    local rows = read_csv(path)
    local header = {}
    for i, name in ipairs(table.remove(rows, 1) or {}) do
        header[name:match("^%s*(.-)%s*$"):lower()] = i
    end
    for _, column in ipairs({"exam", "netid", "name", "version"}) do
        assert(header[column], path .. " has no " .. column .. " column")
    end
    local students, lines = {}, {}
    for i, row in ipairs(rows) do
        local function get(column)
            return (row[header[column]] or ""):match("^%s*(.-)%s*$")
        end
        local line = i + 1
        if get("exam") ~= "" and globs_match(get("exam"), module) then
            local netid = get("netid")
            assert(netid:match("^[a-z]+%d+$"), string.format(
                "%s line %d: bad NetID \"%s\"", path, line, netid))
            assert(not lines[netid], string.format(
                "%s lines %d and %d both give %s a copy of %s",
                path, lines[netid] or 0, line, netid, module))
            lines[netid] = line
            table.insert(students, {netid = netid, name = get("name"),
                version = get("version"), line = line})
        end
    end
    return students, path
end

function personalize(names)
    local students, path = personal_rows()
    if names and #names > 0 then
        local wanted, selected = {}, {}
        for _, netid in ipairs(names) do wanted[netid] = true end
        for _, s in ipairs(students) do
            if wanted[s.netid] then
                table.insert(selected, s)
                wanted[s.netid] = nil
            end
        end
        for netid, _ in pairs(wanted) do
            error(netid .. " has no copy of " .. module .. " in " .. path)
        end
        students = selected
    end
    if #students == 0 then
        print("No personalized copies of " .. module .. " in " .. path)
        return 0
    end
    -- the first listed version that this module has, or the only document
    -- of a module without versions
    local single = module .. ".qns.tex"
    for _, s in ipairs(students) do
        local listed = s.version
        s.version = nil
        if fileexists(typesetdir .. "/" .. single) then
            s.version, s.base = "(single)", single
        end
        for v in string.gmatch(listed, "%S+") do
            if s.version then break end
            local base = module .. "-" .. v .. ".qns.tex"
            if fileexists(typesetdir .. "/" .. base) then
                s.version, s.base = v, base
            end
        end
        assert(s.version, string.format(
            "%s line %d: %s has none of the versions \"%s\"; "
            .. "run l3build doc first, or check the version column",
            path, s.line, module, listed))
    end
    -- The generated files must be newer than the sources they come from:
    -- after the .dtx changes, `l3build doc` has to run again.
    local newest = 0
    for _, glob in ipairs(sourcefiles) do
        for _, file in ipairs(filelist(sourcefiledir, glob)) do
            local time = lfs.attributes(sourcefiledir .. "/" .. file, "modification")
            if time and time > newest then newest = time end
        end
    end
    for _, s in ipairs(students) do
        local time = lfs.attributes(typesetdir .. "/" .. s.base, "modification")
        assert(time and time >= newest, string.format(
            "%s is older than the source; run l3build doc first", s.base))
    end

    local outdir = personaldir or (builddir .. "/personalized")
    print(string.format("%d personalized copies of %s:", #students, module))
    for _, s in ipairs(students) do
        print(string.format("  %s-%s.qns.pdf  from version %s",
            module, s.netid, s.version))
    end
    if options['dry-run'] then return 0 end

    mkdir(outdir)
    for _, s in ipairs(students) do
        local base = s.base
        local copy = module .. "-" .. s.netid .. ".qns.tex"
        local f = assert(io.open(typesetdir .. "/" .. base, "r"))
        local source = f:read("a")
        f:close()
        -- Rename the file in \ProvidesFile, where the footer looks for the
        -- version and date.  The rest, including the random seeds, is the
        -- same as the version.
        local count
        source, count = source:gsub("\\ProvidesFile%s*{" .. base:gsub("%p", "%%%0")
            .. "}", "\\ProvidesFile{" .. copy .. "}")
        assert(count == 1, "No \\ProvidesFile{" .. base .. "} in " .. base)
        f = assert(io.open(typesetdir .. "/" .. copy, "w"))
        f:write("\\def\\StudentName{" .. tex_escape(s.name) .. "}\n",
            "\\def\\StudentNetID{" .. s.netid .. "}\n",
            personalsetup, "\n", source)
        f:close()
        local errorlevel = typeset(copy, typesetdir)
        if errorlevel ~= 0 then return errorlevel end
        local pdf = module .. "-" .. s.netid .. ".qns.pdf"
        rm(outdir, pdf)
        cp(pdf, typesetdir, outdir)
        -- don't leave the copy where `l3build doc` would typeset it
        rm(typesetdir, copy)
    end
    print("Personalized copies are in " .. outdir)
    return 0
end

target_list.personalize = {
    func = personalize,
    help = "Make copies with students' names, from a file outside the repository"
}
