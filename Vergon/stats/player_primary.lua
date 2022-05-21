require "/scripts/status.lua"
require "/scripts/achievements.lua"


function init()
  
  self.inflictedDamage = damageListener("inflictedDamage", inflictedDamageCallback)

  message.setHandler("applyStatusEffect", function(_, _, effectConfig, duration, sourceEntityId)
  
  end)

	status.modifyResource("health", status.stat("maxHealth"))
end

function inflictedDamageCallback(notifications)
  for _,notification in ipairs(notifications) do
    if notification.killed then
      if world.entityExists(notification.targetEntityId) then
        local entityType = world.entityType(notification.targetEntityId)
        local eventFields = entityEventFields(notification.targetEntityId)
        util.mergeTable(eventFields, worldEventFields())
        eventFields.damageSourceKind = notification.damageSourceKind

        if entityType == "object" then
          recordEvent(entity.id(), "killObject", eventFields)

        elseif entityType == "npc" or entityType == "monster" or entityType == "player" then
          recordEvent(entity.id(), "kill", eventFields)
        end
      else
        -- TODO: better method for getting data on killed entities
        sb.logInfo("Skipped event recording for nonexistent entity %s", notification.targetEntityId)
      end
    end
  end
end

function applyDamageRequest(damageRequest)
  
    return {}
end



function notifyResourceConsumed(resourceName, amount)
    -- Ensures energy never runs out.
	if resourceName == "energy" then
  		status.modifyResourcePercentage("energy", 1)

    -- Ensures health never runs out.
	elseif resourceName == "health" then
		status.modifyResource("health", status.stat("maxHealth"))

	end
end



function update(dt)
  status.modifyResource("health", status.stat("maxHealth"))
end

function overheadBars()
    local bars = {}

    if status.statPositive("shieldHealth") then
        table.insert(bars, {
            percentage = status.resource("shieldStamina"),
            color = status.resourcePositive("perfectBlock") and {255, 255, 200, 255} or {200, 200, 0, 255}
        })
    end

    return bars
end