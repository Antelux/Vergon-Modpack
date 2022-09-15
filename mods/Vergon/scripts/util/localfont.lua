-----------------------------------------------------------------------

local LetterTextures = {}
local ShadowTextures = {}

for i = 32, 127 do

	local Letter = string.char(i)

	local Row, Column = (6 - (i // 16)) + 1, i % 16
	local TexX, TexY = Column * 10, Row * 10

	LetterTextures[Letter] = '/interface/localfont.png?crop;' .. TexX .. ';' .. TexY .. ';' .. (TexX + 10) .. ';' .. (TexY + 10)
	ShadowTextures[Letter] = '/interface/localfontshadowed.png?crop;' .. TexX .. ';' .. TexY .. ';' .. (TexX + 10) .. ';' .. (TexY + 10)

end

for i = 0, 255 do

	local Letter = string.char(i)

	LetterTextures[Letter] = LetterTextures[Letter] or LetterTextures[' ']
	ShadowTextures[Letter] = ShadowTextures[Letter] or ShadowTextures[' ']

end

-----------------------------------------------------------------------

local Letter = {
	image = '/interface/localfont.png';
	centered = false;
	mirrored = false;
	rotation = 0;
	position = {0, 0};
	fullbright = true;
}

-----------------------------------------------------------------------

function NewLocalFont(localAnimator)

	local Localfont = {
		__animator = localAnimator;
		__scale = 1.0;
		__color = 'FFF';
		__rotation = 0;
	}

	function Localfont:setScale(scale)

		self.__scale = scale

	end

	function Localfont:setRotation(degrees)

		self.__rotation = math.rad(degrees)

	end

	function Localfont:setColor(r, g, b, a)

		r = (r or 255) // 1
		g = (g or 255) // 1
		b = (b or 255) // 1
		a = (a or 255) // 1

		self.__color = string.format('%02X%02X%02X%02X', r, g, b, a)

	end

	function Localfont:renderText(text, x, y, isShadowed)

		text = tostring(text)

		local Textures = isShadowed and ShadowTextures or LetterTextures
		local AddDrawable = self.__animator.addDrawable
		local Position = Letter.position

		local Params = '?multiply=' .. self.__color .. '?scalenearest=' .. self.__scale

		local OffsetX = 0.125 * 10 * math.cos(self.__rotation) * self.__scale
		local OffsetY = 0.125 * 10 * math.sin(self.__rotation) * self.__scale

		Letter.rotation = self.__rotation

		Position[1] = x
		Position[2] = y

		for i = 1, #text do

			Letter.image = Textures[text:sub(i, i)] .. Params

			AddDrawable(Letter, 'ForegroundTile+1')

			Position[1] = Position[1] + OffsetX
			Position[2] = Position[2] + OffsetY

		end
	end

	return Localfont

end

-----------------------------------------------------------------------