--------------------------------------------------------------------

require "/scripts/vec2.lua"

--------------------------------------------------------------------

--[[

args : {
	moves : {
		up : "boolean"
		down : "boolean"
		left : "boolean"
		right : "boolean"
		jump : "boolean"
		run : "boolean"
		primaryFire : "boolean"
		altFire : "boolean"
		special1 : "boolean"
		special2 : "boolean"
		special3 : "boolean"
	},
	dt : "basically script.updateDt"
}

--]]

local Special1_Pressed = false
local Special2_Pressed = false
local Special3_Pressed = false

local Sit_Enabled = false

local Position = {0, 0}
local Velocity = {0, 0}
local Center;

local Reset_Timer = 0

local Rotation = 0
local TargetRotation = Rotation

local Scale = 1
local TargetScale = Scale

local Scaled_Poly = {
	standingPoly = {{-0.75, -2.0}, {-0.35, -2.5}, {0.35, -2.5}, {0.75, -2.0}, {0.75, 0.65}, {0.35, 1.22}, {-0.35, 1.22}, {-0.75, 0.65}},
	crouchingPoly = {{-0.75, -2.0}, {-0.35, -2.5}, {0.35, -2.5}, {0.75, -2.0}, {0.75, -1.0}, {0.35, -0.5}, {-0.35, -0.5}, {-0.75, -1.0}}
}

function init()
  self.angularVelocity = 0
  self.active = false
  self.angle = 0
  self.transformFadeTimer = 0

  self.ballRadius = config.getParameter("ballRadius")
  self.ballFrames = config.getParameter("ballFrames")
  self.ballSpeed = config.getParameter("ballSpeed")
  self.transformFadeTime = config.getParameter("transformFadeTime", 0.3)
  self.transformedMovementParameters = config.getParameter("transformedMovementParameters")

  self.transformedMovementParameters.runSpeed = self.ballSpeed * 2
  self.transformedMovementParameters.walkSpeed = self.ballSpeed
  self.basePoly = mcontroller.baseParameters().standingPoly

  math.__tech = tech
  math.__tech.args = { moves = {} }
  math.__tech.factor = 0

end

function uninit()

	tech.setParentState()

	mcontroller.setRotation(0)

	mcontroller.controlParameters({
		standingPoly = {{-0.75, -2.0}, {-0.35, -2.5}, {0.35, -2.5}, {0.75, -2.0}, {0.75, 0.65}, {0.35, 1.22}, {-0.35, 1.22}, {-0.75, 0.65}},
		crouchingPoly = {{-0.75, -2.0}, {-0.35, -2.5}, {0.35, -2.5}, {0.75, -2.0}, {0.75, -1.0}, {0.35, -0.5}, {-0.35, -0.5}, {-0.75, -1.0}}
	})

	if math.__player then

		math.__player.setProperty('VERGON_SCALE', TargetScale)

	end

end

--------------------

local lastIsMoving = false
local loaded = false
local lastTime = os.clock()

local Parameters = {}
local DeltaTimeArray = { length = 60 }

for i = 1, DeltaTimeArray.length do

	DeltaTimeArray[i] = 1/60

end

