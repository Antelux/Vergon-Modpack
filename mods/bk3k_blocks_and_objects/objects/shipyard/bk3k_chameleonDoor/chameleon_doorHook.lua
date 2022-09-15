local chameleon_init = init
local chameleon_update = update
local chameleon_initMaterialSpaces = initMaterialSpaces

local chameleonMaterials

function init() --hooked, will call regular init() which is now called chameleonInit()
  if not storage.quickCheck then
    storage.chameleonSet = false
  end

  chameleon_init()
  self.chameleonCooldown = 0
end


function update(args)  --hooked, will call the regular update() which is now called chameleonUpdate()
  if self.chameleonCooldown > 0 then
    self.chameleonCooldown = self.chameleonCooldown - args
  elseif not storage.chameleonSet then
    initMaterialSpaces() --search again for materials to mimick
    updateCollisionAndWires()
    if storage.chameleonSet then
      updateAnimation(storage.state)
    end
  end

  chameleon_update(args)
end


function initMaterialSpaces()  --hooked, defines storage.matTableClosed ahead of time
  local metaMatC = chameleonMaterials( {"metamaterial:door", "metamaterial:lockedDoor"} )
  --if nothing chosen, returns default
  storage.matTableClosed = {}
  for k, v in ipairs(metaMatC) do
    storage.matTableClosed[k] = buildMaterialSpaces(storage.spaces, v)
  end
  chameleon_initMaterialSpaces(metaMatC)
end


function chameleonMaterials(defaultMat_Table)
  local check
  local offset
  local whatMaterial

  if storage.isHorizontal then
    offset = {1, 0}
    check = {
      cMath.add(storage.corners.upperRight, offset ),
      cMath.add(storage.corners.lowerRight, offset ),
      cMath.sub(storage.corners.upperLeft, offset ),
      cMath.sub(storage.corners.lowerLeft, offset )
      }
  else
    offset = {0, 1}
    check = {
      cMath.add(storage.corners.upperRight, offset ),
      cMath.sub(storage.corners.lowerRight, offset ),
      cMath.add(storage.corners.upperLeft, offset ),
      cMath.sub(storage.corners.lowerLeft, offset )
      }
  end

  --check for material in the foreground
  for _, f in ipairs(check) do
    whatMaterial = world.material(f, "foreground")
    if whatMaterial then
      if (whatMaterial ~= "metamaterial:door") and (whatMaterial ~= "metamaterial:lockedDoor") then
        storage.chameleonSet = true
        return {whatMaterial, whatMaterial}
      end
    end
  end


  --that must have found nothing, so look for materials in the background

  for _, b in ipairs(check) do
    whatMaterial = world.material(b, "background")
    if whatMaterial then
      if (whatMaterial ~= "metamaterial:door") and (whatMaterial ~= "metamaterial:lockedDoor") then
        storage.chameleonSet = true
        return {whatMaterial, whatMaterial}
      end
    end
  end


  --nothing was found in either!
  storage.chameleonSet = false
  self.chameleonCooldown = 15

  if not storage.state then
    --no frame drawing if the door is open!  That would give away it's presence.
    --and I may want a hidden ladder made from mid-air doors below a platform, etc
    animator.setAnimationState("doorState", "frame")
  end

  return defaultMat_Table

end