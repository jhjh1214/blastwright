--!strict
-- Leaderboard ranking and text. Pure: no Roblox APIs. Input rows are { Name = string, Value = number }.

local Board = {}

local function commas(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function isValid(row: any): boolean
	return type(row) == "table"
		and type(row.Name) == "string"
		and type(row.Value) == "number"
		and row.Value == row.Value -- not NaN
		and row.Value >= 0
		and row.Value < math.huge
end

-- Valid rows only, highest value first (ties by name), at most maxRows. Does not modify the input.
function Board.Rank(rows: { any }, maxRows: number): { { Name: string, Value: number } }
	local clean: { { Name: string, Value: number } } = {}
	for _, row in rows do
		if isValid(row) then
			table.insert(clean, { Name = row.Name, Value = row.Value })
		end
	end
	table.sort(clean, function(a: { Name: string, Value: number }, b: { Name: string, Value: number })
		if a.Value ~= b.Value then
			return a.Value > b.Value
		end
		return a.Name < b.Name
	end)
	while #clean > maxRows do
		table.remove(clean)
	end
	return clean
end

-- Multi-line board text (meant for a monospaced font).
function Board.Format(title: string, rows: { any }, maxRows: number): string
	local ranked = Board.Rank(rows, maxRows)
	local lines = { title }
	if #ranked == 0 then
		table.insert(lines, "No chains yet. Be the first!")
	end
	for i, row in ranked do
		local name = #row.Name > 18 and (row.Name:sub(1, 17) .. "~") or row.Name
		table.insert(lines, ("%2d  %-18s %7s"):format(i, name, commas(row.Value)))
	end
	return table.concat(lines, "\n")
end

return Board
