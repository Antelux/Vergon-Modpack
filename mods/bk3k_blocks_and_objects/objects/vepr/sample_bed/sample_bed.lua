function init()
  storage.id = entity.id()
  storage.wasOccupied = false
  storage.openMaterialSpaces = config.getParameter("openMaterialSpaces", {})
  storage.closedMaterialSpaces = config.getParameter("closedMaterialSpaces", {})
  local anchor = config.getParameter("anchors", {})
  storage.anchor = {
    bottom = (anchor[1] == "bottom"),
    right = (anchor[1] == "right"),
    left = (anchor[1] == "left"),
  }
  update_materialSpaces(false)
  update_animation(false)
end


function update(dt)
  local occupied = world.loungeableOccupied(storage.id)
  if storage.wasOccupied ~= occupied then
    update_animation(occupied)
    update_materialSpaces(occupied)
  end
  
  storage.wasOccupied = occupied
end

function update_animation(occupied)
  local bedState = ""
  
  if occupied then
    bedState = "in_use"
  else
    bedState = "idle"
  end
      
  animator.setAnimationState("bedState", bedState, true)
  
  if animator.hasSound(bedstate) then
    animator.playSound(bedstate)
  end
end

function update_materialSpaces(occupied)
  if occupied then
    object.setMaterialSpaces(storage.closedMaterialSpaces)
  else
    object.setMaterialSpaces(storage.openMaterialSpaces)
  end
end