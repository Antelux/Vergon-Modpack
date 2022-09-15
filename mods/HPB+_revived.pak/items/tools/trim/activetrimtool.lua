require "/scripts/vec2.lua"
require "/scripts/util.lua"

-- Read some variables from the item file and set an initial stance
function init()
	self.seed = config.getParameter("seed", "hullrivetsmall")
	self.rangeLimit = config.getParameter("rangeLimit", 15)
	self.sfx = config.getParameter("toolSound", "drill")
	self.stances = config.getParameter("stances")
	self.fireOffset = config.getParameter("fireOffset", {0,0})
	setStance("idle")
end

function update(dt, fireMode, shiftHeld)
	-- Get block position pointed at
	local pos = activeItem.ownerAimPosition()

	-- Place the mod if possible, playing a sound as we do so
	if fireMode == "primary" then
		fire(true, pos)
	elseif fireMode == "alt" then
		fire(false, pos)
	end

	-- Point the tool in the player's hands at the target point
	updateAim(self.stance.allowRotate, self.stance.allowFlip)
end

-- Place the mod if possible, playing a sound as we do so
function fire(isForeground, position)
	if canPlaceMod(isForeground, position) then
		-- Calculate range and determine if we're close enough
		local playerPosition = mcontroller.position()
		local inRange = (vecDist(playerPosition, position) <= self.rangeLimit)
		-- Place the mod only if we're close enough
		if (inRange) then
			if isForeground then
				world.placeMod(position,"foreground",self.seed,0,false)
			else
				world.placeMod(position,"background",self.seed,0,false)
			end
			animator.playSound(self.sfx)

			--FIX ME: Item consumption code would go here
			-- First I have to eliminate more bad targets
		end
	end
end

-- Thanks for this one Zoomah
-- Calculates the distance from point a to point b (both should be vectors)
function vecDist(a, b)
   return math.sqrt((a[1] - b[1])^2 + (a[2] - b[2])^2)
end

-- Returns true if we can place a material modifier on the the specified block
--  Still needs some work to remove some invalid targets; will probably have to use a black-list
--   for falling blocks
function canPlaceMod(isForeground, position)
	--FIX ME: Add a check for tumbling blocks and platforms
	if isForeground then
		if not world.material(position,"foreground") then
			return false
		else
			return not world.mod(position,"foreground")
		end
	else
		if not world.material(position,"background") then
			return false
		else
			return not world.mod(position,"background")
		end
	end
end

-- Returns true if the specified block has a material modifier on it
function hasMod(isForeground, position)
	if isForeground then
		return world.mod(position,"foreground") ~= nil
	else
		return world.mod(position,"background") ~= nil
	end
end

---------------------------------------------------
-- Copied from /items/active/grapple/grapple.lua --
-- Modified very slightly                        --
---------------------------------------------------
function setStance(stanceName)
  self.stanceName = stanceName
  self.stance = self.stances[stanceName]
  self.stanceTimer = self.stance.duration or 0
  animator.setAnimationState("weapon", stanceName == "active" and "empty" or "tool")
  animator.rotateGroup("weapon", util.toRadians(self.stance.weaponRotation))
  updateAim(self.stance.allowRotate, self.stance.allowFlip)
end

-- Point the tool in the player's hands at the target point
function updateAim(allowRotate, allowFlip)
  --local aimAngle, aimDirection = table.unpack(activeItem.aimAngleAndDirection(self.fireOffset[2], activeItem.ownerAimPosition()))
  local aimAngle, aimDirection = activeItem.aimAngleAndDirection(self.fireOffset[2], activeItem.ownerAimPosition())
  
  if allowRotate then
    self.aimAngle = aimAngle
  end
  aimAngle = (self.aimAngle or 0) + util.toRadians(self.stance.armRotation)
  activeItem.setArmAngle(aimAngle)

  if allowFlip then
    self.aimDirection = aimDirection
  end
  activeItem.setFacingDirection((self.aimDirection or 0))
end