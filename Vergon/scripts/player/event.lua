--------------------------------------------------------------------

local Intervals = { length = 0 }
local Timeouts  = { length = 0 }
local Handles   = {}

--------------------------------------------------------------------

local Event = {

	time = {
		FRAME  = 1/60,
		SECOND = 1,
		MINUTE = 60,
		HOUR   = 60*60
	},

	sleep = function(delay)

		local Clock = os.clock
		local AwakeAt = Clock() + delay

		while Clock() < AwakeAt do

			coroutine.yield()

		end

	end,

	setInterval = function(functionOrThread, delay)

		delay = delay or 0

		Intervals.length = Intervals.length + 1
		Intervals[Intervals.length] = {
			execute = functionOrThread,
			executeAt = os.clock() + delay,
			executeEvery = delay,
		}

	end,

	setTimeout = function(functionOrThread, delay)

		delay = delay or 1/1000

		Timeouts.length = Timeouts.length + 1
		Timeouts[Timeouts.length] = {
			execute = functionOrThread,
			executeAt = os.clock() + delay
		}

	end,

	on = function(eventName, functionOrThread)

		Handles[eventName] = Handles[eventName] or { length = 0 }

		local Handlers = Handles[eventName]

		Handlers.length = Handlers.length + 1
		Handlers[Handlers.length] = functionOrThread

	end,

	trigger = function(eventName, ...)

		local Handlers = Handles[eventName]
		if not Handlers then return end

		for i = 1, Handlers.length do

			Handlers[i](...)

		end

	end
}

-----------------------------------------------------------------------

function init()

	math.__message = message
	math.__player  = player
	math.__event   = Event
	
	-- Update at fastest rate.
	script.setUpdateDelta(1)
	lastTime = os.clock()

	-- Start up the clock.
	player.interact('ScriptPane', '/interface/clock/clock.config')

end

-----------------------------------------------------------------------

function uninit()

	Event.trigger('uninit')

end

-----------------------------------------------------------------------

function update()

	local Clock = os.clock
	local Type = type

	local Resume = coroutine.resume
	local Status = coroutine.status

	local Intervals = Intervals
	local Timeouts = Timeouts

	local TimeNow = Clock()

	local i = 1

	while i <= Intervals.length do

		local Interval = Intervals[i]
		local ExecuteAt = Interval.executeAt

		if TimeNow >= ExecuteAt then

			local Execute = Interval.execute
			local Delta = TimeNow - ExecuteAt

			if Type(Execute) == 'function' then

				Execute(Delta)
				Interval.executeAt = Interval.executeEvery + Clock()

			else -- Thread

				local ok, err = Resume(Execute, Delta)

				if (not ok) or (Status(Execute) == 'dead') then

					if not ok then

						sb.logInfo('Interval Thread Error: ' .. tostring(err))

					end

					for j = i, Intervals.length do

						Intervals[j] = Intervals[j + 1]

					end

				end

			end

		end

		i = i + 1

	end

	i = 1

	while i <= Timeouts.length do

		local Timeout = Timeouts[i]
		local ExecuteAt = Timeout.executeAt

		if TimeNow >= ExecuteAt then

			local Execute = Timeout.execute
			local Delta = TimeNow - ExecuteAt

			local remove = true

			if Type(Execute) == 'function' then

				Execute(Delta)

			else -- Thread

				local ok, err = Resume(Execute, Delta)

				if (not ok) or (Status(Execute) == 'dead') then

					if not ok then

						sb.logInfo('Timeout Thread Error: ' .. tostring(err))

					end

				else

					remove = false

				end

			end

			if remove then

				Timeouts.length = Timeouts.length - 1
				
				for j = i, Timeouts.length do

					Timeouts[j] = Timeouts[j + 1]

				end

			end

		end

		i = i + 1

	end

end

-----------------------------------------------------------------------