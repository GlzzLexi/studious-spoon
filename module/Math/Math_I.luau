--!strict
--------------------------------------------------------------------------------
--	MathI (Math 1)
--	==============
--	A single-function foundational mathematics solver for Roblox with chainable
--	configuration, batch evaluation, and fault-tolerant result objects.
--
--	Covers the 3 most essential non-calculus math pillars in game development:
--	1. Pythagoras (Spatial geometry, missing triangle sides & vector distances)
--	2. Logarithm  (RPG level scaling, prestige curves, rating & decibel math)
--	3. Quadratic  (Projectile ballistics, AI target-leading & polynomial roots)
--
--	The module exports ONE callable. Everything else is reached by chaining
--	methods off the object it returns.
--
--
--	TABLE OF CONTENTS
--	-----------------
--	1.  Installation
--	2.  Quick start
--	3.  API reference
--	4.  Result object
--	5.  The 3 core math pillars (Formulas & behavior)
--	6.  Batch mode
--	7.  Why use this? (Justification)
--	8.  Game use-case examples
--	9.  Error handling
--	10. Limitations and notes
--
--
--	1. INSTALLATION
--	---------------
--	Place this ModuleScript in ReplicatedStorage (or ServerStorage) and
--	require it from any Script or LocalScript.
--
--		local MathI = require(game.ReplicatedStorage.MathI)
--
--
--	2. QUICK START
--	--------------
--		-- 1. PYTHAGORAS: Find hypotenuse from legs (3, 4) -> 5
--		local hyp = MathI({ 3, 4 }):Pythagoras()
--		if hyp.ok then
--			print("Hypotenuse:", hyp.value) --> 5
--		end
--
--		-- Find missing leg when given one leg (3) and hypotenuse (5) -> 4
--		local leg = MathI({ 3, 5 }):Pythagoras("leg")
--		print("Missing Leg:", leg.value) --> 4
--
--		-- Distance between two Vector3 or Vector2 positions
--		local dist = MathI({ Vector3.new(0, 0, 0), Vector3.new(3, 4, 12) }):Pythagoras()
--		print("3D Distance:", dist.value) --> 13
--
--		-- 2. LOGARITHM: Find player level from XP using base-2 exponential scaling
--		local level = MathI(1024):Precision(2):Logarithm(2)
--		print("Level:", level.value) --> 10
--
--		-- Inverse Logarithm (b^x): Find XP required for Level 10 (2^10)
--		local xpReq = MathI(10):Inverse():Logarithm(2)
--		print("XP Required:", xpReq.value) --> 1024
--
--		-- 3. QUADRATIC: Solve x^2 - 5x + 6 = 0 -> roots { 2, 3 }
--		local roots = MathI({ 1, -5, 6 }):Quadratic()
--		print("Roots:", roots.value[1], roots.value[2]) --> 2, 3
--
--		-- Projectile time-of-flight (only return positive time t >= 0)
--		local flightTime = MathI({ -4.9, 19.6, 24.5 }):PositiveOnly():Quadratic()
--		print("Impact Time (s):", flightTime.value[1]) --> 5
--
--		-- BATCH: Solve multiple datasets in one call
--		local batch = MathI({
--			TriangleA = { 6, 8 },
--			TriangleB = { 5, 12 },
--		}):Pythagoras()
--		print(batch.value.TriangleA, batch.value.TriangleB) --> 10, 13
--
--
--	3. API REFERENCE
--	----------------
--
--	MathI(target) -> Solver
--		Creates a solver builder. This is the only function the module exports.
--
--		target  number | {number} | {Vector3} | {Vector2} | {[string]: any}
--		        A single number (for Logarithm), an array of numbers/vectors
--		        (for Pythagoras or Quadratic), or a named dictionary of targets
--		        for batch processing.
--
--		Defaults: base = 10, precision = nil (unrounded), inverse = false,
--		          positiveOnly = false.
--
--	Solver:Precision(decimals) -> Solver
--		Rounds all numeric results to `decimals` decimal places (e.g.,
--		Precision(2) rounds 5.126 to 5.13, Precision(0) rounds to integer).
--
--	Solver:Inverse(enabled?) -> Solver
--		Toggles inverse mode (defaults to true when called).
--		- In `Logarithm(base)`: switches from `log_base(x)` to `base ^ x`.
--		- In `Pythagoras()`: switches default mode from `"hypotenuse"` to `"leg"`.
--
--	Solver:PositiveOnly(enabled?) -> Solver
--		Used with `Quadratic()`. Filters out negative roots (`r < 0`), which is
--		ideal when solving for forward time `t` or positive distances.
--
--	Solver:Pythagoras(mode?) -> Result
--		Solves Euclidean distance or right-triangle geometry:
--		- mode = "hypotenuse" (default):
--		  * Given `{a, b}` or `{x, y, z, ...}`: returns `sqrt(a^2 + b^2 + ...)`.
--		  * Given `{VectorA, VectorB}`: returns Euclidean distance `(A - B).Magnitude`.
--		- mode = "leg" (or when `:Inverse()` is chained):
--		  * Given `{leg, hypotenuse}` (in any order, automatically detects the
--		    larger value as hypotenuse `c` and smaller as leg `b`): returns
--		    `sqrt(c^2 - b^2)`.
--
--	Solver:Logarithm(base?) -> Result
--		Evaluates the logarithm of `target` with base `base` (defaults to 10).
--		- Pass `math.exp(1)` for natural logarithm `ln(x)`.
--		- If `:Inverse()` is active, evaluates the antilogarithm `base ^ target`.
--		- Supports a single number or an array of numbers `{x1, x2, ...}`.
--
--	Solver:Quadratic() -> Result
--		Solves `ax^2 + bx + c = 0` for target `{ a, b, c }`.
--		Returns a sorted array of real roots `{ r1, r2 }` (or `{ r1 }` if one
--		repeated root or filtered by `:PositiveOnly()`). Fails gracefully with
--		`ok = false` if roots are imaginary (discriminant < 0).
--
--	Precision, Inverse, and PositiveOnly return a NEW Solver. The original is
--	never mutated, so you can safely keep a configured solver and reuse it.
--
--
--	4. RESULT OBJECT
--	----------------
--	Every terminal call (Pythagoras / Logarithm / Quadratic) returns:
--
--		{
--			ok     : boolean            true if every target succeeded and is finite
--			value  : any                single: number or {number} (for Quadratic/array)
--			                            batch : { [Name] = number | {number} }
--			error  : string?            single mode: error message on failure
--			failed : {[string]:string}? batch mode: { [Name] = error },
--			                            only present when something failed
--		}
--
--	Nothing in this module throws on invalid inputs (negative log, imaginary
--	roots, impossible triangle legs, or division by zero). Always check `ok`.
--
--
--	5. THE 3 CORE MATH PILLARS (FORMULAS & BEHAVIOR)
--	------------------------------------------------
--	1. Pythagoras:
--	   - Hypotenuse / N-Dimensional Norm:  c = sqrt(x_1^2 + x_2^2 + ... + x_n^2)
--	   - Missing Right-Triangle Leg:       a = sqrt(c^2 - b^2) where c >= b >= 0
--	   - Vector Distance:                  d = ||V_2 - V_1||
--
--	2. Logarithm:
--	   - Change of Base Formula:           log_b(x) = ln(x) / ln(b)
--	   - Inverse (Antilog / Exponential):  f(x) = b ^ x
--	   - Domain Guards: requires x > 0 and base > 0, base ~= 1.
--
--	3. Quadratic:
--	   - Standard Equation:                ax^2 + bx + c = 0
--	   - Discriminant:                     D = b^2 - 4ac
--	   - Numerically Stable Citardauq/Vieta Formula:
--	     Avoids catastrophic cancellation when `b^2 >> 4ac` by computing:
--	         q = -0.5 * (b + sign(b) * sqrt(D))
--	         r1 = q / a,  r2 = c / q
--	   - Automatically falls back to linear solver `-c / b` if `a == 0`.
--
--
--	6. BATCH MODE
--	-------------
--	Passing a string-keyed dictionary as `target` switches to batch mode.
--	Each entry is solved independently. A failure in one entry does not stop
--	the others.
--
--		local res = MathI({
--			ValidLog = 100,
--			BadLog   = -5, -- negative numbers have no real logarithm
--		}):Logarithm(10)
--
--		res.ok             --> false (BadLog failed)
--		res.value.ValidLog --> 2
--		res.failed         --> { BadLog = "Logarithm input must be > 0" }
--
--
--	7. WHY USE THIS? (JUSTIFICATION)
--	--------------------------------
--	Almost every non-trivial gameplay system relies on spatial distance,
--	exponential progression, or 2nd-order motion equations. Doing this raw in
--	Luau causes three recurring bugs:
--
--	1. Silent NaN Corruption in Domain Edge Cases:
--	   `math.sqrt(c^2 - b^2)` when `b > c` (due to floating-point inaccuracy),
--	   `math.log(-1)`, or a negative quadratic discriminant `b^2 - 4ac < 0`
--	   silently produces `nan`. Passing `nan` into a `BodyMover`, `CFrame`, or
--	   `DataStore` corrupts player saves or vaporizes parts in Workspace.
--	   `MathI` validates domains upfront and guarantees finite outputs when
--	   `res.ok == true`.
--
--	2. Missing Built-in Solvers & Boilerplate:
--	   Luau's `math.log(x, base)` doesn't handle array batches, inverse scaling,
--	   or precision rounding, and Luau has no built-in quadratic or leg-finding
--	   solver. Writing `(-b + math.sqrt(b^2 - 4*a*c)) / (2*a)` by hand in
--	   multiple scripts is error-prone and breaks when `a == 0`.
--
--	3. Reversible Economy & Progression Math:
--	   Game economies constantly need to convert back and forth between
--	   `TotalXP -> CurrentLevel` (`Logarithm`) and `CurrentLevel -> TotalXP`
--	   (`:Inverse():Logarithm`). Having both on the same chainable builder
--	   guarantees your UI bars and server level-up checks never desync.
--
--
--	8. GAME USE-CASE EXAMPLES
--	-------------------------
--	A. Projectile Ballistics & AI Target Leading (Quadratic):
--	   When a turret or NPC throws a projectile with initial vertical speed `v0`
--	   from height `h0` under gravity `g`, its height over time is:
--	       y(t) = -0.5*g*t^2 + v0*t + h0
--	   Use `Quadratic()` with `:PositiveOnly()` to find the exact second it
--	   hits the ground (`y = 0`):
--
--		local g, v0, h0 = 196.2, 80, 15
--		local hit = MathI({ -0.5 * g, v0, h0 }):PositiveOnly():Precision(3):Quadratic()
--		if hit.ok then
--			print("Lands in:", hit.value[1], "seconds")
--		end
--
--	B. RPG Leveling, Prestige & Number Formatting (Logarithm):
--	   Calculate a player's level from their XP on a 1.5x exponential curve, or
--	   determine the exact suffix tier (`1 = K`, `2 = M`, `3 = B`, `4 = T`) for
--	   simulator cash displays using base-1000 logarithms:
--
--		local cash = 45_000_000 -- 45 Million
--		local suffixIndex = math.floor(MathI(cash):Logarithm(1000).value) --> 2 ("M")
--
--	C. Combat Range Checks, Wall-Climb Triangles & Radar (Pythagoras):
--	   If a player has a 25-stud grappling hook (`c = 25`) and stands 15 studs
--	   away from a wall (`b = 15`), immediately compute the maximum vertical
--	   ledge height (`a`) they can reach:
--
--		local maxHeight = MathI({ 15, 25 }):Pythagoras("leg")
--		print("Max grapple ledge height:", maxHeight.value) --> 20 studs
--
--
--	9. ERROR HANDLING
--	-----------------
--		local res = MathI({ 1, 2, 10 }):Quadratic()
--		if not res.ok then
--			warn(`No real solution: {res.error}`)
--		end
--
--	Common error sources: imaginary roots (`discriminant < 0`), logarithm of
--	`<= 0`, invalid logarithm base (`<= 0` or `== 1`), or passing fewer than 2
--	values to `Pythagoras`.
--
--
--	10. LIMITATIONS AND NOTES
--	-------------------------
--	- Pure Luau; safe to run on both Server and Client (including Parallel Luau).
--	- `Quadratic()` solves for real roots only. If a trajectory never reaches
--	  the target height (`discriminant < 0`), `res.ok` returns `false` so your
--	  AI knows the target is out of range.
--	- In `Pythagoras("leg")`, if the two sides are equal (`c == b`), it safely
--	  returns `0` rather than failing on floating-point `-0`.
--------------------------------------------------------------------------------

