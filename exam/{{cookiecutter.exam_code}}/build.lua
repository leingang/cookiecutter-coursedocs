#!/usr/bin/env texlua

module = "{{cookiecutter.exam_code}}"
{% if cookiecutter.bundle_name != "" -%}
bundle = "{{cookiecutter.bundle_name}}"
maindir = ".."
{% else -%}
maindir = "."
{% endif -%}

version = "0.0"
versiondate = "{% now 'local', '%Y-%m-%d' %}"


unpackfiles  = {"*.dtx"}
unpackexe    = "latex" -- required because of the \ProvidesFile

supportdir = "support"
typesetfiles = {"*.*.tex"}
typesetexe = "lualatex"
typesetsuppfiles = {"*.png", "*.pdf", "*.sty", "*.cls", "*.lua", "*.tex"}

tagfiles = {"*.dtx", "*.lua"}

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

-- Run the vc script before generating
table.insert(typesetsuppfiles,"vc*")
function docinit_hook()
    local cmd = "texlua ./vc.lua -f -m"
    -- local cmd = "sh ./vc -f -m"
    print("Running '" .. cmd .. "'")
    errorlevel = run(typesetdir,cmd)
    assert(errorlevel == 0, 
        "Failed with status " .. errorlevel .. ": " .. cmd)
    return errorlevel
end

-- Typeset with latexmk
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

-- STAMP BARCODES
-- `l3build stamp` makes individually barcoded copies of the question PDFs
-- with stampbarcode.  `l3build stamp A B` stamps only those versions,
-- and `l3build stamp --dry-run` only prints the commands (options go
-- before version names: `l3build stamp --dry-run A`).
-- Run `l3build doc` first: this stamps the PDFs that are already built.

-- Where the stamped copies go, relative to this directory.
-- The default (nil) is the "stamped" directory in builddir.
stampdir = nil
-- The offset puts the barcode between the logo and the Aztec code on the
-- cover, and just above the header on the other pages.
stampoptions = "--position top --barwidth 1 --offset +70+5"
-- For each version to stamp: the first barcode number (a string, so that no
-- digits are lost) and the number of copies.  Versions without an entry are
-- not stamped.  An exam without versions uses the key "".
stampjobs = {
{%- if cookiecutter.get('versions_to_stamp') %}
{%- for v in cookiecutter.versions_to_stamp.split(',') %}
    ["{{ v | trim }}"] = {start = "", copies = {{ cookiecutter.number_copies }}},  -- TODO: fill in start
{%- endfor %}
{%- else %}
    -- ["A"] = {start = "1268104881013101", copies = 20},
{%- endif %}
}

