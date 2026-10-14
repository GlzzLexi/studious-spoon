--!strict
--------------------------------------------------------------------------------
--	Calculus
--	========
--	A single-function numerical calculus solver for Roblox with chainable
--	precision configuration, batch function evaluation, and discrete data support.
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
--	5.  Numerical methods and precision
--	6.  Batch mode
--	7.  Discrete data mode
--	8.  Why use this? (Justification)
--	9.  Game use-case examples
--	10. Error handling
--	11. Limitations and notes
--
--
--	1. INSTALLATION
--	---------------
--	Place this ModuleScript in ReplicatedStorage (or ServerStorage) and
--	require it from any Script or LocalScript.
--
--		local Calculus = require(game.ReplicatedStorage.Calculus)
--
--
--	2. QUICK START
--	--------------
--		-- Derivative of f(x) = x^2 at x = 3
--		local res = Calculus(function(x) return x ^ 2 end):Differential(3)
--		if res.ok then
--			print("Slope:", res.value) --> 6
--		else
--			warn("Math error:", res.error)
--		end
--
--		-- Definite integral of f(x) = x^2 from 0 to 3 with 500 sub-intervals
--		local area = Calculus(function(x) return x ^ 2 end):Intervals(500):Integral(0, 3)
--		print("Area:", area.value) --> 9
--
--		-- Custom step size for high-frequency oscillation derivatives
--		local slope = Calculus(math.sin):Step(1e-7):Differential(0)
--		print("cos(0):", slope.value) --> 1
--
--		-- Discrete array data: {y1, y2, y3, ...} with uniform spacing dx = 0.5
--		local data = { 0, 0.25, 1, 2.25, 4 }
--		local discreteArea = Calculus(data, 0.5):Integral()
--		print("Discrete Area:", discreteArea.value)
--
--		-- Batch: evaluate multiple functions at once
--		local batch = Calculus({
--			Position = function(t) return 5 * t ^ 2 end,
--			Velocity = function(t) return 10 * t end,
--		}):Differential(2)
--		print(batch.value.Position, batch.value.Velocity) --> 20, 10
--
--
--	3. API REFERENCE
--	----------------
--
--	Calculus(target, dx?) -> Solver
--		Creates a solver builder. This is the only function the module exports.
--
--		target  MathFn | {number} | {[string]: MathFn | {number}}
--		        A single function f(x), a discrete array of Y-values, or a
--		        named dictionary of functions/arrays (batch mode).
--		dx      number?
--		        Grid spacing when `target` is a discrete array of numbers.
--		        Defaults to 1.
--
--		Defaults: step = 1e-5 (for Differential), intervals = 100 (for Integral).
--
--	Solver:Step(h) -> Solver
--		Sets the infinitesimal step size `h` used by `Differential` for
--		continuous functions. Clamped to a minimum of 1e-12 to prevent
--		floating-point underflow.
--
--	Solver:Intervals(n) -> Solver
--		Sets the number of sub-intervals `n` used by `Integral` for continuous
--		functions. Clamped to a minimum of 2 and rounded to the nearest even
--		integer (required by Simpson's 1/3 rule).
--
--	Solver:Differential(x?) -> Result
--		Computes the derivative at point `x` (or array index `x` in discrete
--		mode). If `target` is a discrete array and `x` is omitted, returns an
--		array containing the derivative at every sample point.
--
--	Solver:Integral(a?, b?) -> Result
--		Computes the definite integral from `a` to `b`.
--		- For continuous functions, `a` and `b` are required domain bounds.
--		- For discrete arrays, `a` and `b` are optional start/end indices
--		  (defaulting to `1` and `#data`).
--
--	Step and Intervals return a NEW Solver. The original is never mutated, so
--	you can safely keep a configured solver and reuse it:
--
--		local highPrecision = Calculus(math.sin):Step(1e-7):Intervals(1000)
--		highPrecision:Differential(math.pi)
--		highPrecision:Integral(0, math.pi)
--
--
--	4. RESULT OBJECT
--	----------------
--	Every terminal call (Differential / Integral) returns the same shape:
--
--		{
--			ok     : boolean            true if every target succeeded and is finite
--			value  : any                single: number (or {number} for full array diff)
--			                            batch : { [Name] = number | {number} }
--			error  : string?            single mode: error message on failure
--			failed : {[string]:string}? batch mode: { [Name] = error },
--			                            only present when something failed
--		}
--
--	Nothing in this module throws on a runtime math failure (NaN, Inf, nil
--	return, or out-of-bounds index). Always check `ok`.
--
--
--	5. NUMERICAL METHODS AND PRECISION
--	----------------------------------
--	Continuous functions:
--	- Differential uses Five-Point Stencil central finite difference:
--	      f'(x) = (-f(x+2h) + 8f(x+h) - 8f(x-h) + f(x-2h)) / (12h)
--	  Error scales at O(h^4), providing near machine-precision accuracy.
--	- Integral uses Composite Simpson's 1/3 Rule across `n` even intervals.
--	  Error scales at O((b-a)^5 / n^4), converging much faster than Riemann sums.
--
--	Discrete arrays:
--	- Differential uses central difference `(y[i+1] - y[i-1]) / (2*dx)` for
--	  interior points, and forward/backward difference at array boundaries.
--	- Integral uses the Composite Trapezoidal Rule across the sample range.
--
--
--	6. BATCH MODE
--	-------------
--	Passing a string-keyed dictionary as `target` switches to batch mode.
--	Each entry is evaluated independently. A failure in one function does not
--	stop the others.
--
--		local res = Calculus({
--			Valid = function(x) return x ^ 3 end,
--			Broken = function(x) return 0 / 0 end, -- returns NaN
--		}):Differential(2)
--
--		res.ok          --> false (Broken produced NaN)
--		res.value.Valid --> 12
--		res.failed      --> { Broken = "Result is NaN or Infinite" }
--
--
--	7. DISCRETE DATA MODE
--	---------------------
--	Instead of a function, you can plug in raw telemetry or physics samples
--	(e.g., recorded velocities every `dt` seconds from RunService.Heartbeat):
--
--		local velocities = { 0, 4.9, 9.8, 14.7, 19.6 }
--		local dt = 0.5
--
--		-- Total distance traveled (integral of velocity)
--		local dist = Calculus(velocities, dt):Integral()
--
--		-- Instantaneous acceleration at sample index 3
--		local accel = Calculus(velocities, dt):Differential(3)
--
--		-- Acceleration across all samples
--		local allAccel = Calculus(velocities, dt):Differential()
--
--
--	8. WHY USE THIS? (JUSTIFICATION)
--	--------------------------------
--	Roblox's built-in `math` library provides basic algebra and trigonometry,
--	but lacks rate-of-change and accumulation solvers. Developers usually
--	fall back to naive frame-by-frame approximations like `(f(x+dt) - f(x)) / dt`
--	or `sum += val * dt`, which suffer from severe issues in production games:
--
--	1. Frame-Rate Dependency & Drift:
--	   Riemann sums (`sum += v * dt`) accumulate massive drift during frame
--	   drops or physics throttling. Simpson's 1/3 Rule and the Five-Point
--	   Stencil are O(h^4) accurate, achieving in 100 steps what a naive loop
--	   cannot match in 10,000, independent of `RunService.Heartbeat` jitter.
--
--	2. Unsolveable / Arbitrary Functions:
--	   Many game formulas have no closed-form antiderivative or are too complex
--	   to differentiate by hand (e.g., procedural noise `math.noise`, custom
--	   Bezier arc-lengths, or player-submitted equations). Numerical solvers
--	   evaluate any black-box function `f(x)` on the fly without hardcoding
--	   derived formulas.
--
--	3. Crash-Proof Math Pipeline:
--	   In Luau, dividing by zero (`1/0` or `0/0`) silently produces `inf` or
--	   `nan` without throwing an error. Feeding `nan` into `CFrame` or
--	   `Part.Position` corrupts the physics state and deletes parts into the
--	   void. This module catches `nan`, `inf`, and runtime errors automatically,
--	   guaranteeing safe numbers when `res.ok == true`.
--
--
--	9. GAME USE-CASE EXAMPLES
--	-------------------------
--	A. Graphing & Educational Math Games:
--	   Let players type or build custom math functions, then render tangent
--	   lines, normal vectors, and shaded area-under-the-curve visuals in real
--	   time without needing a symbolic math parser.
--
--		local userFunc = function(x) return math.sin(x) * x end
--		local slope = Calculus(userFunc):Differential(cursorX).value
--		local area  = Calculus(userFunc):Integral(startX, endX).value
--
--	B. Physics Simulations & Custom Trajectories:
--	   Calculate exact tangent angles to orient projectiles along curved paths
--	   (ziplines, roller coasters, orbital mechanics) or compute exact arc
--	   length `Integral(sqrt(1 + f'(x)^2))` so objects move at constant speed
--	   along curved splines.
--
--		local heightCurve = function(x) return -0.05 * x ^ 2 + 2 * x end
--		local dy_dx = Calculus(heightCurve):Differential(projX).value
--		local pitchAngle = math.atan(dy_dx)
--
--	C. Vehicle Suspension, Drones & PID Controllers:
--	   Hovercrafts, drones, and raycast cars use PID (Proportional-Integral-
--	   Derivative) controllers to stabilize altitude or steering. Feed recent
--	   error samples into Discrete Mode to get clean `I` (Integral) and `D`
--	   (Derivative) terms that resist physics jitter.
--
--		local errorHistory = { 1.2, 0.9, 0.5, 0.2, 0.05 } -- last 5 frames
--		local solver = Calculus(errorHistory, 1 / 60)
--		local I = solver:Integral().value
--		local D = solver:Differential(#errorHistory).value
--
--	D. RPG Economy, XP & Matchmaking Balancing:
--	   When designing non-linear cost or XP curves, integrate the curve from
--	   Level 1 to 100 to instantly know the total grind time or gold sink, or
--	   differentiate to find where progression spikes too sharply.
--
--		local xpCurve = function(lvl) return 100 * (lvl ^ 1.85) end
--		local totalXP = Calculus(xpCurve):Integral(1, 100).value
--
--
--	10. ERROR HANDLING
--	------------------
--		local res = Calculus(myFunc):Integral(0, 10)
--		if not res.ok then
--			warn(`Calculation failed: {res.error}`)
--		end
--
--	Common error sources: function throwing an error, dividing by zero (NaN/Inf),
--	omitting bounds `(a, b)` on a continuous function, or passing fewer than 2
--	points in a discrete data array.
--
--
--	11. LIMITATIONS AND NOTES
--	-------------------------
--	- Pure Luau; safe to run on both Server and Client (including Parallel Luau
--	  Actors).
--	- Extremely small `Step` values (below 1e-9) can introduce floating-point
--	  cancellation noise on flat curves. The default `1e-5` is optimal for
--	  almost all game physics and economy curves.
--	- Functions with vertical asymptotes or discontinuities between `a` and `b`
--	  will produce inaccurate integrals or fail with an Infinite/NaN error.
--------------------------------------------------------------------------------

export type MathFn = (x: number) -> number
export type TargetItem = MathFn | { number }
export type Target = TargetItem | { [string]: TargetItem }

export type Result = {
	ok: boolean,
	value: any,
	error: string?,
	failed: { [string]: string }?,
}

export type Solver = {
	Step: (self: Solver, h: number) -> Solver,
	Intervals: (self: Solver, n: number) -> Solver,
	Differential: (self: Solver, x: number?) -> Result,
	Integral: (self: Solver, a: number?, b: number?) -> Result,
}

--------------------------------------------------------------------------------

local function isFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function isDiscreteArray(item: any): boolean
	return type(item) == "table" and (#item > 0 or next(item) == nil)
end

local function isBatchMap(target: Target): boolean
	if type(target) ~= "table" then
		return false
	end
	local k = next(target)
	return type(k) == "string"
end

-- Five-point stencil derivative for continuous functions: O(h^4) accuracy
local function diffContinuous(fn: MathFn, x: number, h: number): number
	local f1 = fn(x + 2 * h)
	local f2 = fn(x + h)
	local f3 = fn(x - h)
	local f4 = fn(x - 2 * h)
	return (-f1 + 8 * f2 - 8 * f3 + f4) / (12 * h)
end

-- Finite difference for discrete array data
local function diffDiscrete(data: { number }, dx: number, index: number?): number | { number }
	local n = #data
	if n < 2 then
		error("Discrete data requires at least 2 points", 0)
	end

	local function at(i: number): number
		if i < 1 or i > n or i % 1 ~= 0 then
			error(`Index {i} out of bounds [1, {n}]`, 0)
		end
		if i == 1 then
			return (data[2] - data[1]) / dx
		elseif i == n then
			return (data[n] - data[n - 1]) / dx
		else
			return (data[i + 1] - data[i - 1]) / (2 * dx)
		end
	end

	if index ~= nil then
		return at(index)
	end

	local out = table.create(n)
	for i = 1, n do
		local val = at(i)
		if not isFinite(val) then
			error("Result contains NaN or Infinite values", 0)
		end
		out[i] = val
	end
	return out
end

-- Composite Simpson's 1/3 Rule for continuous functions: O(h^4) accuracy
local function integrateContinuous(fn: MathFn, a: number, b: number, intervals: number): number
	if a == b then
		return 0
	end
	local sign = 1
	if a > b then
		a, b = b, a
		sign = -1
	end

	local n = math.max(2, math.floor(intervals))
	if n % 2 ~= 0 then
		n += 1
	end

	local h = (b - a) / n
	local sum = fn(a) + fn(b)

	for i = 1, n - 1 do
		local x = a + i * h
		local weight = if i % 2 == 1 then 4 else 2
		sum += weight * fn(x)
	end

	return sign * (h / 3) * sum
end

-- Composite Trapezoidal Rule for discrete array data
local function integrateDiscrete(data: { number }, dx: number, a: number?, b: number?): number
	local n = #data
	if n < 2 then
		error("Discrete data requires at least 2 points", 0)
	end

	local iStart = a or 1
	local iEnd = b or n

	local sign = 1
	if iStart > iEnd then
		iStart, iEnd = iEnd, iStart
		sign = -1
	end

	if iStart < 1 or iEnd > n or iStart % 1 ~= 0 or iEnd % 1 ~= 0 then
		error(`Indices [{iStart}, {iEnd}] out of bounds [1, {n}]`, 0)
	end
	if iStart == iEnd then
		return 0
	end

	local sum = 0.5 * (data[iStart] + data[iEnd])
	for i = iStart + 1, iEnd - 1 do
		sum += data[i]
	end

	return sign * sum * dx
end

--------------------------------------------------------------------------------

local function build(target: Target, dx: number, step: number, intervals: number): Solver
	local batch = isBatchMap(target)

	local function entries(): { [string]: TargetItem }
		if batch then
			return target :: { [string]: TargetItem }
		end
		return { _single = target :: TargetItem }
	end

	local function run(job: (item: TargetItem) -> any): Result
		local values: { [string]: any } = {}
		local failed: { [string]: string } = {}

		for name, item in entries() do
			local ok, res = pcall(function()
				if dx <= 0 or not isFinite(dx) then
					error("Spacing 'dx' must be a positive finite number", 0)
				end
				local val = job(item)
				if type(val) == "number" and not isFinite(val) then
					error("Result is NaN or Infinite", 0)
				end
				return val
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
		Step = function(_, h: number)
			return build(target, dx, math.max(1e-12, math.abs(h)), intervals)
		end,

		Intervals = function(_, n: number)
			local even = math.max(2, math.floor(n))
			if even % 2 ~= 0 then
				even += 1
			end
			return build(target, dx, step, even)
		end,

		Differential = function(_, x: number?)
			return run(function(item: TargetItem)
				if type(item) == "function" then
					if x == nil or not isFinite(x) then
						error("Continuous Differential requires a finite number 'x'", 0)
					end
					return diffContinuous(item, x, step)
				elseif isDiscreteArray(item) then
					return diffDiscrete(item :: { number }, dx, x)
				else
					error("Invalid target: expected function or array of numbers", 0)
				end
			end)
		end,

		Integral = function(_, a: number?, b: number?)
			return run(function(item: TargetItem)
				if type(item) == "function" then
					if a == nil or b == nil or not isFinite(a) or not isFinite(b) then
						error("Continuous Integral requires finite bounds 'a' and 'b'", 0)
					end
					return integrateContinuous(item, a, b, intervals)
				elseif isDiscreteArray(item) then
					return integrateDiscrete(item :: { number }, dx, a, b)
				else
					error("Invalid target: expected function or array of numbers", 0)
				end
			end)
		end,
	}

	return solver
end

return function(target: Target, dx: number?): Solver
	return build(target, dx or 1, 1e-5, 100)
end
