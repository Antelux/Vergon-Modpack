--[[
[19:29:15.130] [Info] sb: table
[19:29:15.130] [Info] rawget: function
[19:29:15.130] [Info] jsize: function
[19:29:15.130] [Info] jobject: function
[19:29:15.130] [Info] setmetatable: function
[19:29:15.130] [Info] math: table
[19:29:15.130] [Info] root: table
[19:29:15.130] [Info] error: function
[19:29:15.130] [Info] select: function
[19:29:15.130] [Info] getmetatable: function
[19:29:15.130] [Info] utf8: table
[19:29:15.130] [Info] load: function
[19:29:15.130] [Info] io: table
[19:29:15.130] [Info] type: function
[19:29:15.130] [Info] jresize: function
[19:29:15.130] [Info] package: table
[19:29:15.130] [Info] config: table
[19:29:15.130] [Info] require: function
[19:29:15.130] [Info] debug: table
[19:29:15.130] [Info] rawlen: function
[19:29:15.130] [Info] world: table
[19:29:15.130] [Info] animationConfig: table
[19:29:15.130] [Info] rawequal: function
[19:29:15.130] [Info] next: function
[19:29:15.130] [Info] print: function
[19:29:15.130] [Info] ipairs: function
[19:29:15.130] [Info] collectgarbage: function
[19:29:15.130] [Info] os: table
[19:29:15.130] [Info] update: function
[19:29:15.130] [Info] tostring: function
[19:29:15.130] [Info] _VERSION: string
[19:29:15.130] [Info] assert: function
[19:29:15.130] [Info] rawset: function
[19:29:15.130] [Info] pcall: function
[19:29:15.130] [Info] script: table
[19:29:15.130] [Info] localAnimator: table
[19:29:15.130] [Info] dofile: function
[19:29:15.130] [Info] coroutine: table
[19:29:15.130] [Info] tonumber: function
[19:29:15.130] [Info] pairs: function
[19:29:15.130] [Info] table: table
[19:29:15.130] [Info] activeItemAnimation: table
[19:29:15.130] [Info] xpcall: function
[19:29:15.130] [Info] string: table
[19:29:15.130] [Info] self: table
[19:29:15.130] [Info] jremove: function
[19:29:15.130] [Info] loadfile: function
[19:29:15.130] [Info] jarray: function


RenderLayer
	BackgroundOverlay
	BackgroundTile
	Platform
	Plant
	PlantDrop
	Object
	PreviewObject
	BackParticle
	Vehicle
	Effect
	Projectile
	Monster
	Npc
	Player
	ItemDrop
	Liquid
	MiddleParticle
	ForegroundTile
	ForegroundEntity
	ForegroundOverlay
	FrontParticle
	Overlay
--]]

-----------------------------------------------------------------------

require '/scripts/util/painter.lua'
require '/scripts/util/localfont.lua'
require '/scripts/util/tiledrawable.lua'

require "/scripts/vec2.lua"

-----------------------------------------------------------------------

local ToolInput = painter:getToolInput()
local Areas = painter:getAreas()

-----------------------------------------------------------------------

local function Clamp(value, min, max)

	return math.min(math.max(value, min), max)

end

-----------------------------------------------------------------------

