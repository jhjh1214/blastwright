--!strict
-- Purchase bookkeeping. Pure (no Roblox APIs) so idempotency can be unit-tested.
-- Roblox may call ProcessReceipt several times for one purchase; a PurchaseId must only ever grant once.
local Receipts = {}

local MAX_ENTRIES = 300

-- Records a purchase id in `purchases` ({ [id] = unixTime }). Returns true if it is new, false if already granted.
function Receipts.Apply(purchases: { [string]: number }, purchaseId: string, now: number): boolean
	if purchases[purchaseId] ~= nil then
		return false
	end
	purchases[purchaseId] = now

	-- Keep the save small: drop the oldest entries beyond MAX_ENTRIES.
	local count = 0
	for _ in purchases do
		count += 1
	end
	while count > MAX_ENTRIES do
		local oldestId, oldestTime = nil, math.huge
		for id, t in purchases do
			if t < oldestTime and id ~= purchaseId then
				oldestId, oldestTime = id, t
			end
		end
		if oldestId == nil then
			break
		end
		purchases[oldestId] = nil
		count -= 1
	end
	return true
end

-- Undo a record (used when applying the grant itself failed, so a retry can grant it properly).
function Receipts.Revert(purchases: { [string]: number }, purchaseId: string)
	purchases[purchaseId] = nil
end

-- Shards a developer product grants: Amount per unlocked stratum.
function Receipts.ShardAmount(def: { Amount: number }, strataUnlocked: number): number
	return def.Amount * math.max(1, math.floor(strataUnlocked))
end

-- Reverse lookup { [productId] = key } for configured (non-nil) ids only.
function Receipts.ProductIndex(products: { [string]: { Id: number? } }): { [number]: string }
	local index = {}
	for key, def in products do
		if def.Id ~= nil then
			index[def.Id] = key
		end
	end
	return index
end

return Receipts
