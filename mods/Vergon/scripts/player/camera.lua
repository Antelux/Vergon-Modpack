-----------------------------------------------------------------------

-- https://easings.net/
-- localAnimator - Relative coordinates to player
--				   will be one frame behind to player coordinates unless entity messages are used to delay updates. 

--[[
	
	TODO:

		- Aiming is based on mouse location relative to screen center,
		  not relative to player location.

	IDEAS:

		- Might be better to use a client-side stagehand instead of a monster?

		- Mark monster with special 'clientside' bool in paramters that tells
		  the server not to delete it but not to send data out for it either.
		  Allows voices??

--]]

local COLLISION_SET = { 'block', 'dynamic' }
local Size;

local MonsterPosition = {0, 0}
local TargetPosition = {0, 0}
local OldPosition = {0, 0}
local LastPosition = {0, 0}
local MonsterID;
local MonsterHasFocus = false
local cameraEnabled = true
local lastTime;
local cameraDelay = 0
local cameraTimer = 0
local lastMoveUp;
local lastItem;
local lastUpdate = 0;

local tileWidth = (2560/8)/3 -- ~107
local tileHeight = (1440/8)/3 -- ~59

-----------------------------------------------------------------------

local Camera = {

	targetEntity = nil,
	swapItem = nil,
	hooked = false
}

function Camera.sizeUpdate(tW, tH)

	tileWidth = tW
	tileHeight = tH

end

math.__camera = Camera

-----------------------------------------------------------------------

local function SetTargetEntity(entityID)

	Camera.targetEntity = entityID

	local SwapItem = player.swapSlotItem()

	Camera.swapItem = function()

		player.setSwapSlotItem(SwapItem)
		Camera.swapItem = nil

	end

	player.setSwapSlotItem({
		name = 'commonshortsword',
		parameters = { scripts = { '/items/active/RoleplayCamera.lua' } }
	})

end

-----------------------------------------------------------------------

local function SetMonsterPosition()--positionX, positionY)

	--MonsterPosition[1] = positionX
	--MonsterPosition[2] = positionY

	if MonsterID and world.entityExists(MonsterID) then
		
		world.callScriptedEntity(MonsterID, 'mcontroller.setPosition', MonsterPosition);

	else

		MonsterID = nil;
		MonsterHasFocus = false;

	end

end

-----------------------------------------------------------------------

local function IsItemAimable(item)

	local Parameters = item and item.parameters

	return Parameters and 
	(
		(
			Parameters.primaryAbility and 
			Parameters.primaryAbility.baseDps and
			(Parameters.primaryAbility.baseDps > 0)
		)
		--or Parameters.primaryAbilityType
		or
		(
			Parameters.altAbility and 
			Parameters.altAbility.baseDps and
			(Parameters.altAbility.baseDps > 0)
		)
		--or Parameters.altAbilityType
	)

end

-----------------------------------------------------------------------

local function EaseInOutSine(x)

	return -(math.cos(math.pi * x) - 1) / 2

end

-----------------------------------------------------------------------

local function Clamp(value, min, max)

	return math.min(math.max(value, min), max)

end

-----------------------------------------------------------------------

function init()

	Size = world.size()

	script.setUpdateDelta(1)

end

-----------------------------------------------------------------------

