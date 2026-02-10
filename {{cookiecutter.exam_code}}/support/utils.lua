local module = {}


--- Checks if all elements in a given list are distinct.
--- 
--- This function iterates through the provided list and determines
--- whether all elements are unique. If a duplicate is found, it 
--- returns `false`. Otherwise, it returns `true`.
---
--- @param valueList table A list of values to check for uniqueness.
--- @return boolean `true` if all elements are distinct, `false` otherwise.
function module.are_distinct(valueList)
    local seen = {}
    for _, value in ipairs(valueList) do
        if seen[value] then
        return false -- Found a duplicate
        else
        seen[value] = true
        end
    end
    return true -- No duplicates found
end

--- Shuffles the elements of a given table in place.
--- This function randomizes the order of elements in the input table `t`.
--- 
--- @param t table The table to be shuffled. The table is modified in place.
--- @return table The shuffled table.
function module.shuffle(t)
    local n = #t
    for i = n, 2, -1 do
      -- Generate a random index j such that 1 <= j <= i
      local j = math.random(1, i)  -- math.random(i)  -- Shorter, equivalent
      -- Swap t[i] and t[j]
      t[i], t[j] = t[j], t[i]
    end
end

return module