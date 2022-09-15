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
    update_animation(storage.wasOccupied, occupied)
    update_materialSpaces(occupied)
  end
  
  storage.wasOccupied = occupied
end

function update_animation(occupied)
  
  if storage.anchor.bottom then
    
  elseif storage.anchor.left then
  
  elseif storage.anchor.right then
  
  end

end

function update_materialSpaces(inUse)
  if inUse then
    object.setMaterialSpaces(storage.closedMaterialSpaces)
  else
    object.setMaterialSpaces(storage.openMaterialSpaces)
  end
end