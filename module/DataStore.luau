--!strict
--[=[
	Store
	=====
	A single-function wrapper around Roblox's DataStoreService with chainable
	retry and backoff configuration.

	The module exports ONE callable. Everything else is reached by chaining
	methods off the object it returns.


	TABLE OF CONTENTS
	-----------------
	1. Installation
	2. Quick start
	3. API reference
	4. Result object
	5. Retry and backoff behavior
	6. Batch mode
	7. Caching
	8. Error handling
	9. Limitations and notes


	1. INSTALLATION
	---------------
	Place this ModuleScript in ServerScriptService (or ServerStorage) and
	require it from a server Script. DataStores are server-only.

		local Store = require(game.ServerScriptService.Store)


	2. QUICK START
	--------------
		-- Read
		local res = Store("Coins"):Get("User_1")
		if res.ok then
			print("Coins:", res.value)
		else
			warn("Read failed:", res.error)
		end

		-- Write, retrying up to 5 attempts total
		Store("Coins"):Try(5):Set("User_1", 100)

		-- Safe read-modify-write with custom backoff
		Store("Coins"):Try(4):Wait(0.5):Update("User_1", function(old)
			return (old or 0) + 50
		end)

		-- Batch: same key across several stores
		local all = Store({ "Coins", "Gems" }):Try(3):Get("User_1")
		print(all.value.Coins, all.value.Gems)


	3. API REFERENCE
	----------------

	Store(target, scope?) -> Request
		Creates a request builder. This is the only function the module exports.

		target  string | {string}   One store name, or an array of names (batch).
		scope   string?             Optional DataStore scope. Defaults to "global".

		Defaults: 1 attempt (no retry), 1 second backoff base.

	Request:Try(attempts) -> Request
		Sets the TOTAL number of attempts per store (not "extra" retries).
		Try(1) means one attempt, Try(5) means up to five. Values below 1 are
		clamped to 1.

	Request:Wait(seconds) -> Request
		Sets the backoff base delay in seconds. Only matters when Try(n) with
		n > 1 is used.

	Request:Get(key) -> Result
		Reads the value stored under `key`.

	Request:Set(key, value, userIds?) -> Result
		Writes `value` under `key`. `userIds` is optional and is forwarded to
		DataStore's UserIds argument (useful for GDPR/data-deletion tracking).
		Batch mode: pass a map instead of a single value:
			Store({ "Coins", "Gems" }):Set("User_1", { Coins = 10, Gems = 2 })

	Request:Update(key, transform) -> Result
		Atomic read-modify-write via UpdateAsync. `transform` receives the old
		value and returns the new one. Return nil to cancel the write.
		Batch mode: pass one function (applied to every store) or a map of
		functions keyed by store name.

	Try, Wait return a NEW Request. The original is never mutated, so you can
	safely keep a configured request and reuse it:

		local reliable = Store("Coins"):Try(5):Wait(0.5)
		reliable:Get("User_1")
		reliable:Set("User_1", 10)


	4. RESULT OBJECT
	----------------
	Every terminal call (Get / Set / Update) returns the same shape:

		{
			ok     : boolean            true if every store succeeded
			value  : any                single: the value
			                            batch : { [StoreName] = value }
			error  : string?            single mode: error message on failure
			failed : {[string]:string}? batch mode: { [StoreName] = error },
			                            only present when something failed
		}

	Nothing in this module throws on a DataStore failure. Always check `ok`.


	5. RETRY AND BACKOFF BEHAVIOR
	-----------------------------
	Delay before retry number i (1-based) = Wait * 2^(i - 1)

	Example: Try(4):Wait(0.5)

		attempt 1 -> fails -> wait 0.5s
		attempt 2 -> fails -> wait 1.0s
		attempt 3 -> fails -> wait 2.0s
		attempt 4 -> fails -> give up, return { ok = false, error = "..." }

	Worst-case added delay: 3.5 seconds. The call yields for that duration,
	so call it from a thread that can afford to wait (not a hot loop).
	No delay is applied after the final attempt.


	6. BATCH MODE
	-------------
	Passing an array as `target` switches to batch mode. Each store is
	processed one after another, and each gets its own independent retry
	budget. A failure in one store does not stop the others.

		local res = Store({ "Coins", "Gems", "Pets" }):Try(3):Get("User_1")

		res.ok            --> false if ANY store failed
		res.value.Coins   --> value from stores that succeeded
		res.failed        --> { Pets = "..." } only for stores that failed

	Batch is NOT atomic. If "Coins" saves and "Gems" fails, "Coins" stays
	saved. Use `res.failed` to decide how to recover.


	7. CACHING
	----------
	GlobalDataStore objects are cached per "name" or "name/scope", so repeated
	calls do not re-resolve the store. The cache lives for the server's
	lifetime.


	8. ERROR HANDLING
	-----------------
		local res = Store("Coins"):Try(3):Set("User_1", 100)
		if not res.ok then
			warn(`Save failed after 3 attempts: {res.error}`)
		end

	Common error sources: API access disabled in Studio, throttling, a value
	that cannot be serialized, or exceeding the 4 MB value limit.


	9. LIMITATIONS AND NOTES
	------------------------
	- Server-side only.
	- Studio needs "Enable Studio Access to API Services" turned on in Game
	  Settings > Security for DataStores to work while testing.
	- Update transforms may run more than once (on retries or contention).
	  Keep them free of side effects.
	- Batch operations run sequentially, so a large batch with retries can
	  take a while. Budget for it.
	- This module does not queue or throttle requests. Staying within
	  DataStore request budgets is the caller's responsibility.
]=]

