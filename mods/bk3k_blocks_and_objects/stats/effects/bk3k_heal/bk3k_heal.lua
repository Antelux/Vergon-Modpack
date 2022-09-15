--I made this edited version because effect.duration() returns nil when applied to NPCs

function init()
  animator.setParticleEmitterOffsetRegion("healing", mcontroller.boundBox())
  animator.setParticleEmitterEmissionRate("healing", config.getParameter("emissionRate", 3))
  animator.setParticleEmitterActive("healing", true)

  script.setUpdateDelta(5)
  local duration = effect.duration() or config.getParameter("defaultDuration", 1)
  self.healingRate = config.getParameter("healAmount", 30) / duration
end

function update(dt)
  status.modifyResource("health", self.healingRate * dt)
end

function uninit()
  
end
