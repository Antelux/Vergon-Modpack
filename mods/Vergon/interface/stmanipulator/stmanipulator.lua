-----------------------------------------------------------------------

require '/scripts/util/painter.lua'
require '/scripts/util/tiledrawable.lua'

-----------------------------------------------------------------------

local ToolInput = painter:getToolInput()
local Toolbar;

-----------------------------------------------------------------------

local function Capitalize(text)

	return text:sub(1, 1):upper() .. text:sub(2)

end

-----------------------------------------------------------------------

local function ToolbarButton(toolName, iconImage, x, y, isSelected)

	local Button = {

		position = {x, y};
		iconImage = iconImage;
		toolName = toolName;

		isHovered = false;
		isPressed = false;
		isSelected = 
			((painter:getLeftTool() == toolName) and 0) or
			((painter:getRightTool() == toolName) and 2) or
			false;
	}

	function Button:setPosition(x, y)

		self.position[1] = x
		self.position[2] = y

	end

	function Button:update(mousePosition, mouseButton)

		local IsHovering =
			(mousePosition[1] > self.position[1]) and (mousePosition[1] <= (self.position[1] + 18)) and
			(mousePosition[2] > self.position[2]) and (mousePosition[2] <= (self.position[2] + 18))

		local IsPressing = IsHovering and ((mouseButton == 0) or (mouseButton == 2)) -- Left/right click.

		if IsHovering and not self.isHovered then

			widget.playSound('/sfx/interface/actionbar_select.ogg')

		end

		if IsPressing and not self.isPressed then

			widget.playSound('/sfx/interface/clickon_success.ogg')

			for _, Button in ipairs(Toolbar) do

				if Button.isSelected == mouseButton then

					Button.isSelected = self.isSelected
					break

				end

			end

			self.isSelected = mouseButton

		end
		
		self.isHovered = IsHovering
		self.isPressed = IsPressing

	end

	function Button:render(canvas)

		local ButtonImage =
			(self.isPressed and '/interface/stmanipulator/blankhover.png') or
			(self.isHovered and '/interface/stmanipulator/blank.png?brightness=30') or
			'/interface/stmanipulator/blank.png'

		canvas:drawImage(ButtonImage .. '?multiply=FFFFFF80', self.position)

		if self.isSelected then

			local HighlightImage = (self.isSelected == 0) and
				'/interface/stmanipulator/lefthighlight.png' or
				'/interface/stmanipulator/righthighlight.png'

			canvas:drawImage(HighlightImage, self.position)

		end

		canvas:drawImage(self.iconImage, {self.position[1] + 9, self.position[2] + 9}, 1, nil, true)

	end

	return Button

end

-----------------------------------------------------------------------

local heldMouseButton
local ToolbarTextConfig = {
	position = {0, 0};
	horizontalAnchor = 'left';
	verticalAnchor = 'top';
}

local function UpdateToolbar(canvas, mousePosition)

	local Size = canvas:size()

	for _, Button in ipairs(Toolbar) do

		Button:update(mousePosition, heldMouseButton)
		Button:render(canvas)

	end

	for _, Button in ipairs(Toolbar) do

		if Button.isSelected == 0 then

			painter:setLeftTool(Button.toolName)

		elseif Button.isSelected == 2 then

			painter:setRightTool(Button.toolName)

		end

	end

	ToolbarTextConfig.position[1] = 1
	ToolbarTextConfig.position[2] = Size[2] - 40
	ToolbarTextConfig.horizontalAnchor = 'left'

	canvas:drawText(Capitalize(painter:getLeftTool()), ToolbarTextConfig, 12, {255, 0, 0})

	ToolbarTextConfig.position[1] = 19*8
	ToolbarTextConfig.horizontalAnchor = 'right'

	canvas:drawText(Capitalize(painter:getRightTool()), ToolbarTextConfig, 12, {0, 0, 255})

end

-----------------------------------------------------------------------

function toolbarClickEvent(position, button, isDown)

	heldMouseButton = isDown and button
	update()

end

-----------------------------------------------------------------------

local function GetFilePath(basePath, fileName)

	if fileName:sub(1, 1) == '/' then

		return fileName

	end

	if basePath:sub(-1) == '/' then

		return basePath .. fileName

	end

	return basePath:match('^(.+%/).-$') .. fileName

end

-----------------------------------------------------------------------