local DataStoreService = game:GetService("DataStoreService")

export type Result = {
	ok: boolean,
	value: any,
	error: string?,
	failed: { [string]: string }?,
}

export type Request = {
	Try: (self: Request, attempts: number) -> Request,
	Wait: (self: Request, seconds: number) -> Request,
	Get: (self: Request, key: string) -> Result,
	Set: (self: Request, key: string, value: any, userIds: { number }?) -> Result,
	Update: (self: Request, key: string, transform: any) -> Result,
}

--------------------------------------------------------------------------------

local opened: { [string]: GlobalDataStore } = {}

local function open(name: string, scope: string?): GlobalDataStore
	local id = if scope then `{name}/{scope}` else name
	local store = opened[id]
	if not store then
		store = DataStoreService:GetDataStore(name, scope or "global")
		opened[id] = store
	end
	return store
end

local function attempt(job: () -> any, tries: number, delay: number): (boolean, any)
	local ok = false
	local res: any = nil
	for i = 1, tries do
		ok, res = pcall(job)
		if ok then
			return true, res
		end
		if i < tries then
			task.wait(delay * 2 ^ (i - 1))
		end
	end
	return false, tostring(res)
end

local function keysOf(map: { [string]: any }): { string }
	local list = {}
	for name in map do
		table.insert(list, name)
	end
	return list
end

--------------------------------------------------------------------------------

local function build(target: string | { string }, scope: string?, tries: number, delay: number): Request
	local batch = type(target) == "table"

	local function targets(): { string }
		return if type(target) == "table" then target else { target }
	end

	-- Runs `job` once per store, retrying each one independently.
	local function run(names: { string }, job: (store: GlobalDataStore, name: string) -> any): Result
		local values: { [string]: any } = {}
		local failed: { [string]: string } = {}

		for _, name in names do
			local ok, res = attempt(function()
				return job(open(name, scope), name)
			end, tries, delay)

			if ok then
				values[name] = res
			else
				failed[name] = res
			end
		end

		if not batch then
			local only = names[1]
			return { ok = failed[only] == nil, value = values[only], error = failed[only] }
		end

		local hasFailures = next(failed) ~= nil
		return { ok = not hasFailures, value = values, failed = if hasFailures then failed else nil }
	end

	local request: Request = {
		Try = function(_, attempts)
			return build(target, scope, math.max(1, attempts), delay)
		end,

		Wait = function(_, seconds)
			return build(target, scope, tries, seconds)
		end,

		Get = function(_, key)
			return run(targets(), function(store)
				return store:GetAsync(key)
			end)
		end,

		Set = function(_, key, value, userIds)
			local names = if batch then keysOf(value) else targets()
			return run(names, function(store, name)
				return store:SetAsync(key, if batch then value[name] else value, userIds)
			end)
		end,

		Update = function(_, key, transform)
			local perStore = batch and type(transform) == "table"
			local names = if perStore then keysOf(transform) else targets()
			return run(names, function(store, name)
				return store:UpdateAsync(key, if perStore then transform[name] else transform)
			end)
		end,
	}

	return request
end

return function(target: string | { string }, scope: string?): Request
	return build(target, scope, 1, 1)
end
