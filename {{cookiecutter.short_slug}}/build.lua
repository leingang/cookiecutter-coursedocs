bundle     = "{% set bundle = cookiecutter.course_number.lower().replace(' ', '-') + '-' + cookiecutter.section %}{{ bundle }}"
module     = "{{ bundle }}-{{ cookiecutter.short_slug }}"
pkgversion = "0.0.1"
pkgdate    = "{% now 'local' %}"

unpackfiles  = {"*.dtx"}
unpackexe    = "latex" -- required because of the \ProvidesFile

typesetfiles = {"*.*.tex"}
typesetsuppfiles = {"*.sty", "*.png", "*.pdf","latexmkrc"}

-- these aren't used because of the typeset function below
-- but just in case
-- typesetexe   = "xelatex"
-- typesetopts  = "-interaction=nonstopmode -halt-on-error -file-line-error"


-- disable installation since I'm not *actually* writing a module to be
-- installed in texmf
-- Thanks @josephwright https://github.com/latex3/l3build/discussions/208
target_list.install = null


-- function docinit_hook()
--     print("** Copying latexmkrc from "..sourcefiledir.." to "..unpackdir)
--     errorlevel = cp("latexmkrc", sourcefiledir, unpackdir)
--     if errorlevel ~= 0 then
--         error("** Error!!: Can't copy latexmkrc from "..sourcefiledir.." to "..unpackdir)
--         return errorlevel
--     else
--         print("OK")
--     end
--     return 0
-- end


-- function typeset(file)
--     local name = jobname(file)
--     local cmd = "latexmk -r latexmkrc " .. file
--     print("Running '" .. cmd .. "'")
--     errorlevel = run(unpackdir,cmd)
--       if errorlevel ~= 0 then
--         error("latexmk failed")
--         return errorlevel
--       else
--         print("OK")
--     end
--     return 0
--   end

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

tagfiles = {"*.dtx","build.lua","README.md"}

--decorator to only run if repo is clean
function only_if_clean(f)
    return function(x)
        if os.capture("git status --porcelain") ~= "" then
            print("Error: Repository is dirty.  Aborted.")
            os.exit(1)
        else
            print("Repository is clean")
            return f(x)
        end
    end 
end

-- tag = only_if_clean(tag)
target_list.tag.pre = only_if_clean(target_list.tag.pre)


local mydate = os.date("!%Y-%m-%d")
function update_tag(file,content,tagname,tagdate)
    if not tagname and tagdate == mydate then
        tagname = pkgversion
        tagdate = pkgdate
    else
        local v_maj, v_min = string.match(tagname, "^v?(%d+)(%S*)$")
        if v_maj == "" or not v_min then
          print("Error: Invalid tag '"..tagname.."'. Tagging aborted")
          os.exit(0)
        else
          tagname = string.format("%i%s", v_maj, v_min)
          tagdate = mydate
        end
    end
    if string.match(file, "%.dtx") then
        local tagdate = string.gsub(tagdate, "-", "/")
        content = string.gsub(content,
                              "%[%d%d%d%d%/%d%d%/%d%d%s+v%S+",
                              "["..tagdate.." v"..tagname)
    end
    if string.match(file, "%.md") then
        local tagdate = string.gsub(tagdate, "/", "-")
        content = string.gsub(content,
                              "Version: (%d+)(%S+)",
                              "Version: "..tagname)
        content = string.gsub(content,
                              "Date: %d%d%d%d%-%d%d%-%d%d",
                              "Date: "..tagdate)
    end
    if string.match(file , "%.lua$") then
        local tagdate = string.gsub(tagdate, "/", "-")
        content = string.gsub (content,
                               '\npkgversion%s*= "(%d+)(%S+)"',
                               '\npkgversion = "' .. tagname .. '"')
        content = string.gsub (content,
                               '\npkgdate%s*= "%d%d%d%d%-%d%d%-%d%d"',
                               '\npkgdate    = "' .. tagdate .. '"')
    end
    return content
end


function tag_hook(tagname,tagdate)
    local v_maj, v_min = string.match(tagname, "^v?(%d+)(%S*)$")
    if v_maj == "" or not v_min then
      print("Error: Invalid tag '".. tagname .."'. Git tagging aborted")
      os.exit(0)
    else
      version = string.format("%i%s", v_maj, v_min)
    end
    msg = "Tagging version " .. version
    cmd = 'git commit -a -m "' .. msg .. '"'
    print ("Running '" .. cmd .. "'")
    shell(cmd)
    cmd = 'git tag -a -m "' .. msg ..  '" ' .. tagname
    print ("Running '" .. cmd .. "'")
    shell(cmd)
end

-- disable installation since I'm not *actually* writing a module to be
-- installed in texmf
-- Thanks @josephwright https://github.com/latex3/l3build/discussions/208
target_list.install = null