local function GenerateCropDirectives(tileJSON, tileImage, paintIndex)

	local TemplatePath = GetFilePath(tileJSON.path, tileJSON.config.renderTemplate)
	local Template = root.assetJson(TemplatePath)
	local Size = root.imageSize(tileImage)

	local Piece = Template.pieces[Template.representativePiece]

	local TexSX = Piece.texturePosition[1] + (paintIndex * Piece.colorStride[1]) - 3
	local TexSY = Piece.texturePosition[2] + (paintIndex * Piece.colorStride[2]) - 3

	local TexEX = TexSX + Piece.textureSize[1] + 6
	local TexEY = TexSY + Piece.textureSize[2] + 6

	-- "variantStride" : [16, 0]

	return '?crop;' .. TexSX .. ';' .. (Size[2] - TexEY) .. ';' .. TexEX .. ';' .. (Size[2] - TexSY)

end

-----------------------------------------------------------------------

local InputTextConfig = {
	position = {0, 0};
	horizontalAnchor = 'left';
	verticalAnchor = 'top';
}

local PaintIndexName = {
	[0] = '^darkgray;None',
	'^red;Red',
	'^blue;Blue',
	'^green;Green',
	'^yellow;Yellow',
	'^orange;Orange',
	'^magenta;Magenta',
	'^black;Black',
	'^lightgray;White'
}

local BorderColor = {255, 255, 255, 32}

local function UpdateInputSelection(canvas, mousePosition)

	local Size = canvas:size()

	local TileY = Size[2] - 115
	local TextY = Size[2] - 180

	canvas:drawImage('/interface/stmanipulator/blank.png', {19*4, TileY}, 6, nil, true)

	local Height = #ToolInput.tiles
	local Width = #ToolInput.tiles[1]

	local Tiles = math.max(Width, Height)
	local Scale = 10 / Tiles
	local TexS = Scale * 8

	local Coords = {}
	local LineS = {}
	local LineE = {}

	for y = 1, Height do

		for x = 1, Width do

			local Tile = ToolInput.tiles[y][x]

			local PaintIndex = Tile.paint or 0
			local Hueshift = math.floor(Tile.material.hueshift or 0)
			local Drawable, Color = tileDrawable.material(Tile.material.name, PaintIndex, x, y)

			--sb.logInfo(Drawable)

			Coords[1] = ((Size[1]/2) - ((TexS*Tiles)/2)) + ((x - 1) * TexS) + (((Width % 2) == 0) and 0 or (TexS / 2))
			Coords[2] = 145 + ((y - 1) * TexS) + (((Height % 2) == 0) and 0 or (TexS / 2))
			
			canvas:drawImage(Drawable .. '?hueshift=' .. Hueshift, Coords, Scale)

			LineS[1] = Coords[1]
			LineS[2] = Coords[2]

			LineE[1] = LineS[1] + TexS
			LineE[2] = LineS[2]

			canvas:drawLine(LineS, LineE, BorderColor)

			LineS[2] = LineS[2] + TexS
			LineE[2] = LineE[2] + TexS

			canvas:drawLine(LineS, LineE, BorderColor)

			LineS[1] = Coords[1]
			LineS[2] = Coords[2]

			LineE[1] = LineS[1]
			LineE[2] = LineS[2]  + TexS

			canvas:drawLine(LineS, LineE, BorderColor)

			LineS[1] = LineS[1] + TexS
			LineE[1] = LineE[1] + TexS

			canvas:drawLine(LineS, LineE, BorderColor)
		end

	end

	--[[
	do
		local MaterialColor = MaterialConfig and MaterialConfig.config.particleColor or WHITE
		local Color = MaterialConfig and string.format('^#%02X%02X%02X;', MaterialColor[1], MaterialColor[2], MaterialColor[3]) or '^lightgray;'
		local Hueshift = math.floor(ToolInput.material.hueshift or 0)

		InputTextConfig.position[1] = 1
		InputTextConfig.position[2] = TextY

		canvas:drawText('Material: ' .. Color .. Capitalize(ToolInput.material.name or '^darkgray;Empty'), InputTextConfig, 12)

		InputTextConfig.position[1] = 12
		InputTextConfig.position[2] = TextY - (12*1)

		canvas:drawText('Hueshift: ' .. Color .. Hueshift, InputTextConfig, 12)

		if MaterialConfig then

			local MaterialImage = GetFilePath(MaterialConfig.path, MaterialConfig.config.renderParameters.texture)
			local Crop = GenerateCropDirectives(MaterialConfig, MaterialImage, PaintIndex)
			
			canvas:drawImage(MaterialImage .. Crop .. '?hueshift=' .. Hueshift, {19*4, TileY}, 6, nil, true)

		end

	end
	
	do

		local Hueshift = math.floor(ToolInput.matmod.hueshift or 0)

		InputTextConfig.position[1] = 1
		InputTextConfig.position[2] = TextY - (12*2)

		canvas:drawText('Mod: ^lightgray;' .. Capitalize(ToolInput.matmod.name or '^darkgray;Empty'), InputTextConfig, 12)

		InputTextConfig.position[1] = 12
		InputTextConfig.position[2] = TextY - (12*3)

		canvas:drawText('Hueshift: ^lightgray;' .. Hueshift, InputTextConfig, 12)

		if ModConfig then

			local ModImage = GetFilePath(ModConfig.path, ModConfig.config.renderParameters.texture)
			local Crop = GenerateCropDirectives(ModConfig, ModImage, 0)

			canvas:drawImage(ModImage .. Crop .. '?hueshift=' .. Hueshift, {19*4, TileY}, 6, nil, true)

		end

	end

	do
		local LiquidColor = LiquidConfig and LiquidConfig.config.color or WHITE
		local Color = LiquidConfig and string.format('^#%02X%02X%02X%02X;', LiquidColor[1], LiquidColor[2], LiquidColor[3], LiquidColor[4] or 128) or '^lightgray;'

		InputTextConfig.position[1] = 1
		InputTextConfig.position[2] = TextY - (12*4)

		canvas:drawText('Liquid: ' .. Color .. Capitalize(ToolInput.liquid.name or '^darkgray;Empty'), InputTextConfig, 12)

		InputTextConfig.position[1] = 12
		InputTextConfig.position[2] = TextY - (12*5)

		local Amount = math.floor((ToolInput.liquid.amount or 0) * 100)

		canvas:drawText('Amount: ^lightgray;' .. Amount .. '%', InputTextConfig, 12)

		if LiquidConfig then

			local LiquidImage = GetFilePath(LiquidConfig.path, LiquidConfig.config.texture)
			local Pixels = math.max(math.floor((ToolInput.liquid.amount or 0) * 12), 1)

			canvas:drawImage(LiquidImage .. '?crop;4;4;12;' .. Pixels, {19*4, TileY - ((12 - Pixels) * 2)}, 6, LiquidColor, true)

		end

	end

	do
		InputTextConfig.position[1] = 1
		InputTextConfig.position[2] = TextY - (12*6)

		canvas:drawText('Collision: ^lightgray;' .. Capitalize(ToolInput.collision or '^darkgray;Unknown'), InputTextConfig, 12)

	end

	do
		InputTextConfig.position[1] = 1
		InputTextConfig.position[2] = TextY - (12*7)

		canvas:drawText('Paint: ' .. PaintIndexName[PaintIndex], InputTextConfig, 12)

	end
	--]]

