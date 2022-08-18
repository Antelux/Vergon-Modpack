-----------------------------------------------------------------------

-- init() -> displayed() -> dismissed() -> uninit()

-----------------------------------------------------------------------

local Event = math.__event
local Message = math.__message

-----------------------------------------------------------------------

local Clock
local Canvas;
local Width, Height;
local Icons = { length = 0 }

-----------------------------------------------------------------------

local rerender = true
local lastTime = 0
local nextRender = 0
local blinkColon = true
local transition = 0
local alpha = 1
local alphaDelay = 0.5
local isMoving = false
local lastPing = 0
local serverTime = 0
local serverTimeOffset = 0

-----------------------------------------------------------------------

local function Clamp(value, min, max)

	return math.min(math.max(value, min), max)

end

-----------------------------------------------------------------------

local function FormatLabel(label)

	return label
		:gsub('%^essential;', '^#ffb133;')
		:gsub('%^admin;', '^#bf7fff;')

end

-----------------------------------------------------------------------

local function ConvertLegacyAction(icon)

	if icon.pane then 

		return { 'pane', icon.pane } 

	elseif icon.scriptAction then

		return { '_legacy_module', icon.scriptAction }

	end

	return { 'null' }

end

-----------------------------------------------------------------------

local Actions = {}

function Actions.pane(config)

	config = (type(config) == 'table') and config or { config = config }

	player.interact(config.type or 'ScriptPane', config.config, player.id())

end

function Actions.exec(script, ...)

	if type(script) ~= "string" then

		error('Parameter \'script\' must be a string, got ' .. tostring(script) .. ' (' .. type(script) .. ') instead.', 2)

	end

	params = {...} -- Pass any given parameters to the script.
	-- Force execute every time.
	if _SBLOADED then _SBLOADED[script] = nil end
	require(script)
	params = nil -- Clean up.

end

function Actions._legacy_module(s)

	local m, e = (function() local it = string.gmatch(s, "[^:]+") return it(), it() end)()
	local mf = string.format("/quickbar/%s.lua", m)
	module = { }
	-- Force execute every time.
	if _SBLOADED then _SBLOADED[script] = nil end
	require(mf)
	module[e]() module = nil -- run function and clean up

end

local function DoAction(type, ...)

	local Action = Actions[type]

	if not Action then

		sb.logError('No such action: "' .. tostring(type) .. '"')
		return false

	end

	local Results = { pcall(Action, ...) }

	if not Results[1] then

		sb.logError('Unable to preform action: ' .. tostring(Results[2]))

	end

	return table.unpack(Results)

end

-----------------------------------------------------------------------

local function IconButton(icon)

	local Size = root.imageSize(icon.icon)

	icon.label  = FormatLabel(icon.label)
	icon.offset = {(18 - Size[1]) / 2, (18 - Size[2]) / 2}
	icon.weight = icon.weight or 0
	icon._sort  = icon.label:lower():gsub('%^.-;', '')

	icon.isHovered = false
	icon.isPressed = false

	icon.framePosition = { 0, 0 }
	icon.iconPosition  = { 0, 0 }

	function icon:setPosition(x, y)

		self.framePosition[1] = x
		self.framePosition[2] = y

		self.iconPosition[1] = x + self.offset[1]
		self.iconPosition[2] = y + self.offset[2]

	end

	function icon:update(mousePosition, mouseButton)

		local IsHovering =
			(mousePosition[1] > self.framePosition[1]) and (mousePosition[1] <= (self.framePosition[1] + 18)) and
			(mousePosition[2] > self.framePosition[2]) and (mousePosition[2] <= (self.framePosition[2] + 18))

		local IsPressing = IsHovering and (mouseButton == 0) -- Left click.

		if IsHovering and not self.isHovered then

			widget.playSound('/sfx/interface/actionbar_select.ogg')

		end

		if IsPressing and not self.isPressed then

			--if i.condition and not condition(table.unpack(i.condition)) then return nil end -- recheck condition on attempt

			widget.playSound(
				DoAction(table.unpack(self.action)) and
				'/sfx/interface/clickon_success.ogg' or
				'/sfx/interface/clickon_error.ogg'
			)
	
			--if i.dismissQuickbar then pane.dismiss() end

		end
		
		self.isHovered = IsHovering
		self.isPressed = IsPressing

	end

	function icon:render(canvas)

		local ButtonImage =
			(self.isPressed and '/sys/stardust/quickbar/button.idle.png') or
			(self.isHovered and '/sys/stardust/quickbar/button.hover.png') or
			'/sys/stardust/quickbar/button.idle.png'

		canvas:drawImage(ButtonImage .. '?multiply=FFFFFF80', self.framePosition)
		canvas:drawImage(self.icon, self.iconPosition)

	end

	return icon

