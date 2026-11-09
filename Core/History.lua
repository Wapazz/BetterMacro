local _, ns = ...
local U = ns.U

-- Undo / redo for the editor. Each step is a full copy of the macro model,
-- plus the "lineage" it belongs to (see MainFrame: one lineage per macro that
-- was opened or created), so undo can also step back across "New macro" or a
-- template click.
local H = {}
ns.History = H

H.MAX = 60

function H.New()
    return { list = {}, pos = 0, tag = nil }
end

local function entry(macro, lin)
    return { m = U.copy(macro), lin = lin, sig = tostring(lin) .. "|" .. U.sig(macro) }
end

-- Records the current state if it differs from the current step.
-- Steps with the same non-nil tag (typing in the name box) are merged.
-- Returns true when something was recorded.
function H.Record(h, macro, tag, lin)
    local e = entry(macro, lin)
    local cur = h.list[h.pos]
    if cur and cur.sig == e.sig then return false end
    if tag and h.tag == tag and h.pos == #h.list and h.pos > 1 and cur.lin == lin then
        h.list[h.pos] = e
        return true
    end
    for i = #h.list, h.pos + 1, -1 do h.list[i] = nil end
    h.list[#h.list + 1] = e
    while #h.list > H.MAX do table.remove(h.list, 1) end
    h.pos = #h.list
    h.tag = tag
    return true
end

function H.CanUndo(h) return h.pos > 1 end
function H.CanRedo(h) return h.pos < #h.list end

local function at(h)
    local e = h.list[h.pos]
    h.tag = nil
    return U.copy(e.m), e.lin
end

-- Both return a copy of the macro and its lineage, or nil when there is nothing to do.
function H.Undo(h)
    if not H.CanUndo(h) then return nil end
    h.pos = h.pos - 1
    return at(h)
end

function H.Redo(h)
    if not H.CanRedo(h) then return nil end
    h.pos = h.pos + 1
    return at(h)
end
