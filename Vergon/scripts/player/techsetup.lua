-----------------------------------------------------------------------

local TechList = {
	"airdash",
	"blinkdash",
	"sprint",
	"dash",
	"aquasphere",
	"distortionsphere",
	"sonicsphere",
	"spikesphere",
	"doublejump",
	"multijump",
	"rocketjump",
	"walljump"
}

-----------------------------------------------------------------------

function init()

	-- Give the player all techs.
	for i = 1, #TechList do

		player.makeTechAvailable(TechList[i])
		player.enableTech(TechList[i])

	end

	-- Equip the ones needed for later scripts.
	player.equipTech('sprint')
	player.equipTech('distortionsphere')
	player.equipTech('multijump')

	-- No need to update this script.
	script.setUpdateDelta(0)

	-- Inform player about tech changes.
	--Chat.addMessage("Successfully equipped techs.")

end

-----------------------------------------------------------------------