function stamp(names)
    local versions = {}
    if names and #names > 0 then
        versions = names
    else
        for v, _ in pairs(stampjobs) do
            table.insert(versions, v)
        end
        table.sort(versions)
    end
    assert(#versions > 0, "Nothing to stamp: stampjobs is empty")
    local outdir = stampdir or (builddir .. "/stamped")
    for _, v in ipairs(versions) do
        local job = assert(stampjobs[v],
            "No entry for version " .. v .. " in stampjobs")
        assert(string.match(job.start, "^%d+$"),
            "Fill in the first barcode number for version " .. v .. " in stampjobs")
        local pdf = module .. (v ~= "" and ("-" .. v) or "") .. ".qns.pdf"
        assert(fileexists(pdf),
            pdf .. " does not exist; run l3build doc first")
        local cmd = string.format(
            "stampbarcode --start %s -n %d %s --output-dir \"%s\" %s",
            job.start, job.copies, stampoptions, outdir, pdf)
        if options['dry-run'] then
            print("- " .. cmd)
        else
            print("Running '" .. cmd .. "'")
            local errorlevel = run(".", cmd)
            assert(errorlevel == 0,
                "Failed with status " .. errorlevel .. ": " .. cmd)
        end
    end
    return 0
end

target_list.stamp = {
    func = stamp,
    help = "Stamp barcodes on copies of the question PDFs"
}

-- PRINT THE STAMPED COPIES
-- `l3build print` sends the stamped copies to the printers, one lpr job
-- per copy so that each is stapled.  `l3build print A B` prints only
-- those versions, and `l3build print --dry-run` only shows the plan
-- (options go before version names).  To choose the printers:
--     PRINTERS=mf-07,mf-09 l3build print A B
-- The copies and a script of lpr commands go to the print host in a single
-- ssh connection, so there is one password and MFA prompt.
-- Run `l3build stamp` first.

-- Versions that are handed out together, in the order to interleave them:
-- the first copy of each, then the second copy of each, and so on.
printgroups = {
{%- if cookiecutter.get('version_print_groups') %}
{%- for g in cookiecutter.version_print_groups.split(',') %}
    {{ '{' }}{% for v in g.split(';') %}"{{ v | trim }}"{% if not loop.last %}, {% endif %}{% endfor %}{{ '}' }},
{%- endfor %}
{%- elif cookiecutter.get('versions_to_stamp') %}
    {{ '{' }}{% for v in cookiecutter.versions_to_stamp.split(',') %}"{{ v | trim }}"{% if not loop.last %}, {% endif %}{% endfor %}{{ '}' }},
{%- else %}
    -- {"A", "B"},
{%- endif %}
}
-- The printers to split the batch among.  Each gets a contiguous run of the
-- interleaved sequence, so the stacks can be put together in printer order.
printers = {{ '{' }}{% for p in cookiecutter.print_printers.split(',') %}"{{ p | trim }}"{% if not loop.last %}, {% endif %}{% endfor %}{{ '}' }}
printoptions = "-o sides=two-sided-long-edge -o StapleLocation=UpperLeft"
-- how to reach the machine with lpr, e.g. "ssh netid@print.example.edu"
printssh = "{{ cookiecutter.print_ssh }}"

-- The rounds to print: each round is one copy of each version in a group.
-- Only versions in `wanted` are included; the rest of each group is skipped.
local function print_rounds(wanted)
    local rounds = {}
    for _, group in ipairs(printgroups) do
        local members = {}
        local maxcopies = 0
        for _, v in ipairs(group) do
            if wanted[v] then
                table.insert(members, v)
                maxcopies = math.max(maxcopies, stampjobs[v].copies)
            end
        end
        for i = 0, maxcopies - 1 do
            local round = {}
            for _, v in ipairs(members) do
                local job = stampjobs[v]
                if i < job.copies then
                    local first = assert(math.tointeger(job.start),
                        "Bad first barcode number for version " .. v)
                    table.insert(round, string.format("%s%s.qns-%d.pdf",
                        module, v ~= "" and ("-" .. v) or "", first + i))
                end
            end
            table.insert(rounds, round)
        end
    end
    return rounds
end

-- Give each printer a contiguous run of rounds, balanced by number of copies.
-- Returns a list of {printer = name, files = {...}}, without unused printers.
local function split_rounds(rounds, printernames)
    local total = 0
    for _, round in ipairs(rounds) do total = total + #round end
    local shares = {}
    local p, count = 1, 0
    for _, round in ipairs(rounds) do
        if p < #printernames and count >= p * total / #printernames then
            p = p + 1
        end
        shares[p] = shares[p] or {printer = printernames[p], files = {}}
        for _, file in ipairs(round) do
            table.insert(shares[p].files, file)
        end
        count = count + #round
    end
    local used = {}
    for i = 1, #printernames do
        if shares[i] then table.insert(used, shares[i]) end
    end
    return used, total
end

function print_stamped(names)
    -- which versions
    local wanted = {}
    if names and #names > 0 then
        for _, v in ipairs(names) do
            assert(stampjobs[v], "No entry for version " .. v .. " in stampjobs")
            wanted[v] = true
        end
    else
        for v, _ in pairs(stampjobs) do wanted[v] = true end
    end
    local grouped = {}
    for _, group in ipairs(printgroups) do
        for _, v in ipairs(group) do grouped[v] = true end
    end
    for v, _ in pairs(wanted) do
        assert(grouped[v], "Version " .. v .. " is not in printgroups")
    end
    -- which printers
    local printernames = printers
    local env = os.getenv("PRINTERS")
    if env and env ~= "" then
        printernames = {}
        for name in string.gmatch(env, "[^,%s]+") do
            table.insert(printernames, name)
        end
    end
    assert(#printernames > 0, "No printers")
    assert(printssh ~= "", "Set printssh in build.lua to the ssh command "
        .. "for the machine with lpr")

    local outdir = stampdir or (builddir .. "/stamped")
    local shares, total = split_rounds(print_rounds(wanted), printernames)
    assert(total > 0, "Nothing to print")
    local files = {}
    for _, share in ipairs(shares) do
        for _, file in ipairs(share.files) do
            assert(fileexists(outdir .. "/" .. file),
                file .. " does not exist; run l3build stamp first")
            table.insert(files, file)
        end
    end

    -- the plan
    print(string.format("%d copies on %d printer(s):", total, #shares))
    for _, share in ipairs(shares) do
        print(string.format("  %-6s %3d copies  %s ... %s", share.printer,
            #share.files, share.files[1], share.files[#share.files]))
    end

    -- Unpack in a new private directory in the home directory on the print
    -- host and run the script there.  The directory is removed when every
    -- copy is submitted, and kept if a submission fails.  It is removed
    -- after the script has exited: on NFS, a directory holding a script
    -- that is still running cannot be removed.
    -- The remote command has to work in csh as well as sh (the login shell
    -- on the print host may be tcsh), so it uses no variables or conditionals.
    local remotedir = string.format("l3build-print-%s-%d", module, os.time())
    local remote = "umask 077; mkdir " .. remotedir .. " && cd " .. remotedir
        .. " && tar -xf - && sh print.sh && cd .. && (rm -rf " .. remotedir
        .. " || echo Every copy was submitted, but " .. remotedir
        .. " could not be removed.)"
    -- Keep macOS metadata out of the archive, which GNU tar on the print host
    -- warns about: COPYFILE_DISABLE for ._ files, and the tar options for
    -- extended attributes.
    local send = "COPYFILE_DISABLE=1 tar --no-xattrs --format ustar -cf - print.sh %s | "
        .. printssh .. " '" .. remote .. "'"

    if options['dry-run'] then
        for _, share in ipairs(shares) do
            print(share.printer .. ":")
            for _, file in ipairs(share.files) do
                print("  lpr -P " .. share.printer .. " " .. printoptions
                    .. " " .. file)
            end
        end
        print("- " .. string.format(send, "<" .. #files .. " files>"))
        return 0
    end

    local script = assert(io.open(outdir .. "/print.sh", "w"))
    script:write("#!/bin/sh\n"
        .. "# Run in the directory this was unpacked in.\n"
        .. "dir=$(pwd)\n"
        .. "fail() {\n"
        .. "    echo \"Printing failed; the files are in $dir\" >&2\n"
        .. "    exit 1\n"
        .. "}\n")
    for _, share in ipairs(shares) do
        for _, file in ipairs(share.files) do
            script:write(string.format('echo "%s: %s"\n', share.printer, file))
            script:write(string.format("lpr -P %s %s %s || fail\n",
                share.printer, printoptions, file))
        end
    end
    script:write(string.format('echo "Submitted %d copies."\n', #files))
    script:close()

    print("Sending " .. #files .. " files with " .. printssh)
    local errorlevel = run(outdir, string.format(send, table.concat(files, " ")))
    assert(errorlevel == 0, "Printing failed with status " .. errorlevel)
    return 0
end

target_list.print = {
    func = print_stamped,
    help = "Print the stamped copies, interleaved by version"
}

-- l3build install --full will install the pdfs in the directory below
options['texmfhome'] = "{{ cookiecutter.install_dir }}"
-- TODO set sourcefiles to nil only during installation
tdslocations = {'*.*.pdf',"*.dtx"}


