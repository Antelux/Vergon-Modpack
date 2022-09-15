-----------------------------------------------------------------------

require '/scripts/util/painter.lua'
require '/scripts/util/simplex.lua'

-----------------------------------------------------------------------

local ToolInput = painter:getToolInput()
local Areas = painter:getAreas()

-----------------------------------------------------------------------

local Tools = {

	pencil = {

		Apply = function(input, position, layer)

			return input

		end

	};

	eraser = {

		Apply = function(input, position, layer)

			return {
				material = {
					name = false;
					hueshift = 0;
				};

				matmod = {
					name = false;
					hueshift = 0;
				};

				liquid = {
					name = false;
					amount = 0;
				};
				
				collision = 'none';
				paint = 0;
			}

		end

	};

	-- Using dropper on larger area than 1x1 can be used as pattern/random/noise inputs for other brushes!
	dropper = {

		Apply = function(input, position, layer)

			ToolInput.material.name = world.material(position, layer) or false
			ToolInput.material.hueshift = world.materialHueShift(position, layer) or 0

			ToolInput.matmod.name = world.mod(position, layer) or false
			ToolInput.matmod.hueshift = world.modHueShift(position, layer) or 0

			-- = world.
			local Level = world.liquidAt(position) -- {width, height} of liquid within tile.

			ToolInput.liquid.name = Level and root.liquidName(Level[1]) or false
			ToolInput.liquid.amount = Level and Level[2] or 0

			-- none, platform, solid
			ToolInput.collision = 'solid'

			ToolInput.paint = world.materialColor(position, layer)

		end

	};

	paint = {

		Apply = function(input, position, layer)

			return { paint = input.paint }

		end

	};

	hueshift = {

		Apply = function(input, position, layer)

			return { 
				material = { hueshift = input.material.hueshift };
				matmod   = { hueshift = input.matmod.hueshift   };
			}

		end

	};

	modifier = {

		Apply = function(input, position, layer)
			
			return { matmod = input.matmod }

		end

	};

	gradient = {

		Apply = function(input, position, layer)
			
			return { }

		end
		
	};

	hydrator = {

		Apply = function(input, position, layer)

			return { liquid = input.liquid }

		end

	};

	collision = {

		Apply = function(input, position, layer)

			return { collision = input.collision }

		end

	};

	area = {

		from = nil;
		to = nil;

		Apply = function(input, position, layer, data)

			if not data.from then

				data.from = {position[1], position[2]}

			else

				data.to = {position[1], position[2]}

				Areas[1] = {data.from, data.to}

			end

			return { }

		end
	}

	--[[
	Measurer = {

		Settings = {

			Units = {
				type = 'list';
				entries = {
					'Blocks',
					'Meters',
					'Feet'
				}
			}
		}

	}
	--]]

}


local FromPosition = {}

function init()

	painter:open()
	
end

local function PointDictToArray(dict)

	local Points = {}
	local index = 1

	for coordinates, _ in pairs(dict) do

		local X, Y = coordinates:match('(%d+),(%d+)')
		
		Points[index] = {tonumber(X, 10), tonumber(Y, 10)}
		index = index + 1

	end

	return Points

end

local function GetPointsOnLine(from, to, size)

	local Points = {}

	local function Point(x, y)

		local ox2 = size // 2 - (((size % 2) == 0) and 1 or 0)
		local oy2 = size // 2

		for ox1 = 0, size - 1 do

			for oy1 = 0, size - 1 do

				local X = math.floor(x + ox1 - ox2)
				local Y = math.floor(y + oy1 - oy2)

				Points[X .. ',' .. Y] = true

			end

		end

	end

	if (from[1] == to[1]) and (from[2] == to[2]) then

		Point(from[1], from[2])
		return PointDictToArray(Points)

	end
	
	local minX = math.min(from[1], to[1])
	local maxX, minY, maxY

	if minX == from[1] then

		minY = from[2]
		maxX = to[1]
		maxY = to[2]

	else

		minY = to[2]
		maxX = from[1]
		maxY = from[2]

	end
		
	local xDiff = maxX - minX
	local yDiff = maxY - minY
			
	if xDiff > math.abs(yDiff) then

		local y = minY
		local dy = yDiff / xDiff

		for x = minX, maxX do

			Point(x, math.floor(y + 0.5))
			y = y + dy

		end

	else

		local x = minX
		local dx = xDiff / yDiff

		if maxY >= minY then

			for y = minY, maxY do

				Point(math.floor(x + 0.5), y)
				x = x + dx

			end

		else

			for y = minY, maxY, -1 do

				Point(math.floor(x + 0.5), y)
				x = x - dx

			end

		end

	end

	return PointDictToArray(Points)

