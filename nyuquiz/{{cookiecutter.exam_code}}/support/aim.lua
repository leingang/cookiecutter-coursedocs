-- UPLOADS TO THE TESTING CENTER (AIM)
-- Load from build.lua with `dofile(supportdir .. "/aim.lua")`, after
-- support/personalize.lua.
--
-- `l3build aimupload` uploads each student's personalized copy (made with
-- `l3build personalize`) to their testing-center session in AIM, with
-- `edubag aim client upload-exams`.  A session is this exam's if it is for
-- this course and section (any of them, for "016+021" in course.yml), its
-- type is `aimtype` (a string, or a list such as {"Exam", "Final"}), and
-- its date is on or
-- after `aimdate` and before `aimbefore` (so makeups count).  Each file's
-- title is "<aimexam> · <tag> · <name> (<netid>)", so AIM shows which
-- version a session has:
-- * a session with no file of this module gets one;
-- * a session with a file of an older tag gets the new one, and the old one
--   is deleted;
-- * a session with this tag's file is skipped, as is one with a file that
--   was uploaded by hand.
-- So run it again whenever students book sessions.  Students without a
-- session yet are listed as "waiting".
--
-- `l3build aimupload --dry-run` only shows the plan; `l3build aimupload
-- abc123` uploads only that student's copy; the word `headed` shows the
-- browser.  `l3build install --full` runs it too, after the coursedata
-- copies, unless `aimoninstall` is false.
--
-- Each upload is recorded in `aimledger`, outside the repository.  The
-- config for edubag, with NetIDs and names, is written next to the
-- personalized copies in the build directory.
aimexam = aimexam or module
aimtype = aimtype or "Quiz"
aimdate = aimdate         -- nil: the \date in the .dtx
aimbefore = aimbefore     -- nil: the date of the next module like this one
aimledger = os.getenv("AIM_LEDGER") or aimledger
    or "../../../Students/aim-uploads.json"
aimcmd = os.getenv("EDUBAG") or aimcmd or "edubag"
if aimoninstall == nil then aimoninstall = true end

local months = {January = 1, February = 2, March = 3, April = 4, May = 5,
    June = 6, July = 7, August = 8, September = 9, October = 10,
    November = 11, December = 12}