export type TargetItem = number | { number } | { Vector3 } | { Vector2 }
export type Target = TargetItem | { [string]: any }

export type Result = {
	ok: boolean,
	value: any,
	error: string?,
	failed: { [string]: string }?,
}

export type Solver = {
	Precision: (self: Solver, decimals: number) -> Solver,
	Inverse: (self: Solver, enabled: boolean?) -> Solver,
	PositiveOnly: (self: Solver, enabled: boolean?) -> Solver,
	Pythagoras: (self: Solver, mode: ("hypotenuse" | "leg")?) -> Result,
	Logarithm: (self: Solver, base: number?) -> Result,
	Quadratic: (self: Solver) -> Result,
}

--------------------------------------------------------------------------------

local EPSILON = 1e-12

local function isFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function isBatchMap(target: Target): boolean
	if type(target) ~= "table" then
		return false
	end
	local k = next(target)
	return type(k) == "string"
end

local function applyRound(val: any, decimals: number?): any
	if decimals == nil then
		return val
	end
	local mult = 10 ^ math.floor(decimals)
	if type(val) == "number" then
		return math.round(val * mult) / mult
	elseif type(val) == "table" then
		local out = table.create(#val)
		for i, v in val do
			out[i] = math.round(v * mult) / mult
		end
		return out
	end
	return val
end

-- 1. PYTHAGORAS SOLVER
local function solvePythagoras(item: any, mode: string): number
	if type(item) ~= "table" or #item < 2 then
		error("Pythagoras requires an array of at least 2 numbers or 2 Vectors", 0)
	end

	local first = item[1]
	local second = item[2]

	-- Vector3 or Vector2 pair distance
	if typeof(first) == "Vector3" and typeof(second) == "Vector3" then
		if #item ~= 2 then
			error("Vector mode expects exactly 2 Vector3 points", 0)
		end
		return (second - first).Magnitude
	elseif typeof(first) == "Vector2" and typeof(second) == "Vector2" then
		if #item ~= 2 then
			error("Vector mode expects exactly 2 Vector2 points", 0)
		end
		return (second - first).Magnitude
	end

	-- Numeric mode validation
	for i, v in item do
		if not isFinite(v) or v < 0 then
			error(`Side at index {i} must be a non-negative finite number`, 0)
		end
	end

	if mode == "leg" then
		if #item ~= 2 then
			error("Pythagoras 'leg' mode requires exactly 2 sides: {leg, hypotenuse}", 0)
		end
		local s1: number = item[1]
		local s2: number = item[2]
		local c = math.max(s1, s2)
		local b = math.min(s1, s2)
		local diff = (c * c) - (b * b)
		if diff < 0 and math.abs(diff) < EPSILON then
			diff = 0
		end
		return math.sqrt(diff)
	elseif mode == "hypotenuse" then
		local sumSq = 0
		for _, v in item do
			sumSq += (v :: number) * (v :: number)
		end
		return math.sqrt(sumSq)
	else
		error(`Unknown Pythagoras mode '{mode}' (expected 'hypotenuse' or 'leg')`, 0)
	end
end

-- 2. LOGARITHM SOLVER
local function solveLogarithm(item: any, base: number, inverse: boolean): number | { number }
	if not isFinite(base) or base <= 0 or math.abs(base - 1) < EPSILON then
		error("Logarithm base must be a positive finite number not equal to 1", 0)
	end

	local function evalSingle(x: any): number
		if not isFinite(x) then
			error("Logarithm input must be a finite number", 0)
		end
		if inverse then
			local res = base ^ (x :: number)
			if not isFinite(res) then
				error("Inverse logarithm overflowed to Infinity", 0)
			end
			return res
		else
			if (x :: number) <= 0 then
				error("Logarithm input must be greater than 0", 0)
			end
			return math.log(x :: number, base)
		end
	end

	if type(item) == "number" then
		return evalSingle(item)
	elseif type(item) == "table" and #item > 0 then
		local out = table.create(#item)
		for i, v in item do
			out[i] = evalSingle(v)
		end
		return out
	else
		error("Logarithm expects a number or a non-empty array of numbers", 0)
	end
end

-- 3. QUADRATIC SOLVER (ax^2 + bx + c = 0)
local function solveQuadratic(item: any, positiveOnly: boolean): { number }
	if type(item) ~= "table" or #item ~= 3 then
		error("Quadratic requires an array of 3 coefficients: { a, b, c }", 0)
	end

	local a: number = item[1]
	local b: number = item[2]
	local c: number = item[3]

	if not isFinite(a) or not isFinite(b) or not isFinite(c) then
		error("Quadratic coefficients { a, b, c } must be finite numbers", 0)
	end

	local roots: { number } = {}

	-- Degenerate linear case: a == 0 -> bx + c = 0
	if math.abs(a) < EPSILON then
		if math.abs(b) < EPSILON then
			error("Degenerate equation: both 'a' and 'b' are 0", 0)
		end
		roots = { -c / b }
	else
		local disc = (b * b) - (4 * a * c)
		if disc < -EPSILON then
			error(`No real roots (discriminant is negative: {disc})`, 0)
		elseif math.abs(disc) <= EPSILON then
			roots = { -b / (2 * a) }
		else
			local sqrtD = math.sqrt(disc)
			local r1: number
			local r2: number
			if math.abs(b) < EPSILON then
				r1 = -sqrtD / (2 * a)
				r2 = sqrtD / (2 * a)
			else
				local signB = if b >= 0 then 1 else -1
				local q = -0.5 * (b + signB * sqrtD)
				r1 = q / a
				r2 = c / q
			end
			if r1 > r2 then
				r1, r2 = r2, r1
			end
			roots = { r1, r2 }
		end
	end

	if positiveOnly then
		local filtered = {}
		for _, r in roots do
			if r >= -EPSILON then
				table.insert(filtered, if math.abs(r) < EPSILON then 0 else r)
			end
		end
		if #filtered == 0 then
			error("No non-negative real roots found", 0)
		end
		return filtered
	end

	return roots
end

--------------------------------------------------------------------------------

local function build(
	target: Target,
	decimals: number?,
	inverse: boolean,
	positiveOnly: boolean
): Solver
	local batch = isBatchMap(target)

	local function entries(): { [string]: any }
		if batch then
			return target :: { [string]: any }
		end
		return { _single = target }
	end

	local function run(job: (item: any) -> any): Result
		local values: { [string]: any } = {}
		local failed: { [string]: string } = {}

		for name, item in entries() do
			local ok, res = pcall(function()
				local raw = job(item)
				if type(raw) == "number" and not isFinite(raw) then
					error("Result is NaN or Infinite", 0)
				end
				return applyRound(raw, decimals)
			end)

			if ok then
				values[name] = res
			else
				failed[name] = tostring(res)
			end
		end

		if not batch then
			return {
				ok = failed._single == nil,
				value = values._single,
				error = failed._single,
			}
		end

		local hasFailures = next(failed) ~= nil
		return {
			ok = not hasFailures,
			value = values,
			failed = if hasFailures then failed else nil,
		}
	end

	local solver: Solver = {
		Precision = function(_, dec: number)
			return build(target, math.max(0, math.floor(dec)), inverse, positiveOnly)
		end,

		Inverse = function(_, enabled: boolean?)
			local flag = if enabled == nil then true else enabled
			return build(target, decimals, flag, positiveOnly)
		end,

		PositiveOnly = function(_, enabled: boolean?)
			local flag = if enabled == nil then true else enabled
			return build(target, decimals, inverse, flag)
		end,

		Pythagoras = function(_, mode: ("hypotenuse" | "leg")?)
			local resolvedMode = mode or (if inverse then "leg" else "hypotenuse")
			return run(function(item: any)
				return solvePythagoras(item, resolvedMode)
			end)
		end,

		Logarithm = function(_, base: number?)
			local resolvedBase = base or 10
			return run(function(item: any)
				return solveLogarithm(item, resolvedBase, inverse)
			end)
		end,

		Quadratic = function(_)
			return run(function(item: any)
				return solveQuadratic(item, positiveOnly)
			end)
		end,
	}

	return solver
end

return function(target: Target): Solver
	return build(target, nil, false, false)
end
