require "/scripts/vec2.lua"
require "/scripts/util.lua"

function configParameter(name,default)
  if vehicle.configParameter then
    return vehicle.configParameter(name,default)--Glad
  else
    return config.getParameter(name,default)--Cheerful
  end
end


function healthLevelAdjust(hp_or_armor)
  return root.evalFunction("shieldLevelMultiplier", self.level) * hp_or_armor
end


function init()
  storage.oremats = storage.oremats or nil

  self.specialLast = false
  self.active = false
  self.fireTimer = 0
  animator.rotateGroup("guns", 0, true)
  self.level = configParameter("mechLevel", 6)
  self.groundFrames = 1
  self.driver = false
  self.vacTimer = 0
  self.facingDirection = 1
  self.movingDirection = 1
  
-- seating
  self.seats = configParameter("loungePositions")
  for k,v in pairs(self.seats) do
    self.seats[k].seatPos = animator.partPoint(v.part,v.partAnchor)
  end
--  sb.logInfo("\n%s",self.seats)
-- required for damaging
  self.maxHealth = healthLevelAdjust(configParameter("maxHealth",1000))
  self.protection = healthLevelAdjust(configParameter("protection",60))
  self.materialKind = configParameter("materialKind","robotic")

  if storage.health == nil then
    local storedHP = configParameter("startHealthFactor")

    if (storedHP == nil) then
        storage.health = self.maxHealth
    else
       storage.health = math.min(storedHP * self.maxHealth, self.maxHealth)
    end    
    self.warpPosition = mcontroller.position()
    animator.setAnimationState("movement", "warpIn")
  else
    animator.setAnimationState("movement", "idle")
  end
    
  --this comes in from the controller.
  self.ownerKey = configParameter("ownerKey")
  vehicle.setPersistent(self.ownerKey)

   --setup the store functionality  
  message.setHandler("store",
    function(_, _, ownerKey)

      if (self.ownerKey and self.ownerKey == ownerKey and self.driver == nil and animator.animationState("movement")=="idle") then
        self.warpPosition = mcontroller.position()
        animator.setAnimationState("movement", "warpOut")
--                          vehicle.destroy()
        return {storable = true, healthFactor = storage.health / self.maxHealth}
      else
        return {storable = false, healthFactor = storage.health / self.maxHealth}
      end
    end
  )


end

--------------------------------------------------------------------------------

function update()

  local warpAni = animator.animationState("movement")
  if warpAni == "warpOutEnd" then
    vehicle.destroy()
    return
  elseif warpAni == "warpIn" or warpAni == "warpOut" then
    world.debugText("warping",mcontroller.position(),"red")

    --lock it solid whilst spawning/despawning
--    mcontroller.setPosition(self.warpPosition)
    mcontroller.setVelocity({0,0})
    return
  end

  local mechAimLimit = configParameter("mechAimLimit") * math.pi / 180
  local mechHorizontalMovement = configParameter("mechHorizontalMovement")
  local mechJumpVelocity = configParameter("mechJumpVelocity")
  local mechFireCycle = configParameter("mechFireCycle")
  local mechProjectile = configParameter("mechProjectile")
  local mechProjectileConfig = configParameter("mechProjectileConfig")
  local offGroundFrames = configParameter("offGroundFrames")

  local mechCollisionPoly = mcontroller.collisionPoly()
  local position = mcontroller.position()

  -- if mechProjectileConfig.power then
    -- mechProjectileConfig.power = root.evalFunction("gunDamageLevelMultiplier", self.level) * mechProjectileConfig.power
  -- end

  updateVehicleDamage() -- damage visuals
  
  local entityInSeat = vehicle.entityLoungingIn("seat")
  if entityInSeat ~= self.driver then
    self.driver = entityInSeat
    animator.setLightActive("dashGlow",not entityInSeat)
    vehicle.setInteractive(not entityInSeat)
  end
  if not entityInSeat then
    vehicle.setDamageTeam({type = "passive"})
    animator.rotateGroup("guns", -mechAimLimit,true)
    animator.setAnimationState("movement", "idle")
    if self.engineLoopPlaying then
      animator.stopAllSounds("idle")
      self.engineLoopPlaying = false
      animator.playSound("idle")
      animator.setSoundVolume("idle",0,2)
    end
    return
  end
  if animator.hasSound("idle") then
    if not self.engineLoopPlaying then
      self.engineLoopPlaying = true
