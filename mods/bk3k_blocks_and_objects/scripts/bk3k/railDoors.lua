local railDoor_setMaterialSpaces = setMaterialSpaces
local railDoor_updateMaterialSpaces = updateMaterialSpaces
local matchRails


setMaterialSpaces = function(whatState, whatMaterialTableIndex)
  if (whatState == "open") then
    storage.matTableOpen[whatMaterialTableIndex] = matchRails()
  end
  railDoor_setMaterialSpaces(whatState, whatMaterialTableIndex)
end


updateMaterialSpaces = function()
  if storage.state then
    local materialSpaces = matchRails()
    if (#materialSpaces) > 0 then 
      storage.openMaterialSpaces = materialSpaces
    else
      storage.openMaterialSpaces = storage.matTableOpen[1]
    end
  end
  railDoor_updateMaterialSpaces()
end


matchRails = function()
  local materialSpaces = {}
  local i = 1

  if storage.isHorizontal then
    for k, space in ipairs(storage.spaces) do
      local rSpace = storage.realSpaces[k]
      local check, mat
      
      if space[2] == 0 then
        check = {rSpace[1], rSpace[2] - 1}
      else
        check = {rSpace[1], rSpace[2] + 1}
      end
      
      mat = world.material(check, "foreground") or "null"
                  
      if string.match(mat, "rail") then  --I'm using the results in a strictly boolean manor
        materialSpaces[i] = {space, mat}
        i = i + 1
      end
    end
  else
    for k, space in ipairs(storage.spaces) do
      local rSpace = storage.realSpaces[k]
      local check, mat
      
      if space[1] == 0 then
        check = {rSpace[1] - 1, rSpace[2]}
      else
        check = {rSpace[1] + 1, rSpace[2]}
      end
      
      mat = world.material(check, "foreground") or "null"
      
      if string.match(mat, "rail") then  --I'm using the results in a strictly boolean manor
      
        materialSpaces[i] = {space, mat}
        i = i + 1
      end
    end
  end
  
  return materialSpaces
end