--!nonstrict
-- Fetches the icon the developer already set on a Developer Product or Gamepass in the Creator Dashboard, so the Shop can
-- show the same real graphic without any separate upload step. MarketplaceService:GetProductInfo is a network call (it can
-- yield and can fail), so every result is cached for the rest of the session and every card falls back to the drawn art
-- until (and unless) its icon arrives. Never guesses or invents an id: only ever asks Roblox about ids already in
-- Config/Products.luau.
local MarketplaceService = game:GetService("MarketplaceService")

local ProductIcons = {}

local cache = {} -- [id] = "rbxassetid://..." (found) | false (asked, nothing usable) | nil (not asked yet)
local inFlight = {} -- [id] = true while a request is out, so two cards for the same id do not double-fetch

-- Returns the cached image now if there is one (nil otherwise). If this id has never been asked about, starts asking in
-- the background and calls onReady(image) later if it succeeds. A card should show its drawn fallback until then.
function ProductIcons.Get(id: any, infoType: Enum.InfoType, onReady: ((string) -> ())?): string?
	if type(id) ~= "number" or id <= 0 then
		return nil
	end
	local cached = cache[id]
	if cached ~= nil then
		return cached or nil
	end
	if not inFlight[id] then
		inFlight[id] = true
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, infoType)
			end)
			local image = nil
			if ok and type(info) == "table" and type(info.IconImageAssetId) == "number" and info.IconImageAssetId > 0 then
				image = "rbxassetid://" .. info.IconImageAssetId
			end
			cache[id] = image or false
			inFlight[id] = nil
			if image and onReady then
				onReady(image)
			end
		end)
	end
	return nil
end

return ProductIcons
