local _, ns = ...
local G = ns.Generator

-- Live test: asks the game which branch of each line would fire right now.
-- SecureCmdOptionParse only reads conditions, it is allowed in and out of combat.
local V = {}
ns.Evaluator = V

-- Returns { [lineIndex] = { branch = n|nil, unit = "target"|... } } for lines with branches.
function V.Evaluate(macro)
    local res = {}
    if not SecureCmdOptionParse then return res end
    for li, line in ipairs(macro.lines or {}) do
        local branches
        if line.kind == "cast" then branches = line.branches
        elseif line.kind == "sequence" then branches = { line.branch or {} } end
        if branches and #branches > 0 then
            local parts = {}
            for j, b in ipairs(branches) do parts[j] = G.Cond(b) .. " " .. j end
            local ok, result, unit = pcall(SecureCmdOptionParse, table.concat(parts, "; "))
            local n = ok and tonumber(result) or nil
            res[li] = { branch = n, unit = n and (unit or "target") or nil }
        end
    end
    return res
end
