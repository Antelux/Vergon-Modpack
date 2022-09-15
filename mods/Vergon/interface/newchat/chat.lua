-----------------------------------------------------------------------

local Chat    = math.__chat
local Event   = math.__event
local Message = math.__message

--------------------------------------------------------------------

require '/interface/newchat/colors.lua'

--------------------------------------------------------------------

local mousePosition = {0, 0}
local lastMousePosition = {0, 0}
local deltaMousePosition = {0, 0}

local isScrollbarMouseDown = false
local isScrollbarHeld = false
local scrollDirection = 0
local targetOffset

local isChatMouseDown = false
local highlightedMessage
local maxYOffset = 0

local rerenderScrollbar = true
local rerenderChat = true

local autocompleteMatches = { length = 0 }
local closeIn

local lastAvatar = {}

--------------------------------------------------------------------

local function TrimStart(s)

   return s:match '^%s*(.*)'

end

local function Trim(s)

   return s:match '^%s*(.-)%s*$'

end

local function Alpha(x)

	return (x ^ 0.7) * 255

end

local function Alpha2(x)

	return (x ^ 2.5) * 255

end

local function Mix(x, y, f)

	return (x * (1 - f)) + (y * f)

end

local function Clamp(value, min, max)

	return math.min(math.max(value, min), max)

end