--      animator.setSoundVolume("idle",0,0)
      animator.playSound("idle",-1) -- loop forever -1
--      if animator.hasSound("startup") then animator.playSound("startup") end

    else
      animator.setSoundVolume("idle",0.5,0.5)
      animator.setSoundPitch("idle",0.6,0.2)
    end
  end
  vehicle.setDamageTeam(world.entityDamageTeam(entityInSeat))
  
---- movement + animation
  local aimSeatPos = {self.seats["seat"].seatPos[1],self.seats["seat"].seatPos[2]}
  aimSeatPos[1] = aimSeatPos[1]>0 and 0 or aimSeatPos[1]*self.facingDirection--*self.movingDirection
  aimSeatPos = vec2.add(mcontroller.position(),aimSeatPos)
  world.debugLine(vehicle.aimPosition("seat"), aimSeatPos,"white")
  local diff = world.distance(vehicle.aimPosition("seat"), aimSeatPos)
  local aimAngle = math.atan(diff[2], diff[1])
  local facingDirection = (aimAngle > math.pi / 2 or aimAngle < -math.pi / 2) and -1 or 1

  if facingDirection < 0 then
    animator.setFlipped(true)

    if aimAngle > 0 then
      aimAngle = math.max(aimAngle, math.pi - mechAimLimit)
    else
      aimAngle = math.min(aimAngle, -math.pi + mechAimLimit)
    end

    animator.rotateGroup("guns", math.pi - aimAngle)
  else
    animator.setFlipped(false)

    if aimAngle > 0 then
      aimAngle = math.min(aimAngle, mechAimLimit)
    else
      aimAngle = math.max(aimAngle, -mechAimLimit)
    end

    animator.rotateGroup("guns", aimAngle)
  end
  self.facingDirection = facingDirection
  self.aimAngle = aimAngle
--world.debugText("%s\n%s",self.aimAngle,mechAimLimit,mcontroller.position(),"green")
  local onGround = mcontroller.onGround()
  local movingDirection = 0

-- controls
  if vehicle.controlHeld("seat", "left") and onGround then
    mcontroller.setXVelocity(-mechHorizontalMovement)
    movingDirection = -1
  end

  if vehicle.controlHeld("seat", "right") and onGround then
    mcontroller.setXVelocity(mechHorizontalMovement)
    movingDirection = 1
  end
  
  if vehicle.controlHeld("seat", "up") then
    if animator.hasSound("idle") then
      animator.setSoundVolume("idle",1,0.5)
      animator.setSoundPitch("idle",1,0.5)
    end
  end
        
  if vehicle.controlHeld("seat", "down") then
    mcontroller.applyParameters({ignorePlatformCollision=true})
  else
    if mcontroller.parameters().ignorePlatformCollision then
      mcontroller.applyParameters({ignorePlatformCollision=false})
    end
  end

  if vehicle.controlHeld("seat", "jump") and onGround and self.vacTimer <=0 then
--lpk:change jump to item vacuum
    local bounds = mcontroller.localBoundBox()
    local vh = (bounds[4]-bounds[2])
    local bl = vec2.add(position,{bounds[1],bounds[2]-0.5})
    local tr = vec2.add(position,{bounds[3],bounds[2]+1})
--    util.debugRect(bounds,{255,180,0,255})
    local oids = world.itemDropQuery(bl,tr)
    for _,oid in pairs(oids) do
      local item = world.takeItemDrop(oid,entity.id())
      if item then
      world.spawnItem(item.name,position,item.count or 1,item.parameters)
      end
    end
    self.vacTimer = 1
    -- mcontroller.setXVelocity(mechJumpVelocity[1] * movingDirection)
    -- mcontroller.setYVelocity(mechJumpVelocity[2])
    -- animator.setAnimationState("movement", "jump")
    -- self.groundFrames = 0
  else
    self.vacTimer = self.vacTimer - script.updateDt()
  end

  if onGround then
    self.groundFrames = offGroundFrames
  else
    self.groundFrames = self.groundFrames - 1
  end
  
  local emote = self.lastEmote
  local dance = self.lastDance
  local curhp = math.ceil((storage.health/self.maxHealth)*4)
  if self.groundFrames <= 0 then
    if mcontroller.velocity()[2] > 0 then
      animator.setAnimationState("movement", "jump")
    else
      animator.setAnimationState("movement", "fall")
    end
    dance = "panic" -- off ground panic
  elseif movingDirection ~= 0 then
    self.movingDirection = movingDirection
    if facingDirection ~= movingDirection then
      animator.setAnimationState("movement", "backWalk")
    else
      animator.setAnimationState("movement", "walk")
    end
    local emotes = {"annoyed","neutral","happy","laugh"}
    dance = "typing" -- push/pull lever action
    emote = emotes[curhp]--"laugh"
    if self.engineLoopPlaying then
      animator.setSoundPitch("idle",1,0)
      animator.setSoundVolume("idle",1,0.5)
    end
  elseif onGround then
    animator.setAnimationState("movement", "idle")
    local emotes = {"sad","sad","annoyed","happy"}
    dance = "flipswitch" -- arms at sides
    emote = emotes[curhp]--"annoyed"
  end

  if emote ~= self.lastEmote then vehicle.setLoungeEmote("seat",emote) self.lastEmote = emote end
  if dance ~= self.lastDance then vehicle.setLoungeDance("seat",dance) self.lastDance = dance end
  
  if vehicle.controlHeld("seat", "primaryFire") then