local function Decimals(value, decimals)

	local Exp = 10 ^ decimals
	local Rounded = math.floor(value * Exp) / Exp

	if Rounded == (Rounded // 1) then

		return math.floor(value)

	end

	return Rounded

end

-----------------------------------------------------------------------

local localFont;

function init()

	localFont = NewLocalFont(localAnimator)

end

-----------------------------------------------------------------------

function update()

	localAnimator.clearDrawables()
	localAnimator.clearLightSources()

	local Position = activeItemAnimation.ownerPosition()
	local Aim = activeItemAnimation.ownerAimPosition()

	local Scale = painter:getBrushSize()
	local AimFloored = {
		(Aim[1] // 1) - (Scale // 2) - (0.125 * 3) + (((Scale % 2) == 0) and 1 or 0);
		(Aim[2] // 1) - (Scale // 2) - (0.125 * 3.5);
	}

	local Alpha = (60 + (math.sin(os.clock() * 4)) * 12) // 1
	local AlphaHex = string.format('%02x', Alpha)

	-- Highlight blocks.
	if true then

		localAnimator.addDrawable({
			image = '/interface/stmanipulator/tileglow.png?multiply=FFFFFF' .. AlphaHex .. '?scalenearest=' .. Scale .. '?border=3;FFFFFF' .. AlphaHex .. ';FFFFFF00',
			centered = false,
			mirrored = false,
			rotation = 0,
			position = AimFloored,
			fullbright = true
		}, 'ForegroundTile+1')

	-- Show stamp tool blocks.
	else

		local Height = #ToolInput.tiles
		local Width = #ToolInput.tiles[1]
		local AlphaDirective = string.format('?multiply=FFFFFF%02x', (Alpha * 3.5) // 1)

		local TileStartX = (Aim[1] // 1) - (Width // 2) + (((Width % 2) == 0) and 1 or 0)
		local TileStartY = (Aim[2] // 1) - (Height // 2)

		local TilePosition = {}

		for y = 1, Height do

			for x = 1, Width do

				local Tile = ToolInput.tiles[y][x]

				local PaintIndex = Tile.paint or 0
				local Drawable = tileDrawable.material(Tile.material.name, PaintIndex, x, y)

				TilePosition[1] = TileStartX + x - 1
				TilePosition[2] = TileStartY + y - 1

				localAnimator.addDrawable({
					image = Drawable .. '?multiply=FFFFFF' .. AlphaDirective,
					centered = false,
					mirrored = false,
					rotation = 0,
					position = TilePosition,
					fullbright = true
				}, 'ForegroundTile+1')

			end

		end

	end

	-- Show currently selected layer and brush size.
	local CursorText = ((painter:getLayer() == 'foreground') and 'F' or 'B') .. painter:getBrushSize()

	localFont:setRotation(0)
	localFont:setColor(math.abs(math.sin(os.clock())) * 0xFF, math.abs(math.sin(os.clock() - 2)) * 0xFF, math.abs(math.sin(os.clock() + 2)) * 0xFF)
	localFont:renderText(CursorText, AimFloored[1] + Scale + 1, AimFloored[2], true)

	-- Light up area around cursor.

	for x = -1, 1 do

		for y = -1, 1 do

			AimFloored[1] = Aim[1] + (x * 3)
			AimFloored[2] = Aim[2] + (y * 3)

			localAnimator.addLightSource({
				position = AimFloored;
				color = {255, 255, 255}
			})

		end

	end

	-- Render selected areas.

	localFont:setColor(255, 255, 255)

	for _, Area in ipairs(Areas) do

		local From, To = Area[1], Area[2]

		local Width = math.abs(To[1] - From[1])
		local Height = math.abs(To[2] - From[2])

		local MinX = math.min(From[1], To[1])
		local MinY = math.min(From[2], To[2])
		local MaxY = math.max(From[2], To[2])

		localFont:renderText(Width .. 'b ' .. Decimals(Width / 2, 1) .. 'm ' .. Decimals(Width * 1.64042, 1) .. 'f', MinX, MaxY, true)
		localFont:setRotation(90)
		localFont:renderText(Height .. 'b ' .. Decimals(Height / 2, 1) .. 'm ' .. Decimals(Height * 1.64042, 1) .. 'f', MinX, MinY, true)

		local DeltaX = To[1] - From[1]
		local DeltaY = To[2] - From[2]

		localAnimator.addDrawable({
			poly = {{0, 0}, {0, DeltaY}, {DeltaX, DeltaY}, {DeltaX, 0}},
			width = 0.5,
			color = {255, 255, 255, Alpha},
			position = From,
			fullbright = true
		}, 'ForegroundTile+1')

		localAnimator.addDrawable({
			line = {{0, 0}, {0, DeltaY}},
			width = 0.5,
			color = {255, 0, 0, 255},
			position = From,
			fullbright = true
		}, 'ForegroundTile+1')

		localAnimator.addDrawable({
			line = {{0, DeltaY}, {DeltaX, DeltaY}},
			width = 0.5,
			color = {255, 0, 0, 255},
			position = From,
			fullbright = true
		}, 'ForegroundTile+1')

		localAnimator.addDrawable({
			line = {{DeltaX, DeltaY}, {DeltaX, 0}},
			width = 0.5,
			color = {255, 0, 0, 255},
			position = From,
			fullbright = true
		}, 'ForegroundTile+1')

		localAnimator.addDrawable({
			line = {{DeltaX, 0}, {0, 0}},
			width = 0.5,
			color = {255, 0, 0, 255},
			position = From,
			fullbright = true
		}, 'ForegroundTile+1')

	end
	

	--[[
	
	--]]

	--[[
	local Aim = activeItemAnimation.ownerAimPosition()
	local Position = activeItemAnimation.ownerPosition()

	local Distance = vec2.mag(world.distance(Position, Aim))
	local Radius = 20
	local Alpha = 80 --string.format('%02x', Clamp(Radius * 5, 15, 255) // 1)

	for i = 0, 255 do

		local Angle = (i/255) * math.pi * 2
		local X = math.cos(Angle) * Radius
		local Y = math.sin(Angle) * Radius

		local Drawable = {
			image = '/tiles/materials/alienrock.png?crop;4;196;12;204?hueshift=' .. ((i/255)*360) .. '?multiply=FFFFFF' .. Alpha,
			centered = true,
			mirrored = false,
			rotation = 0,
			position = {Position[1] + X, Position[2] + Y},
			fullbright = true
		}

		localAnimator.addDrawable(Drawable, 'ForegroundTile+1')

	end

	local Drawable = {
		image = '/tiles/materials/alienrock.png?crop;2;194;14;206?scalenearest=10?hueshift=' .. (0),
		centered = true,
		mirrored = false,
		rotation = 0,
		position = {Position[1] + 0, Position[2] + 0},
		fullbright = true
	}

	localAnimator.addDrawable(Drawable, 'ForegroundTile+1')
	--]]

end

-----------------------------------------------------------------------