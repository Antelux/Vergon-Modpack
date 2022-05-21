function uninit()

	storage.die = true;
end

function init()

	storage.die = false;
	
	script.setUpdateDelta(0);

	message.setHandler('destroy', function(messageType, isFromLocalEntity, lineToSay)
		
		sb.logInfo('DYING!!!!')
		entity.die();
	end)

end

function shouldDie()

	return storage.die;
end