-- dig fg
    bulldozeTiles("foreground")
  end
  if vehicle.controlHeld("seat", "altFire") then
-- dig bg
    bulldozeTiles("background")
  end
end

--------------------------------------------------------------------------------

function bulldozeTiles(layer)
	local bullPos = mcontroller.position()
  local bullFace = self.facingDirection
  local bullPower = configParameter("bulldozeDamage")
  local bulldozeOffset = configParameter("bulldozeOffset")
  local bulldozeBlocks = configParameter("bulldozeBlocks")
  local bullYOffset = 0
  local mechAimLimit = configParameter("mechAimLimit") * math.pi / 180

  if (self.aimAngle == mechAimLimit or self.aimAngle == (math.pi - mechAimLimit)) then bullYOffset = 1 end
  if (self.aimAngle == -mechAimLimit or self.aimAngle == (-math.pi + mechAimLimit)) then bullYOffset = -1 end
  
	bullPos = {bullPos[1], math.floor(bullPos[2])}
	
	for key,value in pairs(bulldozeBlocks) do
			bulldozeBlocks[key][1] = (value[1] + bulldozeOffset)*bullFace + bullPos[1]
			bulldozeBlocks[key][2] = value[2] + bullPos[2] + bullYOffset
      damageBlock(layer,bulldozeBlocks[key],bullPower)--(bullPower*script.updateDt()))
	end

end

--------------------------------------------------------------------------------
-- modified version of the tile damage code from mining gardenbot
function damageBlock(layer,block,dmg,hrv)
if dmg == nil then dmg = 1 end
if hrv == nil then hrv = 99 end
if layer == nil then layer = "foreground" end
  local dmgtiles = false
--  local matname = world.material(block,layer)
--  util.debugRect({block[1],block[2],block[1]+1,block[2]+1},"red")
  world.debugPoint({block[1]+0.5,block[2]+0.5},"white")
  if not world.tileIsOccupied(block,layer=="foreground") then return end
  world.debugLine({block[1]+1,block[2]},{block[1],block[2]+1},"red")
  world.debugLine({block[1]+1,block[2]+1},{block[1],block[2]},"red")
--  if not matname then return end
--  if matname and harvestmats(matname) ~= 0 then
--  hrv = 99 
--  end

--  local modName = world.mod(block,layer)
--  if modName then --and isOre(modName) then
--    dmgtiles = world.damageTiles({block},layer,block,"blockish",(0.75*dmg)) 
--    if storage.oremats == nil then storage.oremats = {} end
--    if storage.oremats[matname] == nil then storage.oremats[matname] = true end
--  else
    dmgtiles = world.damageTiles({block},layer,block,"blockish",dmg)
--  end
  if not dmgtiles then -- maybe tree over ?! 
    dmgtiles = world.damageTiles({vec2.add(block,{0,1})},layer,block,"plantish",2*dmg)
  end
  if not dmgtiles then -- maybe vine under ?
    dmgtiles = world.damageTiles({vec2.add(block,{0,-1})},layer,block,"plantish",2*dmg)
  end
  if dmgtiles then
--[[
    if entity.hasSound("mine") and self.mineSoundTimer < 0 then 
      entity.playSound("mine")
      self.mineSoundTimer = 0.3 -- no earraping sounds plx
    end
--]]
  end
  return dmgtiles
