local sr_original_init = init

function init(...)  --this is what I added
  local pos = object.position()
  local addItems = config.getParameter("additionalItems", {})

  for reason, group in pairs(addItems) do
    if reason == "FCS" then
      local temp = root.assetJson("/objects/ship/techstation/techstation.object")
      if not temp.uniqueId then  --this is removed by Madtulip's FCS mod, so that's how I know
        for _, i in ipairs(group) do
          world.spawnItem(i, pos)
        end
      end
    else
      for _, i in ipairs(group) do
        world.spawnItem(i, pos)
      end
    end
  end
  sr_original_init(...)
end