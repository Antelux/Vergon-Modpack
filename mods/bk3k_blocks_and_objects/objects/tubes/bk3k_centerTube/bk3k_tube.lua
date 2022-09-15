require("/scripts/bk3k/bk3k-cMath2d(0.21).lua")
require("/scripts/bk3k/bk3kLogger(0.1).lua")

function init()
  --if storage.state then return end
  cMath = _ENV["bk3kcMath2d0.21"]
  L = _ENV.bk3kLogger
  
  --local objectName = config.getParameter("objectName")
  storage.walls = storage.walls or config.getParameter("walls", config.getParameter("spaces", {}) )
  if (#storage.walls) < 1 then  --no walls?  Build them and dump to log
    local wallPoints = config.getParameter("wallPoints", {object.position()})
    storage.walls = cMath.walls(wallPoints)
    L.dump({walls = walls},{"main tube script init","for objectName : ", tostring(objectName), " tube walls"})
  end
      
  local materialSpaces = config.getParameter("wallMaterialSpaces") or 
    buildMaterialSpaces(storage.walls, config.getParameter("wallMaterial", "metamaterial:objectsolid") )
  --materialSpaces = buildMaterialSpaces(storage.walls, "bk3k_invisible_hardBlock")
  object.setMaterialSpaces(materialSpaces) 
  
  local background_material = config.getParameter("background_material")
  
  storage.backgroundSpaces = config.getParameter("backgroundSpaces", {})
  
  storage.backgroundSpaces = translateSpaces(storage.backgroundSpaces)
  
  --storage.state = true
end


function buildMaterialSpaces(spaces, material)
  local retTable = {}
  for i, space in ipairs(spaces) do
    retTable[i] = {space, material}
  end
  
  local doDebug = config.getParameter("doDebug", false)
  if doDebug then 
    logMatSpaces(retTable)
  end
  
  return retTable
  
  
end

function logMatSpaces(ms)
  --JSON
  local str = "\n  [\n"
  local len = #ms
  for k, v in ipairs(ms) do
    str = str .. "    [ [" .. tostring(v[1][1]) .. ", " .. tostring(v[1][2]) .. "], \"" .. v[2] .. "\" ]"
    if len == k then
      str = str .. "\n"
    else
      str = str .. ",\n"
    end
  end
  
  str = str .. "  ]\n"
  sb.logInfo(str)
end

function buildBackground(spaces, material)
  
end

function clearBackground(spaces)
  
  world.damageTiles(storage.backgroundSpaces, "background", object.position(), "blockish", 65535, 0)
end

function die()
  clearBackground()
end

function tubeRemoval()
  die()
end

function translateSpaces(spaces)
  local realSpaces = {}
  local clamp = cMath.floor(object.position()) --it probably isn't strickly necessary to clamp the location
  for k, v in ipairs(spaces) do
    realSpaces[k] = cMath.add(v , clamp)
  end
  return realSpaces
end