function update(args)

	local TimeNow = os.clock()
	local DeltaTime = TimeNow - lastTime

	lastTime = TimeNow

	local Event = math.__event
	if not Event then return end

	if (not loaded) and math.__player then

		TargetScale = math.max(math.min(math.__player.getProperty('VERGON_SCALE', 1), 2), 0.5)
		loaded = true

	end

	--

	math.__tech.args = args

	--

	local IsMoving = 
		args.moves.left or
		args.moves.right or
		args.moves.jump or
		args.moves.primaryFire or
		args.moves.altFire
	
	if IsMoving ~= lastIsMoving then

		Event.trigger('movement', IsMoving)
		lastIsMoving = IsMoving

	end

	--

	do

		local averageDelta = DeltaTime

		for i = DeltaTimeArray.length, 2, -1 do

			local Delta = DeltaTimeArray[i - 1]

			DeltaTimeArray[i] = Delta

			averageDelta = averageDelta + Delta

		end

		averageDelta = averageDelta / DeltaTimeArray.length

		DeltaTimeArray[1] = DeltaTime

		local Factor = averageDelta / (1/60)

		Parameters.walkSpeed = 8.0  * Factor
		Parameters.runSpeed  = 14.0 * Factor
		Parameters.flySpeed  = 8.0  * Factor

		Parameters.mass = 1.6 * Factor
		Parameters.gravityMultiplier = 1.5 * Factor

		mcontroller.controlParameters(Parameters)

		math.__tech.factor = Factor

	end

	----------------------------------------------------------------------------------------------------
	-- Chat
	----------------------------------------------------------------------------------------------------

	if args.moves.special1 and (not Special1_Pressed) then

		local Player = math.__player
		local Chat   = math.__chat

		if Chat then

			Chat.focus()

		elseif Player then

			Player.interact('ScriptPane', '/interface/newchat/chat.config')

		end

	end

	Special1_Pressed = args.moves.special1

	----------------------------------------------------------------------------------------------------
	-- Sit
	----------------------------------------------------------------------------------------------------

	if args.moves.special2 and (not Special2_Pressed) then

		---------------- Sit  ----------------

		-- Switch sitting on/off.
		Sit_Enabled = not Sit_Enabled

		if Sit_Enabled then
			
			-- Set up sitting for the code below this chunk.
			--Position = mcontroller.position()
			tech.setParentState("sit")
			
		else

			-- Set the player back to normal.
			tech.setParentState()

		end
		
	end

	Special2_Pressed = args.moves.special2

	Center = (not mcontroller.onGround()) and Center or nil

	if Sit_Enabled then

		local Speed = args.moves.run and 0.1 or 0.05
		
		Position = mcontroller.position()
		Center = Center or Position

		local Left   = Center[1] - 1.5
		local Right  = Center[1] + 1.5
		local Bottom = Center[2] - 1.5
		local Top    = Center[2] + 1.5

		Position[1] = 
			(args.moves.left  and math.max(Position[1] - Speed, Left)) or
			(args.moves.right and math.min(Position[1] + Speed, Right)) or
			Position[1]

		Position[2] = 
			(args.moves.down and math.max(Position[2] - Speed, Bottom)) or
			(args.moves.up   and math.min(Position[2] + Speed, Top)) or
			Position[2]

		-- Disable looking up with camera.
		args.moves.up = false

		mcontroller.setVelocity(Velocity)
		mcontroller.setPosition(Position)

	end 
  
	----------------------------------------------------------------------------------------------------
	-- Rotation & Scaling
	----------------------------------------------------------------------------------------------------

	if args.moves.special3 then

		---------------- Rotation  ----------------

		-- Rotate to the right.
		if args.moves.right then

			TargetRotation = Rotation - 0.05

		-- Rotate to the left.
		elseif args.moves.left then

			TargetRotation = Rotation + 0.05

		-- Reset rotation.
		elseif args.moves.run and (not Special3_Pressed) and (Reset_Timer > 0) then

			TargetRotation = ((Rotation >= 0) and (Rotation // 2) or math.ceil(Rotation / 2)) * 2

		end

		---------------- Scaling  ----------------

		-- Scale up.
		if args.moves.down then

			TargetScale = math.max(Scale - 0.01, 0.5)

		-- Scale down.
		elseif args.moves.up then

			TargetScale = math.min(Scale + 0.01, 2)

			-- Disable looking up with camera.
			args.moves.up = false

		-- Reset scale.
		elseif (not args.moves.run) and (not Special3_Pressed) and Reset_Timer > 0 then

			TargetScale = 1

		end

		-- Reset the...well, reset timer.
		Reset_Timer = 0.15

	end

	Special3_Pressed = args.moves.special3

	do --

		local Delta = TargetRotation - Rotation
		local rotationChanged = Rotation

		if math.abs(Delta) <= 0.1 then

			Rotation = TargetRotation

		elseif Delta < 0 then

			Rotation = Rotation - 0.05


		elseif Delta > 0 then

			Rotation = Rotation + 0.05

		end

		rotationChanged = rotationChanged ~= Rotation

		-- Apply rotation.
		if rotationChanged then
			
			mcontroller.setRotation(math.pi * Rotation)

		end

	end

	do --

		local Delta = TargetScale - Scale
		local scaleChanged = Scale

		if math.abs(Delta) <= 0.02 then

			Scale = TargetScale

		elseif Delta < 0 then

			Scale = Scale - 0.01


		elseif Delta > 0 then

			Scale = Scale + 0.01

		end

		scaleChanged = scaleChanged ~= Scale

		-- Change the hitbox of the character to take into account their new scale.
		if scaleChanged then

			Scaled_Poly.standingPoly[1][1] = -0.75 * Scale; Scaled_Poly.standingPoly[1][2] = -2.00 * Scale
			Scaled_Poly.standingPoly[2][1] = -0.35 * Scale; Scaled_Poly.standingPoly[2][2] = -2.50 * Scale
			Scaled_Poly.standingPoly[3][1] =  0.35 * Scale; Scaled_Poly.standingPoly[3][2] = -2.50 * Scale
			Scaled_Poly.standingPoly[4][1] =  0.75 * Scale; Scaled_Poly.standingPoly[4][2] = -2.00 * Scale
			Scaled_Poly.standingPoly[5][1] =  0.75 * Scale; Scaled_Poly.standingPoly[5][2] =  0.65 * Scale
			Scaled_Poly.standingPoly[6][1] =  0.35 * Scale; Scaled_Poly.standingPoly[6][2] =  1.22 * Scale
			Scaled_Poly.standingPoly[7][1] = -0.35 * Scale; Scaled_Poly.standingPoly[7][2] =  1.22 * Scale
			Scaled_Poly.standingPoly[8][1] = -0.75 * Scale; Scaled_Poly.standingPoly[8][2] =  0.65 * Scale

			Scaled_Poly.crouchingPoly[1][1] = -0.75 * Scale; Scaled_Poly.crouchingPoly[1][2] = -2.0 * Scale
			Scaled_Poly.crouchingPoly[2][1] = -0.35 * Scale; Scaled_Poly.crouchingPoly[2][2] = -2.5 * Scale
			Scaled_Poly.crouchingPoly[3][1] =  0.35 * Scale; Scaled_Poly.crouchingPoly[3][2] = -2.5 * Scale
			Scaled_Poly.crouchingPoly[4][1] =  0.75 * Scale; Scaled_Poly.crouchingPoly[4][2] = -2.0 * Scale
			Scaled_Poly.crouchingPoly[5][1] =  0.75 * Scale; Scaled_Poly.crouchingPoly[5][2] = -1.0 * Scale
			Scaled_Poly.crouchingPoly[6][1] =  0.35 * Scale; Scaled_Poly.crouchingPoly[6][2] = -0.5 * Scale
			Scaled_Poly.crouchingPoly[7][1] = -0.35 * Scale; Scaled_Poly.crouchingPoly[7][2] = -0.5 * Scale
			Scaled_Poly.crouchingPoly[8][1] = -0.75 * Scale; Scaled_Poly.crouchingPoly[8][2] = -1.0 * Scale

		end

		mcontroller.controlParameters(Scaled_Poly)

		-- Apply scale.
		if scaleChanged or math.__afkChange then

			tech.setParentDirectives('?scalenearest=' .. Scale .. ((math.__pingable and '?saturation=-15?brightness=-40') or (math.__isAFK and '?saturation=-100?brightness=-50') or ''))
			math.__afkChange = false

		end

	end

	-- And of course, update timers accordingly.
	if Reset_Timer > 0 then

		Reset_Timer = Reset_Timer - args.dt

	end

end