function update()

	local Event = math.__event
	if not Event then return end

	if not Camera.hooked then

		Camera.hooked = true

		message.setHandler('CAMERA', function(_, _, newWidth, newHeight)

			Camera.sizeUpdate(newWidth, newHeight)

		end)

	end

	-- No need to update this script.
	script.setUpdateDelta(0)

	-- /camera command.
	Event.setTimeout(coroutine.create(function()

		local Chat

		repeat

			Event.sleep(Event.time.SECOND / 60)
			Chat = math.__chat

		until Chat

		Chat.addCommand(

			'camera (state: bool?)',
			'Toggles the roleplay camera on or off.',

			function(Chat, args)

				cameraEnabled = not cameraEnabled

				Chat.clientMessage('Roleplay camera ' .. (cameraEnabled and '^green;enabled' or '^red;disabled') .. '^reset;.')

			end
		)

	end))

	-- Main camera loop.
	Event.setInterval(function(deltaTime)

		local Tech = math.__tech
		if not Tech then return end

		local PlayerX = mcontroller.xPosition()
		local PlayerY = mcontroller.yPosition()

		if MonsterHasFocus then

			if not cameraEnabled then

				SetTargetEntity()
				MonsterHasFocus = false

				return

			end

		elseif cameraEnabled then

			if not (MonsterID and world.entityExists(MonsterID)) then

				local Config = root.assetJson('/monsters/monsterConfig.json')
				MonsterID = world.spawnMonster('mechshielddrone', {PlayerX, PlayerY}, Config)

				MonsterPosition[1] = PlayerX
				MonsterPosition[2] = PlayerY

				TargetPosition[1] = PlayerX
				TargetPosition[2] = PlayerY

				OldPosition[1] = PlayerX
				OldPosition[2] = PlayerY

				LastPosition[1] = PlayerX
				LastPosition[2] = PlayerY

			else

				SetTargetEntity(MonsterID)
				MonsterHasFocus = true

			end

		else

			return

		end

		local function DistanceSquared(point1, point2)

			local xDelta = point1[1] - point2[1]
			local yDelta = point1[2] - point2[2]

			return (xDelta * xDelta) + (yDelta * yDelta)

		end

		local function HLine(xLength, yOffset)

			local Start = {PlayerX, PlayerY + yOffset}
			local Finish = {PlayerX + xLength, PlayerY + yOffset}

			-- Make sure we're not testing in a separate area from the player.
			local Point = world.lineTileCollisionPoint(LastPosition, Start)
			if Point and (DistanceSquared(LastPosition, Point[1]) > (3^2)) then
				return
			end

			Point = world.lineTileCollisionPoint(Start, Finish, COLLISION_SET)

			--world.debugLine(Start, Point or Finish, Point and {255, 0, 255} or {0, 255, 255})
			--if Point then world.debugText('{%s, %s}', Point[1], Point[2], Point, {255, 0, 255}) end

			return Point and Point[1]
		end

		local function VLine(yLength, xOffset)

			local Start = {PlayerX + xOffset, PlayerY}
			local Finish = {PlayerX + xOffset, PlayerY + yLength}

			-- Make sure we're not testing in a separate area from the player.
			local Point = world.lineTileCollisionPoint(LastPosition, Start)
			if Point and (((mcontroller.facingDirection() * xOffset) ~= math.abs(xOffset)) or (DistanceSquared(LastPosition, Point[1]) > (3^2))) then
				return
			end

			Point = world.lineTileCollisionPoint(Start, Finish, COLLISION_SET)

			-- Ignore 1 block thick ceilings.
			if yLength > 0 then

				while Point do

					-- -5 penalty for ignoring.
					yLength = yLength - (Point[1][2] - Start[2]) - 1 - 5

					if yLength <= 0 then 
						break
					end

					Point[1][2] = Point[1][2] + 1

					if world.material(Point[1], 'foreground') then
						break
					end

					Finish[2] = PlayerY + yLength

					--world.debugLine(Point, Finish, {255, 0, 0})
					Point = world.lineTileCollisionPoint(Point[1], Finish, COLLISION_SET)
				end
			end

			--world.debugLine(Start, Point or Finish, Point and {255, 0, 255} or {0, 255, 255})
			--if Point then world.debugText('{%s, %s}', Point[1], Point[2], Point, {255, 0, 255}) end

			return Point and Point[1]

		end

		local function Mix(x, y, f)

			return (x * (1 - f)) + (y * f)

		end

		local function Total(points, index)

			local total = 0
			local count = 0

			for i = 1, #points do

				local Point = points[i]

				if Point then

					total = total + Point[index]
					count = count + 1

				end
			end

			return total, count

		end

		--{{-0.75, -2.0}, {-0.35, -2.5}, {0.35, -2.5}, {0.75, -2.0}, {0.75, 0.65}, {0.35, 1.22}, {-0.35, 1.22}, {-0.75, 0.65}}

		local PrimaryItem = player.primaryHandItem()
		local AltItem = player.altHandItem()

		local Item = PrimaryItem or AltItem
		local ItemIsAimable = IsItemAimable(PrimaryItem) or IsItemAimable(AltItem)
		local LookUp = Tech.args.moves.up
		local PeriodicUpdate = (os.clock() - lastUpdate) >= 3

		cameraTimer =
			((MonsterPosition[1] ~= TargetPosition[1]) or (MonsterPosition[2] ~= TargetPosition[2])) and
			(cameraTimer + deltaTime) or 0

		if 
			(LastPosition[1] ~= PlayerX) or (LastPosition[2] ~= PlayerY) or 
			(lastMoveUp ~= LookUp) or (lastItem ~= Item) or
			PeriodicUpdate -- Update when standing still every 3 seconds.
		then

			cameraDelay = ((lastMoveUp ~= LookUp) or (lastItem ~= Item) or PeriodicUpdate) and 1 or (cameraDelay + deltaTime)

			if cameraDelay >= 0.1 then

				LastPosition[1] = PlayerX
				LastPosition[2] = PlayerY

				if ItemIsAimable then

					local AimPosition = Tech.aimPosition();
					local AimAngle = math.atan(AimPosition[2] - PlayerY, AimPosition[1] - PlayerX)

					TargetPosition[1] = PlayerX + (math.cos(AimAngle) * math.min(math.abs(AimPosition[1] - PlayerX), tileWidth/3))
					TargetPosition[2] = PlayerY + (math.sin(AimAngle) * math.min(math.abs(AimPosition[2] - PlayerY), tileHeight/3))

				else

					local HOffset = (tileWidth * 0.85) // 1 -- 0.7
					local NHOffset = -HOffset

					local VOffset = (tileHeight * 0.85) // 1
					local NVOffset = -VOffset

					local LeftAverage, LeftCount = Total({
						HLine(NHOffset, -1.00 * 3),
						HLine(NHOffset, -1.00 * 2),
						HLine(NHOffset, -1.00 * 1),
						HLine(NHOffset, -1.00 * 0),
						HLine(NHOffset,  1.00 * 1),
						HLine(NHOffset,  1.00 * 2),
						HLine(NHOffset,  1.00 * 3),
						HLine(NHOffset,  1.00 * 4),
						HLine(NHOffset,  1.00 * 5),
						HLine(NHOffset,  1.00 * 6)
					}, 1)

					local RightAverage, RightCount = Total({
						HLine(HOffset, -1.00 * 3),
						HLine(HOffset, -1.00 * 2),
						HLine(HOffset, -1.00 * 1),
						HLine(HOffset, -1.00 * 0),
						HLine(HOffset,  1.00 * 1),
						HLine(HOffset,  1.00 * 2),
						HLine(HOffset,  1.00 * 3),
						HLine(HOffset,  1.00 * 4),
						HLine(HOffset,  1.00 * 5),
						HLine(HOffset,  1.00 * 6)
					}, 1)

					local BottomAverage, BottomCount = Total({
						VLine(NVOffset, -0.75 * 23),
						VLine(NVOffset, -0.75 * 20),
						VLine(NVOffset, -0.75 * 17),
						VLine(NVOffset, -0.75 * 14),
						VLine(NVOffset, -0.75 * 11),
						VLine(NVOffset, -0.75 * 8),
						VLine(NVOffset, -0.75 * 5),
						VLine(NVOffset, -0.75 * 2),
						VLine(NVOffset,  0.75 * 2),
						VLine(NVOffset,  0.75 * 5),
						VLine(NVOffset,  0.75 * 8),
						VLine(NVOffset,  0.75 * 11),
						VLine(NVOffset,  0.75 * 14),
						VLine(NVOffset,  0.75 * 17),
						VLine(NVOffset,  0.75 * 20),
						VLine(NVOffset,  0.75 * 23)
					}, 2)

					local TopAverage, TopCount = Total({
						VLine(VOffset, -0.75 * 23),
						VLine(VOffset, -0.75 * 20),
						VLine(VOffset, -0.75 * 17),
						VLine(VOffset, -0.75 * 14),
						VLine(VOffset, -0.75 * 11),
						VLine(VOffset, -0.75 * 8 ),
						VLine(VOffset, -0.75 * 5 ),
						VLine(VOffset, -0.75 * 2 ),
						VLine(VOffset,  0.75 * 2),
						VLine(VOffset,  0.75 * 5),
						VLine(VOffset,  0.75 * 8),
						VLine(VOffset,  0.75 * 11),
						VLine(VOffset,  0.75 * 14),
						VLine(VOffset,  0.75 * 17),
						VLine(VOffset,  0.75 * 20),
						VLine(VOffset,  0.75 * 23)
					}, 2)

					local TargetX, TargetY

					if (LeftCount >= 6) and (RightCount >= 6) then

						TargetX = (LeftAverage + RightAverage) / (LeftCount + RightCount)

					end

					if (BottomCount >= 9) and (TopCount >= 9) then

						TargetY = (BottomAverage + TopAverage) / (BottomCount + TopCount)

					end

					local VelocityX = mcontroller.xVelocity() / Tech.factor
					local VelocityY = mcontroller.yVelocity() / Tech.factor

					--sb.setLogMap('adj_vel', '%s, %s', VelocityX, VelocityY)
					--sb.setLogMap('FPS', '%s', Tech.FPS or '??')

					local HorizontalSpeed = Clamp(VelocityX, -30, 30) / 30
					local VerticalSpeed   = Clamp(VelocityY, -120, 120) / 120

					local MovementOffsetX = PlayerX + (HorizontalSpeed * (tileWidth / 2))
					local MovementOffsetY = PlayerY + (VerticalSpeed * tileHeight)

					TargetPosition[1] = TargetX or MovementOffsetX
					TargetPosition[2] = TargetY or MovementOffsetY

					if LeftCount >= 5 then

						local Left = (LeftAverage / LeftCount) + 8
						TargetPosition[1] = math.max(TargetPosition[1], Left)

					end

					if RightCount >= 5 then

						local Right = (RightAverage / RightCount) - 8
						TargetPosition[1] = math.min(TargetPosition[1], Right)

					end

					if BottomCount >= 7 then

						local Bottom = (BottomAverage / BottomCount) + 4
						TargetPosition[2] = math.max(TargetPosition[2], Bottom)

					end

					if TopCount >= 7 then

						local Top = (TopAverage / TopCount) - 4
						TargetPosition[2] = math.min(TargetPosition[2], Top)

					end

					if LookUp then

						TargetPosition[2] = TargetPosition[2] + (tileHeight/3)

					end

					TargetPosition[1] = Clamp(TargetPosition[1], PlayerX - (tileWidth/2.5), PlayerX + (tileWidth/2.5))
					TargetPosition[2] = Clamp(TargetPosition[2], PlayerY - (tileHeight/2.5), PlayerY + (tileHeight/2.5))

				end

			end

			lastUpdate = os.clock()

		else

			cameraDelay = 0

		end

		lastMoveUp = LookUp
		lastItem = Item

		if (MonsterPosition[1] ~= TargetPosition[1]) or (MonsterPosition[2] ~= TargetPosition[2]) then
			
			-- Crossing world seam detection.
			if math.abs(TargetPosition[1] - MonsterPosition[1]) >= (Size[1] / 2) then

				if MonsterPosition[1] < 0 then -- Eastward

					MonsterPosition[1] = MonsterPosition[1] + Size[1]

				else -- Westward

					MonsterPosition[1] = MonsterPosition[1] - Size[1]

				end

			end

			local function Approach(from, to, amount)

				if from < to then

					return math.min(from + amount, to)

				elseif from > to then

					return math.max(from - amount, to)

				else

					return from

				end

			end

			local xDivisor = (ItemIsAimable and (tileWidth/2.75) or (tileWidth/2)) * ((1 - EaseInOutSine(Clamp(cameraTimer * 3, 0, 1))) + 1)
			local yDivisor = (ItemIsAimable and (tileHeight/2.75) or (tileHeight/2)) * ((1 - EaseInOutSine(Clamp(cameraTimer * 3, 0, 1))) + 1)

			local MinXFactor = 1 / (tileWidth * 50)
			local MinYFactor = 1 / (tileHeight * 50)

			local xFactor = ((TargetPosition[1] - MonsterPosition[1]) * Tech.factor) / xDivisor
			local yFactor = ((TargetPosition[2] - MonsterPosition[2]) * Tech.factor) / yDivisor

			OldPosition[1] = MonsterPosition[1]
			OldPosition[2] = MonsterPosition[2]

			MonsterPosition[1] = Approach(OldPosition[1], TargetPosition[1], math.max(math.abs(xFactor), MinXFactor))
			MonsterPosition[2] = Approach(OldPosition[2], TargetPosition[2], math.max(math.abs(yFactor), MinYFactor))

			SetMonsterPosition()

		end

		--world.debugPoint(MonsterPosition, {255, 255, 255})
		--world.debugText('{%s, %s}', MonsterPosition[1], MonsterPosition[2], MonsterPosition, {255, 0, 255})

		--world.debugPoint(TargetPosition, {255, 255, 0})
		--world.debugText('{%s, %s}', TargetPosition[1], TargetPosition[2], TargetPosition, {255, 255, 0})

	end)

end

-----------------------------------------------------------------------