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
				paint = false; --0;
			}

		end

	};

	-- Using dropper on larger area than 1x1 can be used as pattern/random/noise inputs for other brushes!
	dropper = {

		Apply = function(input, position, layer)

			local Level = world.liquidAt(position) -- {width, height} of liquid within tile.
			local Paint = world.materialColor(position, layer)


			ToolInput.tiles = {
				{
					{
						material = {
							name = world.material(position, layer) or false;
							hueshift = world.materialHueShift(position, layer) or 0;
						};

						matmod = {
							name = world.mod(position, layer) or false;
							hueshift = world.modHueShift(position, layer) or 0;
						};

						liquid = {
							id = Level and Level[1] or false;
							name = Level and root.liquidName(Level[1]) or false;
							amount =  Level and Level[2] or 0;
						};
						
						collision = 'solid';
						paint = (Paint ~= 0) and Paint or nil;
					}
				}
			}

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

	animator.setSoundVolume('place', 0.9)
	animator.setSoundVolume('break', 0.8)
	animator.setSoundVolume('paint', 0.9)
	animator.setSoundVolume('liquid', 1.5)
	
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

local data = { area = {} }

local function ApplyTool(toolName, mouseButton, isShiftHeld, fromPosition, toPosition)

	--local Tool = Tools[toolName]
	--if not Tool then return end

	-- Truthy: Apply exactly what is given.
	-- Nil: Leave it untouched.
	-- False: Remove/reset/default value.

	if (toolName == 'brush') and (mouseButton ~= 'none') then

		local Layer = painter:getLayer()
		local Size = painter:getBrushSize()

		local Points = GetPointsOnLine(fromPosition, toPosition, Size)
		local Tool =
			(
				(mouseButton == 'left') and 
				(isShiftHeld and Tools.dropper or Tools.pencil)
			) or
			(
				(mouseButton == 'right') and 
				Tools.eraser
			)

		local soundsToPlay = {}

		for _, Point in ipairs(Points) do

			local Input = GetNextInput(Point)
			local Output = Tool.Apply(Input, Point, Layer, Tool)

			if Output then

				--world.sendEntityMessage('SERVER', 'PLACE_MATERIAL', Point[1], Point[2])

				--
				if Output.material then

					if Output.material.name ~= nil then

						if Output.material.name == false then
							
							world.damageTiles({ Point }, Layer, Point, 'beamish', 1000, 0)
							table.insert(soundsToPlay, 'break')

						else

							world.placeMaterial(Point, Layer, Output.material.name, Output.material.hueshift or 0, true)
							table.insert(soundsToPlay, 'place')

						end

					end

				end

				if Output.matmod then

					if Output.matmod.name ~= nil then

						if Output.matmod.name then

							world.placeMod(Point, Layer, Output.matmod.name, Output.matmod.hueshift or 0, true)
							table.insert(soundsToPlay, 'place')

						end

					end

				end

				if Output.liquid then
					
					if Output.liquid.id ~= nil then

						world.destroyLiquid(Point)

						if Output.liquid.id then

							world.spawnLiquid(Point, Output.liquid.id, Output.liquid.amount or 0)
							table.insert(soundsToPlay, 'liquid')

						end

					end

				end

				if Output.paint then

					world.setMaterialColor(Point, Layer, Output.paint)
					table.insert(soundsToPlay, 'paint')

				end
				--

			end

		end

		for _, Sound in ipairs(soundsToPlay) do

			animator.setSoundPitch(Sound, 1 + (((math.random() * 2) - 1) * 0.1))
			animator.setSoundVolume(Sound, ((1 / #soundsToPlay) ^ 0.5) * 0.85)
			animator.playSound(Sound)

		end

	elseif toolName == 'area' then

		local Area = data.area

		if mouseButton == 'right' then

			local Area = Areas[#Areas]
			local From, To = Area[1], Area[2]

			local MinX = math.min(From[1], To[1])
			local MinY = math.min(From[2], To[2])

			local MaxX = math.max(From[1], To[1])
			local MaxY = math.max(From[2], To[2])

			local Layer = painter:getLayer()
			local Position = {}
			local indexY = 1

			ToolInput.tiles = {}

			for y = MinY, MaxY do

				local Tiles = {}
				local indexX = 1

				Position[2] = y

				for x = MinX, MaxX do

					Position[1] = x

					Tiles[indexX] = {
						material = {
							name = world.material(Position, Layer) or false;
							hueshift = world.materialHueShift(Position, Layer) or 0;
						};

						matmod = {
							name = world.mod(Position, Layer) or false;
							hueshift = world.modHueShift(Position, Layer) or 0;
						};

						liquid = {
							id = Level and Level[1] or false;
							name = Level and root.liquidName(Level[1]) or false;
							amount =  Level and Level[2] or 0;
						};
						
						collision = 'solid';
						paint = (Paint ~= 0) and Paint or nil;
					}

					indexX = indexX + 1

				end

				ToolInput.tiles[indexY] = Tiles

				indexY = indexY + 1

			end

		else

			if not Area[1] then

				Area[1] = {fromPosition[1], fromPosition[2]}

			else

				Area[2] = {toPosition[1], toPosition[2]}

			end

		end

		if mouseButton == 'none' then

			table.insert(Areas, Area)

			data.area = {}

		end

	end

end

-----------------------------------------------------------------------

local lastShiftHeld = false
local lastFireMode = 'none'
local lastShiftPress = 0

function update(dt, fireMode, isShiftHeld)

	local IsShiftPressed = false

	if isShiftHeld ~= lastShiftHeld then

		IsShiftPressed = isShiftHeld
		lastShiftHeld = isShiftHeld

	end

	local FireModeChanged = false

	if fireMode ~= lastFireMode then

		FireModeChanged = true
		lastFireMode = fireMode

	end

	-- Switch between layers.
	if IsShiftPressed then

		-- TODO: 'Both' layer.
		if (os.clock() - lastShiftPress) <= 0.25 then

			painter:swapLayer()

		end

		lastShiftPress = os.clock()

	end

	-- Change brush size.
	if math.__tech.args.upPressed then

		local Size = painter:getBrushSize() + (isShiftHeld and -1 or 1)
		if Size > 5 then Size = 1 elseif Size < 1 then Size = 5 end

		painter:setBrushSize(Size)

	end

	local ToPosition = activeItem.ownerAimPosition()
	local ToolName = painter:getLeftTool() --(fireMode == 'primary') and painter:getLeftTool() or painter:getRightTool()
	local MouseButton = 
		((fireMode == 'primary') and 'left') or
		((fireMode == 'alt') and 'right') or 'none'

	ToPosition[1] = ToPosition[1] // 1
	ToPosition[2] = ToPosition[2] // 1
	
	if FromPosition then

		-- Mouse moved.
		if (FromPosition[1] ~= ToPosition[1]) or (FromPosition[2] ~= ToPosition[2]) or FireModeChanged then

			ApplyTool(ToolName, MouseButton, isShiftHeld, FromPosition, ToPosition)

		end

	elseif FireModeChanged then

		ApplyTool(ToolName, MouseButton, isShiftHeld, ToPosition, ToPosition)

	end

	FromPosition = (MouseButton ~= 'none') and ToPosition or false

end

-----------------------------------------------------------------------

function activate(fireMode, isShiftHeld)

	update(1, fireMode, isShiftHeld)
	
end

-----------------------------------------------------------------------