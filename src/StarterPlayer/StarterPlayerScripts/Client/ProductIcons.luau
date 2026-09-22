--!nonstrict
-- Fetches the icon the developer already set on a Developer Product or Gamepass in the Creator Dashboard, so the Shop can
-- show the same real graphic without any separate upload step. MarketplaceService:GetProductInfo is a network call (it can
-- yield and can fail), so every SUCCESS is cached for the rest of the session; a failure is NOT cached, so a card can try
-- again later (a transient hiccup, or an icon that was only just uploaded and has not finished propagating through
-- Roblox's systems yet, should not be stuck showing the drawn fallback for the whole session). Never guesses or invents
-- an id: only ever asks Roblox about ids already in Config/Products.luau.
local MarketplaceService = game:GetService("MarketplaceService")

local ProductIcons = {}

local cache = {} -- [id] = "rbxassetid://..." once found; ids with no result yet are simply absent
local inFlight = {} -- [id] = true while a request is out, so two cards for the same id do not double-fetch
local failedAt = {} -- [id] = os.clock() of the last failed attempt, so retries are spaced out, not instant
local RETRY_AFTER = 8 -- seconds before a failed id can be asked about again
local queue = {} -- ids waiting their turn: many cards ask at once when the Shop first opens; asking one at a time
local draining = false -- (a few ms apart) is friendlier to the API than firing them all in the same instant

local function warnOnce(id, message)
	warn(("[Shop] icon for product/pass %d: %s"):format(id, message))
end

local function drain()
	if draining then
		return
	end
	draining = true
	task.spawn(function()
		while #queue > 0 do
			local job = table.remove(queue, 1)
			local id, infoType, onReady = job.Id, job.InfoType, job.OnReady
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, infoType)
			end)
			inFlight[id] = nil
			if ok and type(info) == "table" and type(info.IconImageAssetId) == "number" and info.IconImageAssetId > 0 then
				local image = "rbxassetid://" .. info.IconImageAssetId
				cache[id] = image
				if onReady then
					onReady(image)
				end
			elseif ok then
				failedAt[id] = os.clock()
				warnOnce(id, "no icon set on this item yet (or it has not finished processing on Roblox's side)")
			else
				failedAt[id] = os.clock()
				warnOnce(id, "GetProductInfo failed: " .. tostring(info))
			end
			task.wait(0.15) -- a small gap between requests, friendlier than firing them all in the same frame
		end
		draining = false
	end)
end

-- Returns the cached image now if there is one (nil otherwise). If this id has never been asked about (or its last
-- attempt failed a while ago), queues a fetch and calls onReady(image) later if it succeeds. A card should show its
-- drawn fallback until then.
function ProductIcons.Get(id: any, infoType: Enum.InfoType, onReady: ((string) -> ())?): string?
	if type(id) ~= "number" or id <= 0 then
		return nil
	end
	if cache[id] then
		return cache[id]
	end
	if inFlight[id] then
		return nil
	end
	if failedAt[id] and os.clock() - failedAt[id] < RETRY_AFTER then
		return nil
	end
	inFlight[id] = true
	table.insert(queue, { Id = id, InfoType = infoType, OnReady = onReady })
	drain()
	return nil
end

return ProductIcons
