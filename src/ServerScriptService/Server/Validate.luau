--!strict
-- Validation of untrusted client payloads. Pure: no Roblox APIs.
local Validate = {}

local function isInt(n: any): boolean
	return type(n) == "number" and n == n and n % 1 == 0 and n > -1e9 and n < 1e9
end

-- payload: raw Detonate argument. Returns (charges, nil) or (nil, reason).
-- Rebuilds a clean list so no client-supplied table or extra field is ever used downstream.
function Validate.Volley(
	payload: any,
	chargesLeft: number,
	unlocked: { [string]: boolean },
	gridSize: number,
	maxVolley: number
): ({ { X: number, Z: number, Kind: string } }?, string?)
	if type(payload) ~= "table" then
		return nil, "payload not a table"
	end
	local count = #payload
	if count < 1 then
		return nil, "empty volley"
	end
	if count > maxVolley or count > chargesLeft then
		return nil, "too many charges"
	end

	local clean = {}
	local seen: { [number]: boolean } = {}
	for i = 1, count do
		local entry = payload[i]
		if type(entry) ~= "table" then
			return nil, "entry not a table"
		end
		local x, z, kind = entry.X, entry.Z, entry.Kind
		if not isInt(x) or not isInt(z) then
			return nil, "coords not integers"
		end
		if x < 1 or x > gridSize or z < 1 or z > gridSize then
			return nil, "coords out of range"
		end
		if type(kind) ~= "string" or unlocked[kind] ~= true then
			return nil, "charge not unlocked"
		end
		local key = (z - 1) * gridSize + x
		if seen[key] then
			return nil, "duplicate cell"
		end
		seen[key] = true
		table.insert(clean, { X = x, Z = z, Kind = kind })
	end
	return clean, nil
end

-- A settings change from the client. Only known keys with boolean values are accepted.
function Validate.Setting(name: any, value: any): (string?, boolean?)
	if (name == "Music" or name == "Sfx") and type(value) == "boolean" then
		return name :: string, value :: boolean
	end
	return nil, nil
end

return Validate
