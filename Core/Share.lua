local _, ns = ...
local U, G, P = ns.U, ns.Generator, ns.Parser

-- Share codes: a macro packed into one line of text that can be pasted in a
-- chat, on Discord or on a forum.
--
--   BM1!<base64url( checksum .. name "\n" icon "\n" macro text )>
--
-- The code carries the macro TEXT, not our block layout: importing goes through
-- the same parser as a macro edited outside the addon, so a code can never put
-- anything in the editor that the parser would not accept, and what it can't
-- turn into blocks shows up as a visible "raw text" block. Nothing is ever
-- saved by an import: the macro opens as a new, unsaved one.
local Sh = {}
ns.Share = Sh

Sh.PREFIX = "BM1!"
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local MAX_CODE, MAX_BODY, MAX_NAME = 2400, 1023, 48

local VALUE = {}
for i = 1, 64 do VALUE[ALPHABET:byte(i)] = i - 1 end

local function chr(n) return ALPHABET:sub(n + 1, n + 1) end

local function b64(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144)
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = chr(c1) .. chr(c2) .. (b and chr(c3) or "") .. (c and chr(c4) or "")
    end
    return table.concat(out)
end

local function unb64(s)
    if #s % 4 == 1 then return nil end
    local out = {}
    for i = 1, #s, 4 do
        local v1, v2, v3, v4 = VALUE[s:byte(i)], VALUE[s:byte(i + 1) or 0], VALUE[s:byte(i + 2) or 0], VALUE[s:byte(i + 3) or 0]
        if not v1 or not v2 then return nil end
        local n = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
        local a = math.floor(n / 65536)
        local b = math.floor(n / 256) % 256
        local c = n % 256
        out[#out + 1] = string.char(a) .. (v3 and string.char(b) or "") .. (v4 and string.char(c) or "")
    end
    return table.concat(out)
end

-- Adler-32 style checksum, as 8 hex digits: catches a code cut short or mistyped.
local function checksum(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return ("%04x%04x"):format(b, a)
end

function Sh.Encode(macro)
    local name = U.trim(macro.name):gsub("[\r\n|]", "")
    local icon = tostring(macro.icon or U.DEFAULT_ICON):gsub("[\r\n]", "")
    local payload = name .. "\n" .. icon .. "\n" .. G.Build(macro)
    return Sh.PREFIX .. b64(checksum(payload) .. payload)
end

-- Returns the macro model and the number of lines kept as raw text,
-- or nil and the locale key of the error.
function Sh.Decode(code)
    code = tostring(code or ""):gsub("%s+", "")
    if #code > MAX_CODE then return nil, "ERR_CODE" end
    local data = code:match("BM1!([%w%-_]+)")
    if not data then
        if code:find("BM1!", 1, true) then return nil, "ERR_CODE_DAMAGED" end
        return nil, code:find("BM%d+!") and "ERR_CODE_VERSION" or "ERR_CODE"
    end
    local raw = unb64(data)
    if not raw or #raw < 10 then return nil, "ERR_CODE_DAMAGED" end
    local sum, payload = raw:sub(1, 8), raw:sub(9)
    if checksum(payload) ~= sum then return nil, "ERR_CODE_DAMAGED" end
    local name, icon, body = payload:match("^([^\n]*)\n([^\n]*)\n(.*)$")
    if not name or #body > MAX_BODY then return nil, "ERR_CODE_DAMAGED" end

    -- "|" starts colour and texture codes in WoW text: a shared macro could use
    -- them to hide part of a line in the explanation, so they are dropped.
    name = U.trim(name:gsub("|", ""))
    if #name > MAX_NAME then name = "" end
    body = body:gsub("\r", ""):gsub("|", "")

    local D = ns.Data
    local macro = P.Parse(body, D and D.Resolve, name)
    if tonumber(icon) then
        macro.icon = tonumber(icon)
    elseif icon:match("^[%w_%-%.\\/]+$") then
        macro.icon = icon
    end
    if #G.Build(macro) > 255 then macro.compact = true end

    local rawLines = 0
    for _, line in ipairs(macro.lines) do
        if line.kind == "raw" then rawLines = rawLines + 1 end
    end
    return macro, rawLines
end
