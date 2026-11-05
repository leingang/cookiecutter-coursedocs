-- TRANSPARENCY CHECK
-- Load from build.lua with `dofile(supportdir .. "/transparency.lua")`.
--
-- The department printers are very slow with pages that use transparency:
-- a 20-page exam with shaded regions drawn at `fill opacity=0.25` took about
-- 90 seconds per copy to process.  So the targets that make copies to print
-- (`stamp`, `personalize`) refuse a PDF that uses transparency.  To make
-- them anyway:
--     ALLOW_TRANSPARENCY=1 l3build stamp
-- (l3build reads its command-line options before build.lua, so a target
-- can't have an option of its own.)
--
-- What counts as transparency, in what the page draws:
-- * a graphics state (gs) with fill or stroke opacity (/ca, /CA) below 1,
--   a soft mask (/SMask), or a blend mode (/BM) other than Normal;
-- * a form XObject that is a transparency group;
-- * an image with a soft mask (/SMask), such as a PNG with alpha.
-- Graphics included from PDF files (\includegraphics of a .pdf; the logo,
-- the bubble sheet, the formula sheet) are not checked: the cover logo has a
-- transparency group, and exams with it have always printed promptly.
--
-- Uses LuaTeX's pdfe and pdfscanner libraries, which texlua has.

-- Is a form XObject a graphic included from a PDF file?  pdfTeX, LuaTeX and
-- xdvipdfmx mark those with /PTEX.* keys.
local function is_included_pdf(xobject)
    return xobject["PTEX.PageNumber"] ~= nil
        or xobject["PTEX.FileName"] ~= nil
        or xobject["PTEX.InfoDict"] ~= nil
end

-- What is transparent about a graphics state dictionary, or nil.
local function gs_transparency(gs)
    local found = {}
    for _, key in ipairs({"ca", "CA"}) do
        local value = gs[key]
        if type(value) == "number" and value < 1 then
            table.insert(found, "/" .. key .. " " .. value)
        end
    end
    local smask = gs.SMask
    if smask ~= nil and smask ~= "None" then
        table.insert(found, "/SMask")
    end
    local bm = gs.BM
    if type(bm) == "string" and bm ~= "Normal" and bm ~= "Compatible" then
        table.insert(found, "/BM /" .. bm)
    end
    if #found > 0 then return table.concat(found, ", ") end
end

-- A page's resources, which may be inherited from the page tree.
local function page_resources(page)
    local node = page
    while node do
        if node.Resources then return node.Resources end
        node = node.Parent
    end
end

-- Scan a content stream (or array of streams) with its resources, adding
-- what is transparent to `found` (a set of descriptions).
local function scan(content, resources, found, depth)
    if depth > 20 then return end -- a malformed PDF could nest forms forever
    local extgstates = resources and resources.ExtGState
    local xobjects = resources and resources.XObject
    local operators = {
        gs = function(scanner)
            local name = scanner:popname()
            local gs = extgstates and extgstates[name]
            local what = gs and gs_transparency(gs)
            if what then found["graphics state /" .. name .. " (" .. what .. ")"] = true end
        end,
        Do = function(scanner)
            local name = scanner:popname()
            local xobject = xobjects and xobjects[name]
            if not xobject then return end
            if xobject.Subtype == "Image" then
                if xobject.SMask ~= nil then
                    found["image /" .. name .. " with a soft mask"] = true
                end
            elseif xobject.Subtype == "Form" and not is_included_pdf(xobject) then
                local group = xobject.Group
                if group and group.S == "Transparency" then
                    found["transparency group /" .. name] = true
                end
                scan(xobject, xobject.Resources or resources, found, depth + 1)
            end
        end,
    }
    pdfscanner.scan(content, operators, {})
end

-- The pages of a PDF that use transparency, as a list of
-- {page = n, what = {descriptions}}.
function transparent_pages(path)
    local doc = pdfe.open(path)
    assert(doc and pdfe.getstatus(doc) >= 0, "Cannot read " .. path)
    local pages = {}
    for n = 1, pdfe.getnofpages(doc) do
        local page = pdfe.getpage(doc, n)
        local found = {}
        if page.Contents then
            scan(page.Contents, page_resources(page), found, 0)
        end
        local what = {}
        for description in pairs(found) do table.insert(what, description) end
        if #what > 0 then
            table.sort(what)
            table.insert(pages, {page = n, what = what})
        end
    end
    pdfe.close(doc)
    return pages
end

-- Refuse a PDF that will be printed if it uses transparency, unless
-- ALLOW_TRANSPARENCY is set.  Returns true if the PDF may be printed.
function check_transparency(path)
    local pages = transparent_pages(path)
    if #pages == 0 then return true end
    local allowed = (os.getenv("ALLOW_TRANSPARENCY") or "") ~= ""
    print((allowed and "Warning: " or "Error: ") .. path
        .. " uses transparency, which the printers are very slow with:")
    for _, p in ipairs(pages) do
        print(string.format("  page %d: %s", p.page, table.concat(p.what, "; ")))
    end
    if allowed then
        print("  Continuing, because ALLOW_TRANSPARENCY is set.")
        return true
    end
    print("  Use opaque colors instead (e.g. fill=tertiary!25, not fill opacity=0.25),")
    print("  or set ALLOW_TRANSPARENCY=1 to make the copies anyway.")
    return false
end