end

-----------------------------------------------------------------------

function init()

	--

	Clock = math.__clock

	if Clock then

		if Clock.__pane then

			pane.dismiss()
			return

		end

	else

		Clock = {
			
			showRealTime = false,
			useMilitaryTime = false,
			lockTime = false,
			__pane = pane
		
		}; math.__clock = Clock

		Event.on('uninit', function()

			local Pane = Clock.__pane
			if Pane then

				Clock.__pane = nil
				Pane.dismiss()

			end

		end)

		Event.on('movement', function(isMoving)

			Clock.onMovement(isMoving)

		end)

		Event.on('ping', function(ping)

			Clock.onPing(ping)

		end)

	end

	Clock.__pane = pane

	function Clock.onMovement(moving)

		isMoving = moving

	end

	function Clock.onPing(ping)

		lastPing = ping

	end

	--

	world.sendEntityMessage('SERVER', 'GET_TIME')

	Message.setHandler('SET_TIME', function(_, _, time)

		serverTime = time
		serverTimeOffset = os.time()

	end)
	

	Canvas = widget.bindCanvas('clockCanvas')

	local Size = Canvas:size()

	Width, Height = Size[1], Size[2]

	--

	local QuickbarIcons = root.assetJson('/quickbar/icons.json')

	-- Translate legacy entries.

	for Name, Icon in pairs(QuickbarIcons.priority) do

		QuickbarIcons.items[Name] = QuickbarIcons.items[Name] or {

			label  = '^essential;' .. Icon.label,
			icon   = Icon.icon,
			weight = -1100,
			action = ConvertLegacyAction(Icon) 

		}

	end

	for Name, Icon in pairs(QuickbarIcons.admin) do

		QuickbarIcons.items[Name] = QuickbarIcons.items[Name] or {

			label  = '^admin;' .. Icon.label,
			icon   = Icon.icon,
			weight = -1000,
			action = ConvertLegacyAction(Icon) ,
			condition = { 'admin' }

		}

	end

	for Name, Icon in pairs(QuickbarIcons.normal) do

		QuickbarIcons.items[Name] = QuickbarIcons.items[Name] or {

			label  = Icon.label,
			icon   = Icon.icon,
			action = ConvertLegacyAction(Icon) 

		}

	end

  	-- Now process all entries.

	for Name, Icon in pairs(QuickbarIcons.items) do

		table.insert(Icons, IconButton(Icon))

	end

	table.sort(Icons, function(a, b) 

		return (a.weight < b.weight) or (a.weight == b.weight and a._sort < b._sort) 

	end)

	Icons.length = #Icons

	--

	update()

end

-----------------------------------------------------------------------

function uninit()

	if Clock.__pane then

		Clock.__pane = nil
		player.interact('ScriptPane', '/interface/clock/clock.config')

	end

end

-----------------------------------------------------------------------

-- button: left = 0, middle = 1, right = 2

local lastMouseButton;

function canvasClickEvent(mousePosition, mouseButton, isDown)

	local MouseButton = isDown and mouseButton

	if MouseButton ~= lastMouseButton then

		lastMouseButton = MouseButton
		rerender = true

		for i = 1, Icons.length do

			local Icon = Icons[i]
			Icon:update(mousePosition, MouseButton)

		end

	end

	if not isDown then return end

	rerender = true

	if button == 0 then

		Clock.useMilitaryTime = not Clock.useMilitaryTime

	elseif button == 1 then

		Clock.lockTime = not Clock.lockTime

	elseif button == 2 then

		Clock.showRealTime = not Clock.showRealTime
		
	end

