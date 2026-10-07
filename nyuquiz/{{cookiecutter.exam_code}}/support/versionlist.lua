--- Version-distinct draws from randomlist lists.
---
--- Every version of a document shuffles a list the same way (using a seed
--- shared by all versions), and version k takes position k of the shuffle.
--- So different versions always get different items, but which version gets
--- which item is still random.
---
--- The shuffle uses its own generator, so it does not disturb math.random,
--- randomlist, or pgf.
local module = {}

--- djb2 string hash, reduced to 32 bits.
--- @param s string
--- @return integer
local function hash(s)
    local h = 5381
    for i = 1, #s do
        h = ((h << 5) + h + s:byte(i)) & 0xFFFFFFFF
    end
    return h
end

--- A permutation of 0, ..., n-1, determined by the seed and the key.
---
--- @param n integer The length of the list.
--- @param seed integer|string The seed shared by all versions.
--- @param key string Distinguishes lists, so each gets its own shuffle.
--- @return table A Lua array (1-indexed) of 0-based list indices.
function module.permutation(n, seed, key)
    local state = (math.tointeger(tonumber(seed)) ~ hash(key)) & 0xFFFFFFFF
    -- 32-bit linear congruential generator (Numerical Recipes constants);
    -- use the high bits, since the low bits of an LCG are weak.
    local function rand(m)
        state = (1664525 * state + 1013904223) & 0xFFFFFFFF
        return (state >> 8) % m
    end
    local p = {}
    for i = 1, n do p[i] = i - 1 end
    for i = n, 2, -1 do
        local j = rand(i) + 1
        p[i], p[j] = p[j], p[i]
    end
    return p
end

--- The 0-based index of the item version k should get.
---
--- @param n integer The length of the list.
--- @param seed integer|string The seed shared by all versions.
--- @param key string The list name.
--- @param k integer The version index, 1 <= k <= n.
--- @return integer
function module.pick(n, seed, key, k)
    return module.permutation(n, seed, key)[k]
end

return module
