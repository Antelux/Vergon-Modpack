local runOnce
local update_function

function init()
  storage.thrustStates = config.getParameter("flyingBoosterStates")
  animator.setAnimationState("thrustState", storage.thrustStates[world.flyingType()], true)
  --sb.logInfo("\noriginal init ran for" .. object.name())
end


update_function = function(dt)
  local engineMode = world.flyingType()
  if engineMode ~= storage.engineMode then
    animator.setAnimationState("thrustState", storage.thrustStates[engineMode], true)
    storage.engineMode = engineMode
  end
end


function update(dt)
  --temporary function gets ran once, then replaced.
  local FU_test = root.assetJson("/currencies.config")
  
  if FU_test.fufoodgoods then
    --sb.logInfo("\nFU detected\n")
    require "/objects/ship/fu_shipstatmodifier.lua"
    init()  --that script just redefined init, and now we run it.
  end
  
  update = update_function
end
