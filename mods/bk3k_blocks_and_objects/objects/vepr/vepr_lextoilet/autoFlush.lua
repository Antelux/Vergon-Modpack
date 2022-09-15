function init()
  storage.id = entity.id()
  storage.autoFlush = false
  storage.cooldown = 0
end


function update(dt)
  local occupied = world.loungeableOccupied(storage.id)
  if storage.autoFlush and occupied then
    --nothing  
  elseif occupied then
    storage.autoFlush = true
    storage.cooldown = 1.50
  elseif storage.cooldown > 0 then
    storage.cooldown = storage.cooldown - dt
  elseif storage.autoFlush then
    storage.autoFlush = false
    animator.setAnimationState("toiletState", "flush", false)
    animator.playSound("flush", 1)
  end
end