--------------------------------------------------------------------

local PendingInvite
local PendingTeleport
local LastLocation = ''
local LastX, LastY = 0, 0

--------------------------------------------------------------------

function init()

	script.setUpdateDelta(1)

end

--------------------------------------------------------------------

local function SendPosition()

	local PlayerX = mcontroller.xPosition()
	local PlayerY = mcontroller.yPosition()

	-- Standing on platforms causes slight fluctuations in position.
	if 
		(math.abs(PlayerX - LastX) >= 0.1) or
		(math.abs(PlayerY - LastY) >= 0.1)
	then

		LastX = PlayerX; LastY = PlayerY;
		world.sendEntityMessage('SERVER', 'POSITION_UPDATE', PlayerX, PlayerY)

		math.__lastMoved = os.clock()

	end

end

--------------------------------------------------------------------

local function SendLocation()

	local PlayerLocation = player.worldId()

	if PlayerLocation ~= LastLocation then

		LastLocation = PlayerLocation
		world.sendEntityMessage('SERVER', 'LOCATION_UPDATE', PlayerLocation)

	end

end

--------------------------------------------------------------------

local function SendPing()

	world.sendEntityMessage('SERVER', 'PING')

end

--------------------------------------------------------------------

function update()

	local Event = math.__event
	if not Event then return end

	math.__lastMoved = os.clock()
	math.__isAFK = math.__isAFK or false
	math.__lastPing = os.clock()

	-- No need to update this script.
	script.setUpdateDelta(0)

	-- /afk command.
	Event.setTimeout(coroutine.create(function()

		local Chat

		repeat

			Event.sleep(Event.time.SECOND / 60)
			Chat = math.__chat

		until Chat

		Chat.addCommand(

			'afk',
			'Toggles AFK mode. When AFK, your character is desaturated and their status is temporarily set to \'AFK\'.',

			function(args)

				if not math.__isAFK then

					math.__isAFK = not math.__isAFK
					math.__lastMoved = math.__isAFK and 0 or os.clock()
					math.__afkChange = true

					world.sendEntityMessage('SERVER', 'AFK', math.__isAFK)

				end

			end
		)

	end))

	Event.on('awaken', function()

		math.__lastMoved = os.clock()

		if math.__isAFK then

			world.sendEntityMessage('SERVER', 'AFK', false)
			math.__isAFK = false
			math.__afkChange = true

		end

	end)

	Event.on('movement', function(isMoving)

		if not isMoving then return end

		math.__lastMoved = os.clock()

		if math.__isAFK then

			world.sendEntityMessage('SERVER', 'AFK', false)
			math.__isAFK = false
			math.__afkChange = true

		end

	end)

	-- /pingme command
	math.__pingable = false

	Event.setTimeout(coroutine.create(function()

		local Chat

		repeat

			Event.sleep(Event.time.SECOND / 60)
			Chat = math.__chat

		until Chat

		Chat.addCommand(

			'pingme',
			'Toggles ping mode. When pingable, your character is slightly desaturated, and when a new message is received, a sound will be played every minute until you move or type in game.',

			function(args)

				if not math.__pingable then

					math.__afkChange = true
					math.__pingable = true
					math.__pinged = -1

				end

			end
		)

	end))

	Event.on('awaken', function()

		if math.__pingable then

			math.__afkChange = true
			math.__pingable = false
			math.__pinged = -1

		end

	end)

	Event.on('movement', function(isMoving)

		if isMoving and math.__pingable then

			math.__afkChange = true
			math.__pingable = false
			math.__pinged = -1

		end

	end)

	-- Send position / location updates to use with proximity chat.
	Event.setInterval(SendPosition, Event.time.SECOND / 4)
	Event.setInterval(SendLocation, Event.time.SECOND * 2)

	-- Handle going AFK.
	Event.setInterval(function()

		if math.__isAFK then return end

		local TimeNow = os.clock()
		local TimeToWarp = math.__lastMoved + (30 * 60) -- 30 Minutes
		local TimeToAFK  = math.__lastMoved + (10 * 60) -- 10 Minutes
		
		if TimeNow >= TimeToWarp then

			math.__isAFK = true
			math.__afkChange = true
			
			if player.worldId() ~= player.ownShipWorldId() then

				player.warp('OwnShip')

			end

		elseif TimeNow >= TimeToAFK then

			math.__isAFK = true
			math.__afkChange = true

			world.sendEntityMessage('SERVER', 'AFK', true)

		end

	end, Event.time.MINUTE * 5)

	-- Handle pending party invites.
	Event.setInterval(function()

		if PendingInvite and PendingInvite:finished() then

			local Accepted = PendingInvite:result()

			world.sendEntityMessage('SERVER', 'PARTY_ANSWER', Accepted)

			PendingInvite = nil

		end

		if PendingTeleport and PendingTeleport:finished() then

			local Accepted = PendingTeleport:result()

			world.sendEntityMessage('SERVER', 'TELEPORT_ANSWER', Accepted)

			PendingTeleport = nil

		end

	end, Event.time.SECOND)

	-- Handle server warp requests.
	message.setHandler('PLAYER_WARP', function(_, _, warpLocation)

		player.warp(warpLocation, 'beam')

	end)

	-- Handle incoming party invites.
	message.setHandler('PARTY_INVITE', function(_, _, playerName)

		local DialogConfig = root.assetJson('/interface/confirmation/teleportconfirmation.config').cyberspace

		DialogConfig.paneLayout = '/interface/windowconfig/simpleconfirmation.config:paneLayout'
		DialogConfig.icon = '/interface/confirmation/confirmationicon.png'

		DialogConfig.title = '^blue;Party Invitation'
		DialogConfig.subtitle = 'Confirmation Dialog'

		DialogConfig.message = '\n' .. playerName .. ' has invited you to their party!\n\nDo you want to join it?\n\n^gray;This invitation will expire in one minute.'

		DialogConfig.okCaption = '^green;Accept'
		DialogConfig.cancelCaption = '^red;Deny'

		PendingInvite = player.confirm(DialogConfig)

	end)

	-- Handle incoming teleport requests.
	message.setHandler('TELEPORT_REQUEST', function(_, _, playerName)

		local DialogConfig = root.assetJson('/interface/confirmation/teleportconfirmation.config').cyberspace

		DialogConfig.paneLayout = '/interface/windowconfig/simpleconfirmation.config:paneLayout'
		DialogConfig.icon = '/interface/confirmation/confirmationicon.png'

		DialogConfig.title = '^blue;Teleport Request'
		DialogConfig.subtitle = 'Confirmation Dialog'

		DialogConfig.message = '\n' .. playerName .. ' would like to teleport to you!\n\nDo you accept?\n\n^gray;This request will expire in one minute.'

		DialogConfig.okCaption = '^green;Accept'
		DialogConfig.cancelCaption = '^red;Deny'

		PendingTeleport = player.confirm(DialogConfig)

	end)

	--
	local PING_INTERVAL = Event.time.SECOND / 4

	message.setHandler('PONG', function()

		local TimeNow = os.clock()
		local LastPing = math.__lastPing
		local Delta = TimeNow - LastPing - PING_INTERVAL

		math.__lastPing = TimeNow

		Event.setTimeout(SendPing, PING_INTERVAL)
		Event.trigger('ping', Delta)

		sb.setLogMap('Ping', '%s ms', Delta * 1000)

	end)

	-- Doesn't work unless it's delayed.
	Event.setTimeout(function()

		world.sendEntityMessage('SERVER', 'SHIP_LOCATION', player.ownShipWorldId())
		world.sendEntityMessage('SERVER', 'AFK', false)

		SendPosition()
		SendLocation()
		SendPing()

	end, Event.time.SECOND / 2)

end

--------------------------------------------------------------------