end

-----------------------------------------------------------------------

local TextColor = {255, 255, 255, 255}
local TextFormat = {
	position = {0, 0},
	horizontalAnchor = "mid", -- left, mid, right
	verticalAnchor = "top", -- top, mid, bottom
	wrapWidth = nil -- wrap width in pixels or nil
}

local function AlphaText(text, alpha)

	return text:gsub('%^(.-);', function(color)

		return '^' .. color .. alpha .. ';'

	end)

end

local function ShadowText(text)

	return '^#000000;' .. text:gsub('%^.-;', '')

end

local function DrawShadowedText(text, x, y, fontSize, alpha)

	fontSize = fontSize or 8
	alpha = alpha or 'FF'

	local ShadowOffset = fontSize * 0.05

	TextFormat.position[1] = x - ShadowOffset
	TextFormat.position[2] = y - ShadowOffset
	
	Canvas:drawText(AlphaText(ShadowText(text), alpha), TextFormat, fontSize, TextColor)

	TextFormat.position[1] = x
	TextFormat.position[2] = y
	
	Canvas:drawText(AlphaText(text, alpha), TextFormat, fontSize, TextColor)

end

-----------------------------------------------------------------------

local TIMEZONE_OFFSET = 60 * 60 * -7
local WORLD_LENGTH = 60 * 60 * 24

local Rect = {0, 0, 0, 0}
local Color = {0, 0, 0, 32}

-- Dusk/Dawn
local TIME_OF_DAY = {
	[0] = 
	'Midnight',  -- 12:00 AM
	'Night',
	'Night',
	'Night',
	'Night',
	'Night',
	'Dawn',      -- 6:00 AM
	'Morning',
	'Morning',
	'Morning',
	'Morning',
	'Morning',
	'Noon',      -- 12:00 PM
	'Afternoon',
	'Afternoon',
	'Afternoon',
	'Afternoon',
	'Afternoon',
	'Dusk',      -- 6:00 PM
	'Evening',
	'Evening',
	'Evening',
	'Evening',
	'Evening',
}

local DAY_OF_MONTH = {
	'1st',
	'2nd',
	'3rd',
	'4th',
	'5th',
	'6th',
	'7th',
	'8th',
	'9th',
	'10th',
	'11th',
	'12th',
	'13th',
	'14th',
	'15th',
	'16th',
	'17th',
	'18th',
	'19th',
	'20th',
	'21st',
	'22nd',
	'23rd',
	'24th',
	'25th',
	'26th',
	'27th',
	'28th',
	'29th',
	'30th',
	'31st'
}