end
--------------------------------------------------------------------------------
function harvestmats(matname)
if type(matname) ~= "string" then return 0 end -- filter out numbers and booleans
--local badmats = {"rock","stone","mud","clay","sand","dirt","gravel","ice","slush","snow","moon","ash","flesh","bone","plantmat","hazard"}
--for _,v in ipairs(badmats) do
--if string.find(matname,v) then return 0 end
--end
if storage.oremats and storage.oremats[matname] == true then return 0 end
return 1
end

--------------------------------------------------------------------------------
-- damage to vehicle
function applyDamage(damageRequest)
  local damage = 0
  if damageRequest.damageType == "Damage" then
    damage = damage + root.evalFunction2("protection", damageRequest.damage, self.protection)
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damage + damageRequest.damage
  else
    return {}
  end
if damage > 0 then
  storage.health = math.max(storage.health - damage,0)
  updateVehicleHitDamage()
end

  if vehicle.getParameter then -- glad
  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damage = damage,
    hitType = "Hit",
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = self.materialKind,
    killed = storage.health <= 0
  }}
  else -- cheerful
  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damageDealt = damage,
    healthLost = damage,
    hitType = "Hit",
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = self.materialKind,
    killed = storage.health <= 0
  }}
  end
end

--------------------------------------------------------------------------------
-- damage visuals
function updateVehicleDamage()  -- called per frame, randomize smoke/fire 
local curhealth = storage.health/self.maxHealth
  if curhealth > 0.8 or math.random() < curhealth then return end  -- undamaged, gtfo
  
  if curhealth <= 0.8 and math.random() > curhealth then    -- 1 smoke
    animator.burstParticleEmitter("smoke")    
  end
  if curhealth <= 0.7 and math.random() > curhealth then    -- 1 smoke
    animator.burstParticleEmitter("smoke")    
  end
  if curhealth <= 0.6 and math.random() > curhealth then
    animator.burstParticleEmitter("smoke")    
  end
  if curhealth <= 0.5 and math.random() > curhealth then
   -- 1 smoke 1 fire
    animator.burstParticleEmitter("smoke2")    
    animator.burstParticleEmitter("fire")
  end
  if curhealth <= 0.25 and math.random() > curhealth then
    -- 2 fire
    animator.burstParticleEmitter("fire")
    animator.burstParticleEmitter("fire2")
  end

end

function updateVehicleHitDamage() -- called when hit, spit out damage shards / explode when 0 hp

  animator.burstParticleEmitter("damageShards")
  if storage.health <= 0 then -- blow chunks and EXPLOSIONS!
    local projectileConfig = {
      damageTeam = { type = "indiscriminate" },
      power = configParameter("explosionDamage"),
      onlyHitTerrain = true,
      timeToLive = 0,
      actionOnReap = {
        {
          action = "config",
          file =  configParameter("explosionConfig")
        }
      }
    }
    world.spawnProjectile("invisibleprojectile", mcontroller.position(), 0, {0, 0}, false, projectileConfig)

    animator.burstParticleEmitter("wreckage")
    animator.burstParticleEmitter("damageShards")

    vehicle.destroy()  -- your head asplode!
  end
  
end
--------------------------------------------------------------------------------
--[[
--prints tables
function printTable(indent, value)
    local tabs = "";
    for i=1,indent,1 do
        tabs = tabs.."    ";
    end
    table.sort(value)
    for k,v in pairs(value) do
        world.logInfo(tabs..getValueOutput(k,v));
        if type(v) == "table" then
            if tostring(k) == "utf8" then
                world.logInfo("    "..tabs.."SKIPPING UTF8")-- SINCE IT SEEMS TO HAVE NO END AND JUST BE FILLED WITH TABLES OF TABLES
            else
                if tableLen(v) == 0 then
                    world.logInfo("    "..tabs.."EMPTY TABLE")
                else
                    printTable(indent+1,v);
                 
                end
            end
            world.logInfo(" ");
        end
    end
 
end

function tableLen(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

--Required for printTable
function getValueOutput(key ,value)
    if type(value) == "table" then
        return "table : "..key;
    elseif type(value) == "function" then
        return "function : "..key.."()"
    elseif type(value) == "string" then
        return "string : "..key.." - \""..tostring(value).."\"";
    else
        return type(value).." : "..key.." - "..tostring(value);
    end
end
]]