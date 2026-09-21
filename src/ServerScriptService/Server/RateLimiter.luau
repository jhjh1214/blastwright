--!strict
-- Token-bucket rate limiter, one bucket per (player, remote). Pure: no Roblox APIs, the caller passes the clock.
-- Purpose: an exploiter cannot flood a remote to burn server time. Legitimate play never gets close to the limits.
export type RateLimiter = {
	Allow: (self: RateLimiter, playerKey: any, remote: string, now: number, rate: number, burst: number) -> boolean,
	Forget: (self: RateLimiter, playerKey: any) -> (),
	_players: { [any]: { [string]: { Tokens: number, Last: number } } },
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(): RateLimiter
	return setmetatable({ _players = {} }, RateLimiter) :: any
end

-- rate = tokens per second, burst = bucket size. Returns true if the call may proceed.
function RateLimiter.Allow(self: RateLimiter, playerKey: any, remote: string, now: number, rate: number, burst: number): boolean
	-- Refuse on nonsense settings or a nonsense clock rather than ever granting free calls.
	if not (rate > 0 and burst >= 1 and now == now and rate < math.huge) then
		return false
	end
	local buckets = self._players[playerKey]
	if buckets == nil then
		buckets = {}
		self._players[playerKey] = buckets
	end
	local bucket = buckets[remote]
	if bucket == nil then
		bucket = { Tokens = burst, Last = now }
		buckets[remote] = bucket
	end
	local elapsed = math.max(0, now - bucket.Last) -- a clock that goes backwards refills nothing
	bucket.Tokens = math.min(burst, bucket.Tokens + elapsed * rate)
	bucket.Last = math.max(bucket.Last, now)
	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	return false
end

-- Drop a player's buckets (call when they leave so nothing leaks between sessions).
function RateLimiter.Forget(self: RateLimiter, playerKey: any)
	self._players[playerKey] = nil
end

return RateLimiter