local function Render()

	Canvas:clear()

	if not os then

		TextFormat.verticalAnchor = 'mid'
		DrawShadowedText('^#FF0000;ERROR:\nINVALID CONFIG', Width/2, Height/2, 18)
		return

	elseif not math.__tech then

		TextFormat.verticalAnchor = 'mid'
		DrawShadowedText('^#FF0000;ERROR:\nINVALID TECH', Width/2, Height/2, 18)
		return

	elseif lastPing >= 3 then -- 3 seconds of timeout..

		TextFormat.verticalAnchor = 'mid'
		DrawShadowedText('^#FF0000;DESYNC:\n' .. lastPing .. 's', Width/2, Height/2, 18)
		return

	end

	TextFormat.verticalAnchor = 'top'

	local Transition = transition ^ 2

	do -- Time & Date

		local WorldTime = serverTime + (os.time() - serverTimeOffset) --Clock.showRealTime and os.time() or (math.floor(world.timeOfDay() * WORLD_LENGTH) + TIMEZONE_OFFSET)
		local Colon = blinkColon and '^#CCCCCC;:' or '^#E6E6E6;:'
		local TimeOfDay = TIME_OF_DAY[tonumber(os.date('%H', WorldTime))] or '???'
		local Time = os.date((Clock.useMilitaryTime and ('^#FFFFFF;%H' .. Colon .. '^#FFFFFF;%M') or ('^#FFFFFF;%I' .. Colon .. '^#FFFFFF;%M %p')), WorldTime)
		local Date = '^#F2F2F2;' .. os.date('%B ', WorldTime) .. (DAY_OF_MONTH[tonumber(os.date('%d', WorldTime))] or '??') .. os.date(', %Y', WorldTime)
		local Day  = '^#E6E6E6;' .. os.date('%A ', WorldTime) .. TimeOfDay
		
		local Alpha = string.format('%02X', ((alpha ^ 2) * 255) // 1)
		local OffsetX = Transition * Width

		DrawShadowedText(Date, Width/2 + OffsetX + 14, 49, 12, Alpha)
		DrawShadowedText(Time, Width/2 + OffsetX + 14, 36, 24, Alpha)
		DrawShadowedText(Day,  Width/2 + OffsetX + 14, 13, 8,  Alpha)

	end

	do -- Buttons

		local Transition = 1 - Transition
		local OffsetY = Transition * Height

		local renderRow;
		local label;

		if Transition == 0 then

			for y = 0, Icons.length // 7 do

				for x = 0, 6 do

					local Index = (y * 7) + x + 1
					local Icon = Icons[Index]

					if not Icon then

						break

					elseif Icon.isHovered then

						label = Icon.label
						renderRow = y
						break

					end

				end

			end

		end

		for y = 0, Icons.length // 7 do

			for x = 0, 6 do

				local Index = (y * 7) + x + 1
				local Icon = Icons[Index]

				if not Icon then break end

				Icon:setPosition(x * 22 + 5, 31 - (y * 22) + OffsetY)
				Icon:render(Canvas)

			end

			if renderRow and (y ~= renderRow) then

				local PositionY = 46 - (y * 22)

				Rect[1] = 0
				Rect[3] = Width

				for i = 1, 27 do

					Rect[2] = PositionY - i + 5.5
					Rect[4] = PositionY - i + 5.5 + 1
					Color[4] = 127.5 - (((math.abs(14 - i) / 14) ^ 1.25) * 255) / 2

					Canvas:drawRect(Rect, Color)

				end

				DrawShadowedText(label, Width/2, PositionY, 16)

			end

		end

	end

end

-----------------------------------------------------------------------

local lastMousePosition = {0, 0}
local lastTransition = 0
local lastAlpha = 1

local function UpdateClock(delta)

	--

	local MousePosition = Canvas:mousePosition()
	local IsHovering = (MousePosition[1] >= 7) and (MousePosition[2] >= 10)

	if 
		(MousePosition[1] ~= lastMousePosition[1]) or 
		(MousePosition[2] ~= lastMousePosition[2]) or
		((transition ~= 0) and (transition ~= 1))
	then

		lastMousePosition = MousePosition
		rerender = true

		for i = 1, Icons.length do

			Icons[i]:update(MousePosition, mouseButton)

		end

	end

	--
	
	local TDelta = IsHovering and delta or -delta

	transition = Clamp(transition + (TDelta * 3), 0, 1)

	if transition ~= lastTransition then

		lastTransition = transition
		rerender = true

	end

	--

	local ADelta = isMoving and -delta or delta

	alphaDelay = Clamp(alphaDelay + ADelta, 0, 0.5)

	if (alphaDelay == 0) or (alphaDelay == 0.5) or ((alpha ~= 0) and (alpha ~= 1)) then

		alpha = Clamp(alpha + (ADelta * 3), 0, 1)

	end

	if alpha ~= lastAlpha then

		lastAlpha = alpha
		rerender = true

	end


	--

	nextRender = nextRender - delta

	if nextRender <= 0 then

		nextRender = 1
		rerender = true
		blinkColon = not blinkColon

	end

	--

	if rerender then 

		rerender = false
		Render() 

	end

end

-----------------------------------------------------------------------

function update()

	local TimeNow = os.clock()
	local Delta = TimeNow - lastTime
	lastTime = TimeNow

	UpdateClock(Delta)

end

-----------------------------------------------------------------------

function quickbarButton()

	player.interact('ScriptPane', '/interface/scripted/mmupgrade/mmupgradegui.config')

end

-----------------------------------------------------------------------