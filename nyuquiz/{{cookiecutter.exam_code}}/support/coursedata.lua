-- COPIES FOR THE COURSEDATA REPOSITORY
-- Load from build.lua with `dofile(supportdir .. "/coursedata.lua")`, after
-- support/personalize.lua.
--
-- When `coursedata_repo` is set, `l3build install --full` also copies what
-- the coursedata repository needs to process scans of this exam or quiz:
-- * the blank versions that `l3build doc` made (<module>-<version>.qns.pdf)
--   and a personalized copy for each student in the student file (made with
--   `l3build personalize`), to <coursedata_repo>/data/raw/artifacts/<module>/templates/
-- * the student file, to <coursedata_repo>/data/raw/artifacts/personalized-exams.csv
-- Files already there are replaced, never deleted.
--
-- Nothing is copied unless every copy can be made: if the personalized
-- copies would be watermarked (uncommitted changes, or commits since the
-- last tag), or `personalize` fails, the install stops with an error after
-- installing as usual.  `l3build install --full --dry-run` only shows the
-- plan.
--
-- After these copies, `l3build install --full` also runs `l3build aimupload`
-- when build.lua loads support/aim.lua (and `aimoninstall` isn't false).
coursedata_repo = coursedata_repo -- nil (or "") skips all of this

local function copy_file(source, dest)
    local f = assert(io.open(source, "rb"), "Cannot read " .. source)
    local data = f:read("a")
    f:close()
    f = assert(io.open(dest, "wb"), "Cannot write " .. dest)
    f:write(data)
    f:close()
end

local function modified(path)
    return lfs.attributes(path, "modification") or 0
end

local function copy_to_coursedata()
    local dry_run = options["dry-run"]
    local repo = coursedata_repo:gsub("/+$", "")
    if not direxists(repo) then
        print("coursedata_repo " .. repo .. " is not a directory")
        return 1
    end
    local artifacts = repo .. "/data/raw/artifacts"
    local templates = artifacts .. "/" .. module .. "/templates"

    -- Copy nothing if the personalized copies would be refused.  (A dry run
    -- goes on; personalize below reports the watermark.)
    local mark, why = personal_watermark()
    if mark and not dry_run then
        print("Not copying to " .. repo .. ": the personalized copies would be watermarked "
            .. mark .. ".")
        print(why)
        return 1
    end

    -- the versions that `doc` made: those with a generated .qns.tex (personalize
    -- removes the .tex of its copies, but not their PDFs)
    local versions = {}
    for _, tex in ipairs(filelist(typesetdir, module .. "*.qns.tex")) do
        local pdf = tex:gsub("%.tex$", ".pdf")
        assert(fileexists(typesetdir .. "/" .. pdf), pdf .. " is not in " .. typesetdir)
        table.insert(versions, pdf)
    end
    table.sort(versions)
    if #versions == 0 then
        print("No " .. module .. "*.qns.tex in " .. typesetdir .. "; did `l3build doc` run?")
        return 1
    end

    -- Make the personalized copies; keep only the ones made now.
    local started = os.time()
    local errorlevel = personalize({})
    if errorlevel ~= 0 then
        print("Not copying to " .. repo .. ": personalize failed")
        return errorlevel
    end
    local outdir = personaldir or (builddir .. "/personalized")
    local personal = {}
    if direxists(outdir) then
        for _, pdf in ipairs(filelist(outdir, module .. "-*.qns.pdf")) do
            if modified(outdir .. "/" .. pdf) >= started then
                table.insert(personal, pdf)
            end
        end
    end
    table.sort(personal)

    local students = os.getenv("STUDENTS")
    if not students or students == "" then students = personalfile end
    local csv = artifacts .. "/personalized-exams.csv"

    print("Copying to " .. templates .. ":")
    for _, pdf in ipairs(versions) do print("  " .. pdf) end
    if dry_run then
        print("  and the personalized copies listed above")
    else
        for _, pdf in ipairs(personal) do print("  " .. pdf) end
    end
    print("Copying " .. students .. " to " .. csv)
    if dry_run then return 0 end

    mkdir(templates)
    for _, pdf in ipairs(versions) do
        copy_file(typesetdir .. "/" .. pdf, templates .. "/" .. pdf)
    end
    for _, pdf in ipairs(personal) do
        copy_file(outdir .. "/" .. pdf, templates .. "/" .. pdf)
    end
    copy_file(students, csv)
    return 0
end

local install_func = target_list.install.func
target_list.install.func = function(names)
    local errorlevel = install_func(names)
    if errorlevel ~= 0 or not options["full"] then return errorlevel end
    if coursedata_repo and coursedata_repo ~= "" then
        errorlevel = copy_to_coursedata()
        if errorlevel ~= 0 then return errorlevel end
    end
    -- then the uploads to the testing center (support/aim.lua), if loaded
    if aimupload and aimoninstall then return aimupload({}) end
    return 0
end