-- The \date of a .dtx file as YYYY-MM-DD, or nil.
local function dtx_date(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("a")
    f:close()
    local month, day, year = text:match("\n\\date{(%a+)%s+(%d+),%s*(%d%d%d%d)")
    if not month or not months[month] then return nil end
    return string.format("%s-%02d-%02d", year, months[month], tonumber(day))
end

-- The date of the next module of the same kind (q09 -> q10, mt1 -> mt2).
local function next_module_date(date)
    local kind = module:match("^%a+")
    local best
    for _, dir in ipairs(filelist("..", kind .. "*")) do
        if dir ~= module and dir:match("^" .. kind .. "%d+$") then
            local d = dtx_date("../" .. dir .. "/" .. dir .. ".dtx")
            if d and d > date and (not best or d < best) then best = d end
        end
    end
    return best
end

-- A value from ../course.yml (key: "value").
local function course_value(key)
    local f = io.open("../course.yml", "r")
    if not f then return nil end
    local text = f:read("a")
    f:close()
    return text:match("\n%s*" .. key .. ':%s*"([^"]*)"')
end

local function json_string(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' end
        if c == "\\" then return "\\\\" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end

local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function git(args)
    local p = io.popen("git " .. args .. " 2>/dev/null")
    local out = p:read("a")
    p:close()
    return (out:gsub("%s+$", ""))
end

function aimupload(names)
    local dry_run = options["dry-run"]
    local args, netids = dry_run and " --dry-run" or "", {}
    for _, word in ipairs(names or {}) do
        if word == "headed" then
            args = args .. " --headed"
        elseif word:match("^[a-z]+%d+$") then
            netids[word] = true
            args = args .. " --netid " .. word
        else
            error("Unknown word '" .. word .. "' (give NetIDs, or headed)")
        end
    end

    -- Only clean, tagged versions go to the testing center.
    local mark, why = personal_watermark()
    if mark then
        print("Not uploading: the personalized copies would be watermarked " .. mark .. ".")
        print(why)
        if not dry_run then return 1 end
    end
    local pattern = doctagmatch and doctagmatch() or (module .. "-v*")
    local tag = git('describe --tags --abbrev=0 --match "' .. pattern .. '" HEAD')
    if tag == "" then
        print("Not uploading: no tag like " .. module .. "-v*")
        return 1
    end
    local tagtime = tonumber(git("log -1 --format=%ct " .. tag .. "^{commit}")) or 0

    local date = aimdate or dtx_date(module .. ".dtx")
    assert(date, "No \\date in " .. module .. ".dtx; set aimdate in build.lua")
    local before = aimbefore or next_module_date(date)
    local subject = course_value("department_code")
    local course = course_value("course_number")
    local section = course_value("section_number")
    assert(subject and course and section,
        "No department_code, course_number and section_number in ../course.yml")
    local sections = {}
    for sec in section:gmatch("[^+,%s]+") do table.insert(sections, json_string(sec)) end
    local types = {}
    for _, t in ipairs(type(aimtype) == "table" and aimtype or {aimtype}) do
        table.insert(types, json_string(t))
    end

    local students, path = personal_students()
    if not students then
        print(path) -- the error message
        return 1
    end
    -- The copies must be made from this version, after `l3build doc`.
    local newest = tagtime
    for _, tex in ipairs(filelist(typesetdir, module .. "*.qns.tex")) do
        local t = lfs.attributes(typesetdir .. "/" .. tex, "modification") or 0
        if t > newest then newest = t end
    end
    local outdir = personaldir or (builddir .. "/personalized")
    local entries, stale, found = {}, {}, {}
    for _, s in ipairs(students) do
        if next(netids) == nil or netids[s.netid] then
            found[s.netid] = true
            local pdf = module .. "-" .. s.netid .. ".qns.pdf"
            local t = lfs.attributes(outdir .. "/" .. pdf, "modification")
            if not t or t < newest then table.insert(stale, pdf) end
            table.insert(entries, string.format('    {"netid": %s, "name": %s, "pdf": %s}',
                json_string(s.netid), json_string(s.name), json_string(pdf)))
        end
    end
    for netid, _ in pairs(netids) do
        assert(found[netid], netid .. " has no copy of " .. module .. " in " .. path)
    end
    if #entries == 0 then
        print("No personalized copies of " .. module .. " in " .. path)
        return 0
    end
    if #stale > 0 then
        print(string.format("%d personalized cop%s missing or older than %s or `l3build doc`:",
            #stale, #stale == 1 and "y is" or "ies are", tag))
        for _, pdf in ipairs(stale) do print("  " .. pdf) end
        print("Run `l3build personalize` first.")
        if not dry_run then return 1 end
    end

    local ledger = aimledger
    if not ledger:match("^/") then ledger = lfs.currentdir() .. "/" .. ledger end
    local config = module .. "-aim.yml"
    mkdir(outdir)
    local f = assert(io.open(outdir .. "/" .. config, "w"))
    f:write("# Written by `l3build aimupload` from build.lua (JSON is YAML). Student data.\n",
        "{\n",
        '  "module": ', json_string(module), ",\n",
        '  "tag": ', json_string(tag), ",\n",
        '  "exam": ', json_string(aimexam), ",\n",
        '  "match": {"type": [', table.concat(types, ", "), "]",
        ', "subject": ', json_string(subject), ', "course": ', json_string(course),
        ', "section": [', table.concat(sections, ", "), '], "date": ', json_string(date),
        before and (', "before": ' .. json_string(before)) or "", "},\n",
        '  "ledger": ', json_string(ledger), ",\n",
        '  "students": [\n', table.concat(entries, ",\n"), "\n  ]\n}\n")
    f:close()
    os.execute("chmod 600 " .. shell_quote(outdir .. "/" .. config))

    print(string.format("%s %s: %s sessions from %s%s", module, tag,
        type(aimtype) == "table" and table.concat(aimtype, "/") or aimtype, date,
        before and (" to before " .. before) or ""))
    local cmd = aimcmd .. " aim client upload-exams " .. config .. args
    print("Running '" .. cmd .. "' in " .. outdir)
    local errorlevel = run(outdir, cmd)
    -- edubag exits 2 when some students need attention (two sessions, or no
    -- PDF yet); in a dry run that is only a report.
    if errorlevel == 2 and dry_run then
        print("(some students need attention; see above)")
        return 0
    end
    return errorlevel
end

target_list.aimupload = {
    func = aimupload,
    help = "Upload the personalized copies to students' testing-center sessions in AIM"
}