local function RoundToZero(number)

	return (number >= 0) and (number // 1) or math.ceil(number)

end

local function StringDistance(str1, str2)

	local Byte = string.byte

	local distance = 0

	for i = 1, math.min(#str1, #str2) do 
		
		if Byte(str1, i) ~= Byte(str2, i) then

			distance = distance + 1

		end

	end
	
	return distance

end

-----------------------------------------------------------------------

local CopiedMessage = {}
local VOLUME_LEVEL = { [0] = 4, 4, 5, 5, 3, 3, 2, 2, 1, 1, 0, 0 }
local ESCAPED_CHARS = {
	['/'] = true,
	['*'] = true,
	['_'] = true,
	['`'] = true,
	['^'] = true,
	['|'] = true,
	['\\'] = true
}

local function UnformatMessage(text)

	local VOLUME_LEVEL = VOLUME_LEVEL
	local Copied = CopiedMessage

	local isItalic = false
	local lastVolume = 2
	local count = 0

	for _, Point in utf8.codes(text) do

		local Code = Point % 0x516
		local Char = utf8.char(Code)

		if ESCAPED_CHARS[Char] then

			count = count + 1
			Copied[count] = '\\'

		end

		if Char ~= ' ' then

			local Italic = ((Point // 0x516) % 2) == 1
			local Volume = VOLUME_LEVEL[Point // 0x516] or 2

			if Volume ~= lastVolume then

				local Delta = Volume - lastVolume

				if Delta == 1 then

					count = count + 1
					Copied[count] = '`'

				elseif Delta == -1 then

					count = count + 1
					Copied[count] = '_'

				else

					if lastVolume ~= 2 then

						count = count + 1
						Copied[count] = '|'

					end

					for i = 1, math.abs(2 - Volume) do

						count = count + 1
						Copied[count] = (Delta < 0) and '_' or '`'

					end

				end

				lastVolume = Volume

			end

			if Italic ~= isItalic then

				count = count + 1
				Copied[count] = '*'
				isItalic = Italic

			end

		end

		count = count + 1
		Copied[count] = Char
		
	end

	return table.concat(Copied, _, 1, count):gsub('%s+', ' ')

end

-----------------------------------------------------------------------

local MAX_MESSAGE_COUNT = 128
	
function Chat.addMessage(message)

	local Messages = Chat.__messages

	Messages.length = math.min(Messages.length + 1, MAX_MESSAGE_COUNT)

	for i = Messages.length, 2, -1 do

		Messages[i] = Messages[i - 1]

	end

	Messages[1] = Chat.message(message)

	local WordsPerMinute = 250 * 0.5 -- Supposed average multiplied by my arbitrary number.
	local SecondsPerWord = 60 / WordsPerMinute
	local StrippedMessage = Messages[1].message:gsub('%^.-;', '')
	local Delay = math.max(utf8.len(StrippedMessage) * SecondsPerWord, 15)

	closeIn = math.max(closeIn or 0, Delay)

	Chat.focus(false)

	if math.__pingable then

		math.__pinged = (math.__pinged < 0) and 0 or math.__pinged

	end

end

function Chat.focus(focus, text)

	focus = (focus == nil) and true or focus

	if Chat.__widget then 

		if focus then

			Chat.__widget.focus('textBox')

		elseif _G.math.setThinkingBubbles then

			_G.math.setThinkingBubbles(false)

		end

		if text then

			Chat.__widget.setText('textBox', text)

		end

		rerenderChat = true
		rerenderScrollbar = true

	else

		Chat.__focusTextBox = focus
		Chat.__inputTextBox = text

		player.interact('ScriptPane', '/interface/newchat/chat.config')

	end

end

function Chat.update()

	if Chat.__widget then 

		rerenderChat = true
		rerenderScrollbar = true

	end

end

--------------------------------------------------------------------

function cursorOverride(screenPosition)

	-- Position is absolute, but we want relative.
	screenPosition[1] = screenPosition[1] - 5
	screenPosition[2] = screenPosition[2] - 5

	--
	lastMousePosition = mousePosition
	mousePosition = screenPosition

	--
	deltaMousePosition[1] = mousePosition[1] - lastMousePosition[1]
	deltaMousePosition[2] = mousePosition[2] - lastMousePosition[2]

	--sb.setLogMap('CURSOR', '%s, %s', screenPosition[1], screenPosition[2])

end

--------------------------------------------------------------------

function init()

	--
	Chat.__widget = widget
	Chat.__pane = pane
	Chat.__ignoreScroll = 0

	--
	local Background = widget.bindCanvas('background_color')
	local Size = Background:size()
	local Width, Height = Size[1], Size[2]

	local Position = {1, 0, Width - 30, 0}
	local Color = {0, 0, 0, 0}

	Background:clear()

	for i = 1, 12 do

		Position[2] = i
		Position[4] = i + 1
		Color[4] = 255 - Alpha(i / Height)

		Background:drawRect(Position, Color)

	end

	Position[1] = 0
	Position[3] = Width

	for i = 14, Height do

		Position[2] = i
		Position[4] = i + 1
		Color[4] = 255 - Alpha(i / Height)

		Background:drawRect(Position, Color)

	end

	--

	if Chat.__focusTextBox then

		widget.focus('textBox')

	end

	if Chat.__inputTextBox then

		widget.setText('textBox', Chat.__inputTextBox)

	end

	Chat.__focusTextBox = true
	Chat.__inputTextBox = nil

	update()

	--[[
	local Drawables = world.entityPortrait(player.id(), 'full')
	for i = 1, #Drawables do

		local Drawable = Drawables[i]

		sb.logInfo(i.. ': %s', Drawable)

	end
	--]]

	if _G.math.setThinkingBubbles then

		_G.math.setThinkingBubbles(false)

	end

end

--------------------------------------------------------------------

function uninit()

	Chat.__widget = nil
	Chat.__pane = nil

	if _G.math.setThinkingBubbles then

		_G.math.setThinkingBubbles(false)

	end

	-- Hacky, but the best we have for now.
	if widget.hasFocus('textBox') then

		Chat.focus(false, widget.getText('textBox'))

	end



end

--------------------------------------------------------------------

function bottomButton()

	targetOffset = 0

end

--------------------------------------------------------------------

local DisabledColor = {64, 64, 64, 64}
local BaseColor     = {128, 128, 128, 64}
local HoverColor    = {192, 192, 192, 64}
local PressColor    = {0, 224, 255, 64}

local UpButtonPosition = {0, 179-8}
local DownButtonPosition = {0, 0}

local BottomNormal = {
	base = '/interface/newchat/bottomBase.png',
	hover = '/interface/newchat/bottomHover.png',
	pressed = '/interface/newchat/bottomPress.png',
	disabled = '/interface/newchat/bottomDisable.png'
}

local BottomNotify = {
	base = '/interface/newchat/notifyBase.png',
	hover = '/interface/newchat/notifyHover.png',
	pressed = '/interface/newchat/notifyPress.png',
	disabled = '/interface/newchat/notifyDisable.png'
}

local function RenderScrollbar(mousePosition)

	local Scrollbar = widget.bindCanvas('scrollbar')
	local Size = Scrollbar:size()
	local Width, Height = Size[1], Size[2]

	local OffsetY = maxYOffset --- 187

	local ChatLogHeight = 187
	local ScrollActive = (maxYOffset > ChatLogHeight)

	local ScrollbarHeight = (ChatLogHeight / OffsetY) * (Height - 16)
	local ScrollbarOffset = (-Chat.__scrollOffset / OffsetY) * (Height - 16)

	if ScrollbarHeight < 10 then

		local Delta = 10 - ScrollbarHeight

		ScrollbarHeight = 10
		ScrollbarOffset = math.max(ScrollbarOffset - Delta, 0)

	end

	Scrollbar:clear()

	do -- Scrollbar Track

		Scrollbar:drawRect({0, 9, Width, Height - 8}, {0, 0, 0, 64})

	end
	
	if ScrollActive then -- Scrollbar

		local IsHovering =
			(mousePosition[1] >= 0) and (mousePosition[1] <= (Width + 0)) and
			(mousePosition[2] >= (8 + ScrollbarOffset + 22)) and (mousePosition[2] <= (8 + ScrollbarOffset + ScrollbarHeight + 22))

		local Color = 
			((IsHovering or isScrollbarHeld) and (
				isScrollbarMouseDown and 
				PressColor or 
				HoverColor
			)) or
			BaseColor

		Scrollbar:drawRect({0, 8 + ScrollbarOffset + 2, 8, 8 + ScrollbarOffset + ScrollbarHeight - 2}, Color)
		Scrollbar:drawRect({1, 8 + ScrollbarOffset + 1, 7, 8 + ScrollbarOffset + ScrollbarHeight - 1}, Color)
		Scrollbar:drawRect({2, 8 + ScrollbarOffset + 0, 6, 8 + ScrollbarOffset + ScrollbarHeight - 0}, Color)

	else

		Scrollbar:drawRect({0, 8 + 1 + 2, 8, Height - 8 - 2}, DisabledColor)
		Scrollbar:drawRect({1, 8 + 1 + 1, 7, Height - 8 - 1}, DisabledColor)
		Scrollbar:drawRect({2, 8 + 1 + 0, 6, Height - 8 - 0}, DisabledColor)

	end

	if ScrollActive and (Chat.__scrollOffset > (-maxYOffset + ChatLogHeight)) then -- Top Button

		local IsHovering =
			(mousePosition[1] >= 0) and (mousePosition[1] <= (Width + 0)) and
			(mousePosition[2] >= (Height - 8 + 22)) and (mousePosition[2] <= (Height + 22))

		local ButtonImage = 
			(IsHovering and (
				isScrollbarMouseDown and 
				'/interface/newchat/upPress.png' or 
				'/interface/newchat/upHover.png'
			)) or
			'/interface/newchat/upBase.png'

		Scrollbar:drawImage(ButtonImage, UpButtonPosition)

	else

		Scrollbar:drawImage('/interface/newchat/upDisable.png', UpButtonPosition)

	end

	if ScrollActive and (Chat.__scrollOffset < 0) then -- Bottom Button
		
		local IsHovering =
			(mousePosition[1] >= 0) and (mousePosition[1] <= (Width + 0)) and
			(mousePosition[2] >= 22) and (mousePosition[2] < (8 + 22))

		local ButtonImage = 
			(IsHovering and (
				isScrollbarMouseDown and 
				'/interface/newchat/downPress.png' or 
				'/interface/newchat/downHover.png'
			)) or
			'/interface/newchat/downBase.png'

		Scrollbar:drawImage(ButtonImage, DownButtonPosition)

	else

		Scrollbar:drawImage('/interface/newchat/downDisable.png', DownButtonPosition)

	end

end

--------------------------------------------------------------------

function scrollbarClickEvent(position, button, isDown)

	isScrollbarMouseDown = isDown
	isScrollbarHeld = isScrollbarMouseDown and isScrollbarHeld
	rerenderScrollbar = true

end

--------------------------------------------------------------------

local function UpdateScrollbar(delta)

	local Scrollbar = widget.bindCanvas('scrollbar')
	local Size = Scrollbar:size()
	local Width, Height = Size[1], Size[2]

	local OffsetY = maxYOffset --- 187
	local ChatLogHeight = 187

	local mouseDeltaY = 0

	if (deltaMousePosition[1] ~= 0) or (deltaMousePosition[2] ~= 0) then

		mouseDeltaY = deltaMousePosition[2]
		rerenderScrollbar = true

	end

	--

	local ScrollbarHeight = (ChatLogHeight / OffsetY) * (Height - 16)
	local ScrollbarOffset = (-Chat.__scrollOffset / OffsetY) * (Height - 16)

	if ScrollbarHeight < 10 then

		local Delta = 10 - ScrollbarHeight

		ScrollbarHeight = 10
		ScrollbarOffset = math.max(ScrollbarOffset - Delta, 0)

	end

	--

	if isScrollbarHeld and (mouseDeltaY ~= 0) then

		local Factor = mouseDeltaY / ((Height - 16) - ScrollbarHeight)
		local Offset = RoundToZero((-maxYOffset + 187) * Factor)

		local NewOffset = Clamp(Chat.__scrollOffset + Offset, -maxYOffset + 187, 0)

		if Chat.__scrollOffset ~= NewOffset then
		
			Chat.__scrollOffset = NewOffset
			rerenderChat = true

		end

	end

	--

	scrollDirection = 0

	if 
		isScrollbarMouseDown and
		(mousePosition[1] >= 0) and (mousePosition[1] <= (Width + 0))
	then

		-- Up Button.
		if (mousePosition[2] >= (Height - 8 + 22)) and (mousePosition[2] <= (Height + 22)) then

			scrollDirection = -1
			targetOffset = false

		-- Down Button.
		elseif (mousePosition[2] >= 22) and (mousePosition[2] < (8 + 22)) then

			scrollDirection = 1
			targetOffset = false

		-- Scrollbar Area.
		elseif (mousePosition[2] >= (8 + 22)) and (mousePosition[2] <= (Height - 8 + 22)) then
			
			local ScrollbarYEnd = 8 + ScrollbarOffset + ScrollbarHeight + 22
			local ScrollbarYStart = 8 + ScrollbarOffset + 22

			-- Moving the scrollbar itself.
			if (mousePosition[2] >= ScrollbarYStart) and (mousePosition[2] <= ScrollbarYEnd) then

				isScrollbarHeld = true

			elseif not isScrollbarHeld then -- Clicking on the scrollbar track.

				local Factor = (mousePosition[2] - (8 + 22)) / (Height - 16)
				targetOffset = (-maxYOffset + 187) * Factor

			end

		end

	end

	--

	if targetOffset then

		targetOffset = Clamp(targetOffset, -maxYOffset + 187, 0)

		local Delta = math.abs(Chat.__scrollOffset - targetOffset)
		local Direction = math.max(math.floor((Delta / 20) + 0.5), 1)

		if Delta <= 1 then

			Chat.__scrollOffset = targetOffset
			rerenderScrollbar = true
			rerenderChat = true
			targetOffset = nil

		elseif targetOffset < Chat.__scrollOffset then

			scrollDirection = -Direction

		elseif targetOffset > Chat.__scrollOffset then

			scrollDirection = Direction

		end

	end

	if scrollDirection ~= 0 then

		local Offset = RoundToZero(scrollDirection * delta * 270)

		Chat.__scrollOffset = Clamp(Chat.__scrollOffset + Offset, -maxYOffset + 187, 0)

		rerenderScrollbar = true
		rerenderChat = true

	end

	Chat.__unread = (Chat.__scrollOffset ~= 0) and Chat.__unread or 0
	Chat.__ignoreScroll = (Chat.__scrollOffset ~= 0) and Chat.__ignoreScroll or 0

	if rerenderScrollbar then

		widget.setVisible('bottomButton', true)
		widget.setButtonEnabled('bottomButton', Chat.__scrollOffset ~= 0)
		widget.setButtonImages('bottomButton', (Chat.__unread > 0) and BottomNotify or BottomNormal)

		closeIn = math.max(closeIn or 0, 15)

		RenderScrollbar(mousePosition)
		rerenderScrollbar = false

	end

end

--------------------------------------------------------------------

local TextColor = {255, 255, 255, 255}
local TextFormat = {
	position = {5, 0},
	horizontalAnchor = "left", -- left, mid, right
	verticalAnchor = "top", -- top, mid, bottom
	wrapWidth = 0 -- wrap width in pixels or nil
}

local function ShadowText(message)

	return '^#000000;' .. message:gsub('%^.-;', '')

end

local function RenderShadow(canvas, message, x, y, fontSize)

	fontSize = fontSize or 8

	TextFormat.position[1] = x - 0.7
	TextFormat.position[2] = y - 0.7
	
	canvas:drawText(ShadowText(message), TextFormat, fontSize, TextColor)

	TextFormat.position[1] = x
	TextFormat.position[2] = y
	
	canvas:drawText(message, TextFormat, fontSize, TextColor)

end

local function RenderVerticalGradient(canvas, x, y, width, height)

	local Position = {x, 0, width, 0}
	local Color = {0, 0, 0, 0}

	for i = y, height do

		Position[2] = i
		Position[4] = i + 1

		Color[4] = 255 - Alpha2((i - y) / (height - y))

		canvas:drawRect(Position, Color)

	end
		
end

local function AdjustTextBrightness(message, percent)

	local R, G, B = 255, 255, 255

	return message:gsub('%^(.-);', function(color)

		local Color = COLOR_CODES[color:upper()]

		if Color then

			R = Color[1]
			G = Color[2]
			B = Color[3]

		elseif color:sub(1, 1) == '#' then

			local Length = #color

			if Length == 4 then

				R = tonumber(color:sub(2, 2), 16) or R
				G = tonumber(color:sub(3, 3), 16) or G
				B = tonumber(color:sub(4, 4), 16) or B

			elseif Length == 7 then

				R = tonumber(color:sub(2, 3), 16) or R
				G = tonumber(color:sub(4, 5), 16) or G
				B = tonumber(color:sub(6, 7), 16) or B

			end

		end

		return
			'^#' ..
			string.format("%02X", math.min(math.floor(R * percent), 255)) ..
			string.format("%02X", math.min(math.floor(G * percent), 255)) ..
			string.format("%02X", math.min(math.floor(B * percent), 255)) ..
			';'

	end)

end

local AvatarCanvases = {
	'avatarCanvas1',
	'avatarCanvas2',
	'avatarCanvas3',
	'avatarCanvas4',
	'avatarCanvas5',
	'avatarCanvas6',
	'avatarCanvas7',
	'avatarCanvas8',
	'avatarCanvas9',
	'avatarCanvas10'
}; local AvatarIndex = 1

local function GetAvatarCanvas(position)

	local Name = AvatarCanvases[AvatarIndex]
	if not Name then return end

	AvatarIndex = AvatarIndex + 1

	widget.setPosition(Name, position)

	local Canvas = widget.bindCanvas(Name)

	Canvas:clear()

	return widget.bindCanvas(Name)

end

local function ResetAvatarCanvases()

	for i = AvatarIndex, #AvatarCanvases do

		widget.bindCanvas(AvatarCanvases[i]):clear()

	end

	AvatarIndex = 1

end

local HCanvas;

local function RenderChatTextBar()

	if HCanvas then return end
	HCanvas = widget.bindCanvas('hideCanvas')

	local Size = HCanvas:size()
	local GRAY = {25, 25, 25}

	HCanvas:clear()
	HCanvas:drawRect({0, 0, Size[1], Size[2]}, {25/2, 25/2, 25/2})

	HCanvas:drawRect({0, 0, Size[1], 1}, GRAY)
	HCanvas:drawRect({0, Size[2] - 1, Size[1], Size[2]}, GRAY)

	HCanvas:drawRect({0, 0, 1, Size[2]}, GRAY)
	HCanvas:drawRect({Size[1] - 30, 0, Size[1], Size[2]}, GRAY)
end

-- NOTE: Y-axis is ascending, so 0 is at bottom.

local MessageHighlightColor = {0, 0, 0, 128}
local CommandColor = {0, 0, 0, 192}
local ButtonPosition = {0, 0}

local function RenderChat(ChatLog, MousePosition)

	RenderChatTextBar()

	local Size = ChatLog:size()
	local Width, Height = Size[1], Size[2]

	TextFormat.wrapWidth = Width - (27 * 2)

	ChatLog:clear()

	local Messages = Chat.__messages
	
	local offsetY = Chat.__scrollOffset + 1
	local renderButtons = false

	-- Chat messages.

	for i = 1, Messages.length do

		local Message = Messages[i]
		local IsDifferentAuthor = (not Messages[i + 1]) or (Messages[i + 1].authorID ~= Message.authorID)
		local IsNextMessageVisible = false

		local StartY = offsetY

		offsetY = offsetY + (Message.lines * 10)

		if Messages[i + 1] then

			local NextMessage = Messages[i + 1]
			local NextMessageStartY = offsetY + (IsDifferentAuthor and (10 + 5) or 0)
			local NextIsDifferentAuthor = (not Messages[i + 2]) or (Messages[i + 2].authorID ~= Message.authorID)
			local NextMessageEndY = NextMessageStartY + (NextMessage.lines * 10) + (NextIsDifferentAuthor and (10 + 5) or 0)

			IsNextMessageVisible = (NextMessageStartY < Height) and (NextMessageEndY > 0)

		end

		if (StartY < Height) and ((offsetY + (IsDifferentAuthor and 15 or 0)) > 0) then -- Is any part of the message visible?

			local HighlightStartY = StartY + 2 + (((not Messages[i - 1]) or (Messages[i - 1].author ~= Message.author)) and -1 or 0)
			local HighlightEndY   = offsetY + 1 + (IsDifferentAuthor and (10 + 2) or 0)

			if -- Highlight message upon hover.
				(MousePosition[1] >= 8) and (MousePosition[1] < (Width + 8)) and 
				(MousePosition[2] >= (HighlightStartY + 13)) and (MousePosition[2] <= (HighlightEndY + 13))
			then
					
				ChatLog:drawRect({0, HighlightStartY, Width, HighlightEndY}, MessageHighlightColor)

				if highlightedMessage ~= Message then

					 widget.playSound('/sfx/interface/actionbar_select.ogg')
					 highlightedMessage = Message

				end

				if isChatMouseDown then

					targetOffset = math.min(-(StartY - Chat.__scrollOffset) + 25, 0)
					isChatMouseDown = false

				end

				-- Render the three action buttons.

				ButtonPosition[2] = HighlightEndY + 4

				ButtonPosition[1] = Width - 22
				widget.setPosition('customButton1', ButtonPosition)

				ButtonPosition[1] = Width - 12
				widget.setPosition('customButton2', ButtonPosition)

				ButtonPosition[1] = Width - 2
				widget.setPosition('customButton3', ButtonPosition)

				renderButtons = true

				-- Copy, Party, Ping
				-- Copy, Edit,  Delete

				widget.setButtonImages('customButton1', {
					base = '/interface/newchat/copyBase.png',
					hover = '/interface/newchat/copyHover.png',
					pressed = '/interface/newchat/copyPress.png',
					disabled = '/interface/newchat/bottomDisable.png'
				})

				if Message.owner then

					widget.setButtonImages('customButton2', {
						base = '/interface/newchat/editBase.png',
						hover = '/interface/newchat/editHover.png',
						pressed = '/interface/newchat/editPress.png',
						disabled = '/interface/newchat/bottomDisable.png'
					})

					widget.setButtonImages('customButton3', {
						base = '/interface/newchat/deleteBase.png',
						hover = '/interface/newchat/deleteHover.png',
						pressed = '/interface/newchat/deletePress.png',
						disabled = '/interface/newchat/bottomDisable.png'
					})

				else

					widget.setButtonImages('customButton2', {
						base = '/interface/newchat/partyBase.png',
						hover = '/interface/newchat/partyHover.png',
						pressed = '/interface/newchat/partyPress.png',
						disabled = '/interface/newchat/bottomDisable.png'
					})

					widget.setButtonImages('customButton3', {
						base = '/interface/newchat/pingBase.png',
						hover = '/interface/newchat/pingHover.png',
						pressed = '/interface/newchat/pingPress.png',
						disabled = '/interface/newchat/bottomDisable.png'
					})

				end

				-- 

				local Timestamp = os.date(false and '^darkgray;%H:%M' or '^darkgray;%I:%M %p', true and Message.realtime or Message.gametime)

				RenderShadow(ChatLog, Timestamp, Width - 29, (HighlightEndY < 20) and (HighlightEndY + 5) or (HighlightEndY - 12), 6)

			end

			do -- Message

				RenderShadow(ChatLog, Message.message, 27, offsetY, 8)

			end

			if IsDifferentAuthor then -- Header

				local StartY2 = offsetY

				local authorPixelWidth
				local isAuthorHighlighted

				offsetY = offsetY + 10

				do -- Author

					TextFormat.position[1] = 27
					TextFormat.position[2] = offsetY

					TextFormat.position[1] = TextFormat.position[1] - 0.7
					TextFormat.position[2] = TextFormat.position[2] - 0.7
					ChatLog:drawText(ShadowText(Message.author), TextFormat, 8, TextColor)

					TextFormat.position[1] = TextFormat.position[1] + 0.7
					TextFormat.position[2] = TextFormat.position[2] + 0.7

					authorPixelWidth = Chat.stringPixelWidth(Message.author)

					if -- Highlight when hovered.
						(MousePosition[1] >= (27 + 8)) and (MousePosition[1] <= (27 + authorPixelWidth + 8)) and 
						(MousePosition[2] >= (StartY2 + 13)) and (MousePosition[2] <= (offsetY + 13)) 
					then
					
						ChatLog:drawText(AdjustTextBrightness(Message.author, 1.4), TextFormat, 8, TextColor)
						isAuthorHighlighted = true
					
					else

						ChatLog:drawText(Message.author, TextFormat, 8, TextColor)

					end

				end

				if authorPixelWidth then  -- Timestamp / Discord Tag

					local Edited = Message.edited and ' ^darkgray;(edited)' or ''

					local Secondary = 
						(isAuthorHighlighted and Message.discord) and
						-- Discord Tag
						('^lightgray;' .. Message.discord) or Edited

					if Message.owner and (Message.messageID < 0) then

						Secondary = Secondary .. '   ^#810400;Sending...'

					end
					
					RenderShadow(ChatLog, Secondary, 27 + authorPixelWidth + 4, offsetY - 1.5, 6)

				end

				offsetY = offsetY + 5

			end

			if IsDifferentAuthor or (not IsNextMessageVisible) then -- Avatar

				local IsPinned = ((StartY + 22) < Height) or (not Messages[i - 1]) or (Messages[i - 1].authorID == Message.authorID)

				TextFormat.position[1] = (4.5 + 4) + 5
				TextFormat.position[2] = (IsPinned and (math.min(offsetY - 13 - 2, Height - 10 - 5)) or StartY + 7) + 12

				local AvatarCanvas = GetAvatarCanvas(TextFormat.position)

				if AvatarCanvas then

					--AvatarCanvas:drawRect({0, 0, 100, 100}, {255, 0, 0})

					local Drawables = Message.avatar

					for i = 1, #Drawables do

						local Drawable = Drawables[i]

						TextFormat.position[1] = Drawable.position[1] + 8.5
						TextFormat.position[2] = Drawable.position[2] + 2.5

						AvatarCanvas:drawImage(Drawable.image, TextFormat.position, 1, TextColor, true)

					end

				end

			end

		elseif IsDifferentAuthor then

			offsetY = offsetY + 10 + 5

		end

		if Chat.__ignoreScroll > 0 then

			local DeltaOffset = offsetY - StartY

			Chat.__scrollOffset = Chat.__scrollOffset - DeltaOffset
			Chat.__ignoreScroll = Chat.__ignoreScroll - 1

			RenderChat(ChatLog, MousePosition)
			return

		end

	end

	ResetAvatarCanvases()

	maxYOffset = offsetY - Chat.__scrollOffset

	widget.setVisible('customButton1', renderButtons)
	widget.setVisible('customButton2', renderButtons)
	widget.setVisible('customButton3', renderButtons)

	highlightedMessage = renderButtons and highlightedMessage

	-- Command stuff.

	local Autocomplete = autocompleteMatches
	local CommandCanvas = widget.bindCanvas('commandCanvas')

	CommandCanvas:clear()
	
	if Autocomplete.length == 1 then

		local SpaceWidth = Chat.stringPixelWidth(' ') * 2

		local Command = Autocomplete[1].command
		local Lines = Chat.stringLineCount(Command.description, Width - (15*2)) * 10 + 10
		local PositionX = Chat.stringPixelWidth(Command.command) + SpaceWidth + 15

		RenderVerticalGradient(CommandCanvas, 0, 0, Width, Lines + 30)
		
		RenderShadow(CommandCanvas, Chat.formatText(Command.command), 15, Lines + 5, 8)
		RenderShadow(CommandCanvas, Chat.formatText('^lightgray;' .. Command.description), 15, Lines - 10 + 5, 8)

		local Rect = {0, 0, 0, 0}
		local Color = {255, 255, 255, 255}

		for i = 1, #Command.parameters do

			local Parameter = Command.parameters[i]
			local StartX = PositionX
			local Text;

			if Parameter.optional then

				Text = Chat.formatText(Parameter.name .. ': ^cyan;' .. Parameter.type .. '?')
				Color[1] = 35; Color[2] = 35; Color[3] = 35

			else

				Text = Chat.formatText(Parameter.name .. ': ^cyan;' .. Parameter.type)
				Color[1] = 70; Color[2] = 70; Color[3] = 70

			end

			PositionX = PositionX + Chat.stringPixelWidth(Text) + SpaceWidth

			Rect[1] = StartX - 1
			Rect[2] = Lines + 5 - 10 + 2
			Rect[3] = PositionX - SpaceWidth
			Rect[4] = Lines + 5 + 1

			CommandCanvas:drawRect(Rect, Color)

			RenderShadow(CommandCanvas, Text, StartX, Lines + 5, 8)

		end

	elseif Autocomplete.length > 1 then

		local text = '^light;'

		local Mod = math.ceil(Autocomplete.length / 3)

		for i = 1, Autocomplete.length do

			local Darken = (((i - 1) % Mod) == 0) and '^dark;' or ''
			local Comma = (i ~= Autocomplete.length) and ', ' or ''

			text = text .. 
				Darken .. 
				Autocomplete[i].command.command .. 
				Comma
		end

		text = Chat.formatText(text)

		local Lines = Chat.stringLineCount(text, Width - (15*2)) * 10

		RenderVerticalGradient(CommandCanvas, 0, 0, Width, Lines + 30)

		RenderShadow(CommandCanvas, text, 15, Lines + 5, 8)

	end

end

--------------------------------------------------------------------

function canvasClickEvent(position, button, isDown)

	if isChatMouseDown ~= isDown then

		isChatMouseDown = isDown
		rerenderChat = true

	end

end

--------------------------------------------------------------------

local function UpdateChat(delta)

	local ChatLog = widget.bindCanvas('chatLog')

	if (deltaMousePosition[1] ~= 0) or (deltaMousePosition[2] ~= 0) then

		rerenderChat = true

	end

	if rerenderChat then

		RenderChat(ChatLog, mousePosition)

		closeIn = math.max(closeIn or 0, 15)
		
		isChatMouseDown = false
		rerenderChat = false

	end

end

--------------------------------------------------------------------

function customButton1()

	local Message = highlightedMessage
	if not Message then return end

	widget.setText('textBox', UnformatMessage(Message.message))
	widget.focus('textBox')

end

--------------------------------------------------------------------

function customButton2()

	local Message = highlightedMessage
	if not Message then return end

	widget.setText('textBox', 
		Message.owner and
		('/edit ' .. Message.messageID .. ' ' .. UnformatMessage(Message.message)) or
		('/party_invite ' .. Message.authorID)
	)

	widget.focus('textBox')

end

--------------------------------------------------------------------

function customButton3()

	local Message = highlightedMessage
	if not Message then return end

	widget.setText('textBox', 
		Message.owner and
		('/delete ' .. Message.messageID) or
		'' --(Message.discord and ('/ping ' .. Message.discord) or 'User lacks discord.')
	)

	widget.focus('textBox')

end

--------------------------------------------------------------------

local MOUSEWHEEL_POSITION = {
	
	PLUS_0 = {5, 202},
	PLUS_1 = {5, 130},
	PLUS_2 = {5,  58},

	MINUS_0 = {5,  18},
	MINUS_1 = {5,  90},
	MINUS_2 = {5, 162}

}

local DUMMY_SCROLLAREA_TEMPLATE = {
	type   = "scrollArea",
	zlevel = 101,
	rect   =  {0, 0, 333, 187},
	children = {
		minus = {
			type = "canvas", 
			rect = {0, -2, 1, -1}
		},
		plus = {
			type = "canvas", 
			rect = {0, 182, 1, 183}
		}
	}
}

local mousewheelReady = false
local lastTime = 0

function update()

	--

	local TimeNow = os.clock()
	local Delta = TimeNow - lastTime

	lastTime = TimeNow

	--

	if not widget.inMember('dummyScrollArea1.dummyScrollArea2.minus', MOUSEWHEEL_POSITION.MINUS_0) then

		local ScrollY = 
			(widget.inMember('dummyScrollArea1.dummyScrollArea2.minus', MOUSEWHEEL_POSITION.MINUS_1) and  1) or
			(widget.inMember('dummyScrollArea1.dummyScrollArea2.minus', MOUSEWHEEL_POSITION.MINUS_2) and  2) or
			(widget.inMember('dummyScrollArea1.dummyScrollArea2.plus',  MOUSEWHEEL_POSITION.PLUS_1)  and -1) or
			(widget.inMember('dummyScrollArea1.dummyScrollArea2.plus',  MOUSEWHEEL_POSITION.PLUS_2)  and -2)

		if ScrollY then

			targetOffset = (targetOffset or Chat.__scrollOffset) + (ScrollY * 60)

		end

		widget.removeAllChildren('dummyScrollArea1')
		widget.addChild('dummyScrollArea1', DUMMY_SCROLLAREA_TEMPLATE, 'dummyScrollArea2')

	end

	--

	if widget.hasFocus('textBox') then

		closeIn = nil

	elseif not closeIn then

		closeIn = 15

	else

		closeIn = closeIn - Delta

		if closeIn <= 0 then

			pane.dismiss()
			return

		end

	end

	UpdateChat(Delta)
	UpdateScrollbar(Delta)

end

--------------------------------------------------------------------

local allowFocusAt = 0
local lastLetterCount = 0

function updateLetterCount()

	-- Pressing enter doesn't work properly without this,
	-- due to the key being binded to this custom chat.
	if os.clock() < allowFocusAt then

		widget.blur('textBox')
		return

	end

	--
	local CurrentMessage = Chat.formatText(TrimStart(widget.getText('textBox')))
	widget.setText('textBox', CurrentMessage)

	-- Update letter count.
	local LetterCount = #CurrentMessage
	local Color;

		 if LetterCount > (800 * 1.00) then Color = '^red;'
	elseif LetterCount > (800 * 0.85) then Color = '^lightgray;'
	elseif LetterCount > (800 * 0.60) then Color = '^gray;'
	else                                   Color = '^darkgray;' end

	widget.setText('letterCount', Color .. ((LetterCount <= 9999) and (800 - LetterCount) or '>:o'))

	if autocompleteMatches.length ~= 0 then

		autocompleteMatches.length = 0
		rerenderChat = true

	end

	-- Thinking bubbles.

	if _G.math.setThinkingBubbles then

		_G.math.setThinkingBubbles((LetterCount > 0) and (CurrentMessage:sub(1, 1) ~= '/'))

	end

	-- Command parsing.
	if CurrentMessage:sub(1, 1) == '/' then

		-- Autocomplete upon pressing space.
		if (CurrentMessage:sub(#CurrentMessage) == ' ') and (LetterCount > lastLetterCount) then

			local Suggestion = widget.getText('textBoxGhost')

			if Suggestion ~= '' then
				
				widget.setText('textBox', Suggestion .. ' ')

			end

		end

		--
		local Args = {}

		for Arg in CurrentMessage:gmatch('([^%s]+)') do

			table.insert(Args, Arg)

		end

		local CommandN = table.remove(Args, 1)

		-- Offer autocomplete suggestions. 
		do

			local Words, wIndex = {}, 1

			for Word in CurrentMessage:gmatch('([^%s]+)') do

				Words[wIndex] = Word
				wIndex = wIndex + 1

			end

			local Commands = Chat.__commands
			local CommandList = Commands['/']
			local command

			while Commands[Words[1]] do

				CommandList = Commands[Words[1]]
				table.remove(Words, 1)

			end

			if CommandList then

				for i = 1, #CommandList do

					local Command = CommandList[i]

					if CommandN == Command.command then

						autocompleteMatches.length = 1
						autocompleteMatches[1] = {
							command = Command,
							distance = 0
						}

						command = nil
						break

					end

					local LengthDelta = #CommandN - #Command.command

					local Distance =
						(LengthDelta < 0) and
						(StringDistance(CommandN, Command.command) == 0) and
						-LengthDelta

					if Distance then

						autocompleteMatches.length = autocompleteMatches.length + 1
						autocompleteMatches[autocompleteMatches.length] = {
							command = Command,
							distance = Distance
						}

						command = command or Command

					end

				end

			end

			if autocompleteMatches.length == 0 then

				local Line = (#CommandN <= 40) and CommandN or (CommandN:sub(1, 40) .. '...')

				autocompleteMatches.length = 1
				autocompleteMatches[1] = {
					command = {
						command = Line,
						description = '^darkcyan;No matching commands.',
						parameters = {},
						callback = nil,
					},
					distance = 0
				}

			end

			if command then

				widget.setText('textBoxGhost', command.command)

			else

				widget.setText('textBoxGhost', '')

			end

		end

	else

		-- Reset AFK status.
		if CurrentMessage ~= '' then

			Event.trigger('awaken')

		end

		--
		widget.setText('textBoxGhost', '')

	end


	table.sort(autocompleteMatches, function(a, b) 

		return a.distance < b.distance

	end)

	lastLetterCount = LetterCount

end

--------------------------------------------------------------------

local function UpdateAvatar(avatar)

	local changed = false

	if #avatar ~= #lastAvatar then

		changed = true

	else

		for i = 1, #avatar do

			local Item1 = lastAvatar[i]
			local Item2 = avatar[i]

			if 
				(Item1.image ~= Item2.image) or
				(Item1.position[1] ~= Item2.position[1]) or
				(Item1.position[2] ~= Item2.position[2])
			then

				changed = true
				break

			end

		end

	end

	if changed then

		world.sendEntityMessage('SERVER', 'UPDATE_AVATAR', avatar)
		lastAvatar = avatar

	end

end

--------------------------------------------------------------------

function sendMessage()

	local Message = Trim(widget.getText('textBox'))
	local Length = #Message

	if Message:find('%S') then

		-- Command.
		if Message:sub(1, 1) == '/' then

			local Autocomplete = autocompleteMatches[1]
			local Args = {}

			for Arg in Message:gmatch('([^%s]+)') do

				table.insert(Args, Arg)

			end

			local Command = table.remove(Args, 1)

			-- TODO: Process args

			-- Client-side command.
			if Autocomplete and (Autocomplete.command.command == Command) and Autocomplete.command.callback then

				local Ok, Error = pcall(Autocomplete.command.callback, Chat, Args)
				if not Ok then

					Chat.clientMessage('^red;Error:^reset; ' .. tostring(Error))

				end

			else -- Server-side command.

				world.sendEntityMessage('SERVER', 'SEND_MESSAGE', Message)

			end

			widget.setText('textBox', '')
			widget.blur('textBox')
			bottomButton()

		elseif Length <= 800 then -- Chat

			local PlayerID = player.id()

			Chat.addMessage({

				avatar = PlayerID,
				author = world.entityName(PlayerID),
				message = Message,
				owner = true

			})

			local MessageObj = Chat.__messages[1]

			UpdateAvatar(MessageObj.avatar)

			world.sendEntityMessage('SERVER', 'SEND_MESSAGE', Message, PlayerID, MessageObj.messageID)

			widget.setText('textBox', '')
			widget.blur('textBox')
			bottomButton()

			rerenderChat = true
			rerenderScrollbar = true

		end

	elseif Length == 0 then
		
		widget.blur('textBox')

	end

	allowFocusAt = os.clock() + 0.15

end

--------------------------------------------------------------------

function blurMessage()

	widget.blur('textBox')

end

--------------------------------------------------------------------