end

-----------------------------------------------------------------------

function feedModeRadioGroup(buttonID, groupName)

	painter:setFeedMode(({
		'random',
		'pattern',
		'noise'
	})[buttonID + 1])

end

-----------------------------------------------------------------------

function init()

	local Canvas = widget.bindCanvas('toolbar')
	local Size = Canvas:size()

	local ToolbarY1 = Size[2] - (19 * 1)
	local ToolbarY2 = Size[2] - (19 * 2)

	Toolbar = {
		ToolbarButton('brush', '/interface/stmanipulator/icon_brush.png', 0, ToolbarY1),
		ToolbarButton('dropper', '/interface/stmanipulator/icon_dropper.png', 19, ToolbarY1),
		ToolbarButton('area', '/interface/stmanipulator/icon_area.png', 38, ToolbarY1),
		ToolbarButton('stamp', '/interface/stmanipulator/icon_stamp.png', 57, ToolbarY1),
		ToolbarButton('measure', '/interface/stmanipulator/icon_measure.png', 76, ToolbarY1),
		ToolbarButton('gradient', '/interface/stmanipulator/icon_gradient.png', 95, ToolbarY1)
	}
	

end

-----------------------------------------------------------------------

function update()

	local Canvas = widget.bindCanvas('toolbar')
	local MousePosition = Canvas:mousePosition()

	Canvas:clear()

	--local Size = Canvas:size()
	--Canvas:drawRect({0, 0, 19 * 8, Size[2]}, {48, 48, 48})

	UpdateToolbar(Canvas, MousePosition)
	UpdateInputSelection(Canvas, MousePosition)

end

-----------------------------------------------------------------------

function uninit()

	painter:close()

end

-----------------------------------------------------------------------