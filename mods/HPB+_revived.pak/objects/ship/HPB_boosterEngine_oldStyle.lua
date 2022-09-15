--This is for Boosters engines that haven't been revamped
--aka animations don't work in FTL
--The only actual purpose is to make things function in FU-BYOS
local runOnce
local update_function

function init()
  --Does nothing
  --sb.logInfo("\noriginal init ran for" .. object.name())
end


update_function = function(dt)
  --Does nothing
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
