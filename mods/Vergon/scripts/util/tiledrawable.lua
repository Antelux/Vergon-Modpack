-----------------------------------------------------------------------

local Assets = {}
local ImageSizes = {}
local Materials = {}
local Mods = {}
local Liquids = {}

-----------------------------------------------------------------------

tileDrawable = {}

--[[
{
	path: /tiles/materials/brick.material, 
	config: {
		health: 8,
		description: Small but perfectly formed bricks made from clay.,
		novakidDescription: Nice lookin' brickwork.,
		materialId: 2,
		particleColor: {1: 134, 2: 72, 3: 50, 4: 255},
		category: materials,
		floranDescription: Ssimple bricksss.,
		itemDrop: brickmaterial,
		glitchDescription: Pleased. These bricks have been carefully formed and arranged.,
		footstepSound: /sfx/blocks/footstep_stone2.ogg,
		renderParameters: {
			occludesBelow: true,
			texture: brick.png,
			lightTransparent: false,
			multiColored: true,
			variants: 5,
			zLevel: 2860
		},
		shortdescription: Bricks,
		materialName: brick,
		renderTemplate: /tiles/classicmaterialtemplate.config
	}
}
]]

-----------------------------------------------------------------------

local function GetFilePath(basePath, fileName)

	if fileName:sub(1, 1) == '/' then

		return fileName

	elseif basePath:sub(-1) == '/' then

		return basePath .. fileName

	else

		return basePath:match('^(.+%/).-$') .. fileName

	end

end

-----------------------------------------------------------------------

local function GenerateCropDirectives(tileJSON, tileImage, paintIndex, x, y)

	local TemplatePath = GetFilePath(tileJSON.path, tileJSON.config.renderTemplate)
	local Variant = sb.staticRandomI32Range(0, (tileJSON.config.renderParameters.variants or 1) - 1, x, y)

	local Template = Assets[TemplatePath] or root.assetJson(TemplatePath)
	Assets[TemplatePath] = Template

	local Size = ImageSizes[tileImage] or root.imageSize(tileImage)
	ImageSizes[tileImage] = Size

	local Piece = Template.pieces[Template.representativePiece]

	local TexSX = Piece.texturePosition[1] + (paintIndex * Piece.colorStride[1]) + (Variant * Piece.variantStride[1]) --- 3
	local TexSY = Piece.texturePosition[2] + (paintIndex * Piece.colorStride[2]) + (Variant * Piece.variantStride[2]) --- 3

	local TexEX = TexSX + Piece.textureSize[1] --+ 6
	local TexEY = TexSY + Piece.textureSize[2] --+ 6

	return '?crop;' .. TexSX .. ';' .. (Size[2] - TexEY) .. ';' .. TexEX .. ';' .. (Size[2] - TexSY)

end

-----------------------------------------------------------------------

function tileDrawable.material(materialName, paintIndex, x, y)

	local MaterialConfig = Materials[materialName] or root.materialConfig(materialName) or Materials.MISSING

	Materials[materialName] = MaterialConfig

	if not MaterialConfig.image then

		MaterialConfig.image = GetFilePath(MaterialConfig.path, MaterialConfig.config.renderParameters.texture)

	end

	if not MaterialConfig.color then

		MaterialConfig.color = MaterialConfig.config.particleColor or {}

		MaterialConfig.color[1] = MaterialConfig.color[1] or 198
		MaterialConfig.color[2] = MaterialConfig.color[2] or 198
		MaterialConfig.color[3] = MaterialConfig.color[3] or 198
		MaterialConfig.color[4] = MaterialConfig.color[4] or 255

	end

	local Crop = GenerateCropDirectives(MaterialConfig, MaterialConfig.image, paintIndex or 0, x or 0, y or 0)

	return MaterialConfig.image .. Crop, MaterialConfig.color

end

-----------------------------------------------------------------------

function tileDrawable.mod(modName, paintIndex)

	local ModConfig = Mods[modName] or root.modConfig(modName) or Mods.MISSING

	Mods[modName] = ModConfig

	if not ModConfig.image then

		ModConfig.image = GetFilePath(ModConfig.path, ModConfig.config.renderParameters.texture)

	end

	local Crop = GenerateCropDirectives(ModConfig, ModConfig.image, 0)

	return ModConfig.image .. Crop

end

-----------------------------------------------------------------------

function tileDrawable.liquid(liquidName)

	local LiquidConfig = Liquids[liquidName] or root.liquidConfig(liquidName) or Liquids.MISSING

	Liquids[liquidName] = LiquidConfig

	if not LiquidConfig.image then

		LiquidConfig.image = GetFilePath(LiquidConfig.path, LiquidConfig.config.texture) .. '?crop;4;4;12;'

	end

	if not LiquidConfig.color then

		LiquidConfig.color = LiquidConfig.config.color or {}

		LiquidConfig.color[1] = LiquidConfig.color[1] or 225
		LiquidConfig.color[2] = LiquidConfig.color[2] or 225
		LiquidConfig.color[3] = LiquidConfig.color[3] or 225
		LiquidConfig.color[4] = LiquidConfig.color[4] or 128

	end

	return LiquidConfig.image, LiquidConfig.color

end

-----------------------------------------------------------------------