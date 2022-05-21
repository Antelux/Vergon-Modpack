function init()
	self.radius = config.getParameter("blockRadius") / 2
	self.altRadius = config.getParameter("altBlockRadius") / 2

	self.notifyTime = config.getParameter("notifyEntityTime")
	self.notifyTimer = 0
	self.notifyDamage = config.getParameter("tileDamage") / config.getParameter("fireTime") * self.notifyTime
	self.notifyQueryParams = {
		includedTypes = {"vehicle"},
		boundMode = "position"
	}
end

local showed = false

function update(dt, fireMode, shifting)
	if fireMode == "primary" then
		self.notifyTimer = math.max(0, self.notifyTimer - dt)
		if self.notifyTimer == 0 then
			self.notifyTimer = self.notifyTime
			notifyEntities(shifting)
		end
	else
		self.notifyTimer = 0
	end

	if not showed then
		sb.logInfo(math.random(100))--config.getParameter('fireTime'))
		item.setCount(math.random(100))

		showed = true
	end

end

function notifyEntities(shifting)
	local entities = world.entityQuery(fireableItem.ownerAimPosition(), shifting and self.altRadius or self.radius, self.notifyQueryParams)
	for _, entityId in ipairs(entities) do
		world.sendEntityMessage(entityId, "positionTileDamaged", self.notifyDamage)
	end
end