end

-----------------------------------------------------------------------

local function GetNextInput(position)

	local FeedMode = painter:getFeedMode()
	local Height = #ToolInput.tiles
	local Width = #ToolInput.tiles[1]

	if FeedMode == 'random' then

		local Index = sb.staticRandomI32Range(0, Width * Height - 1, position[1], position[2])
		local X = (Index % Width) + 1
		local Y = (Index // Width) + 1

		return ToolInput.tiles[Y][X]

	elseif FeedMode == 'pattern' then

		return ToolInput.tiles[(position[2] % Height) + 1][(position[1] % Width) + 1]

	elseif FeedMode == 'noise' then

		local Noise = (simplex.Noise2D(position[1] / 10, position[2] / 10) + 1) / 2
		local Index = (Noise * (Width * Height)) // 1
		local X = (Index % Width) + 1
		local Y = (Index // Width) + 1

		return ToolInput.tiles[Y][X]

	else

		return ToolInput.tiles[1][1]

	end

end

-----------------------------------------------------------------------

local function ApplyTool(toolName, points)

	local Tool = Tools[toolName]
	if not Tool then return end

	-- Truthy: Apply exactly what is given.
	-- Nil: Leave it untouched.
	-- False: Remove/reset/default value.

	local Layer = painter:getLayer()

	for _, Point in ipairs(points) do

		local Input = GetNextInput(Point)
		local Output = Tool.Apply(Input, Point, Layer, Tool)

		if Output then

			--world.sendEntityMessage('SERVER', 'PLACE_MATERIAL', Point[1], Point[2])

			--
			if Output.material then

				if Output.material.name ~= nil then

					if Output.material.name == false then
						
						world.damageTiles({ Point }, Layer, Point, 'beamish', 1000, 0)

					else

						world.placeMaterial(Point, Layer, Output.material.name, Output.material.hueshift or 0, true)

					end

				end

			end

			if Output.matmod then

				if Output.matmod.name ~= nil then

					if Output.matmod.name then

						world.placeMod(Point, Layer, Output.matmod.name, Output.matmod.hueshift or 0, true)

					end

				end

			end

			if Output.liquid then
				
				if Output.liquid.name ~= nil then

					world.destroyLiquid(Point)

					if Output.liquid.name then

						world.spawnLiquid(Point, Output.liquid.name, Output.liquid.amount or 0)

					end

				end

			end

			if Output.paint then

				world.setMaterialColor(Point, Layer, Output.paint)

			end
			--

		end

	end

end

-----------------------------------------------------------------------

local lastShiftHeld = false

function update(dt, fireMode, isShiftHeld)

	local IsShiftPressed = false

	if isShiftHeld ~= lastShiftHeld then

		IsShiftPressed = isShiftHeld
		lastShiftHeld = isShiftHeld

	end

	-- Switch between layers.
	if IsShiftPressed then

		painter:swapLayer()

	end

	-- Change brush size.
	if math.__tech.args.upPressed then

		local Size = painter:getBrushSize() + (isShiftHeld and -1 or 1)
		if Size > 5 then Size = 1 elseif Size < 1 then Size = 5 end

		painter:setBrushSize(Size)

	end

	-- No tool in use.
	if fireMode == 'none' then

		FromPosition = nil
		return

	end

	local ToPosition = activeItem.ownerAimPosition()
	local ToolName = (fireMode == 'primary') and painter:getLeftTool() or painter:getRightTool()
	local Size = painter:getBrushSize()

	ToPosition[1] = ToPosition[1] // 1
	ToPosition[2] = ToPosition[2] // 1
	
	if FromPosition then

		-- Mouse moved.
		if (FromPosition[1] ~= ToPosition[1]) or (FromPosition[2] ~= ToPosition[2]) then

			ApplyTool(ToolName, GetPointsOnLine(FromPosition, ToPosition, Size))

		end

	else

		ApplyTool(ToolName, GetPointsOnLine(ToPosition, ToPosition, Size))

	end

	FromPosition = ToPosition

end

-----------------------------------------------------------------------

function activate(fireMode, isShiftHeld)

	update(1, fireMode, isShiftHeld)
	
end

-----------------------------------------------------------------------