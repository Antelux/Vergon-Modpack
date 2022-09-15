--ignore this for now.  Incomplete, implimentation not a settled matter.  Probably code failures throughout.


function getData(dataType)
  if whatData == "Automatic" then
    return not storage.noAuto
  elseif whatData == "scanTargets" then
    return storage.scanTargets
  elseif whatData == "NPCuse" then
    return not storage.noNPCuse
  elseif whatData == "interactive" then
    return storage.defaultInteractive and not (storage.wireControlled or storage.defaultLocked or storage.locked)
  elseif whatData == "Boundry" then
    return {storage.corners.upperLeft, storage.corners.lowerRight}
  elseif whatData == "realSpaces" then
    return storage.realSpaces
  else
    return nil
  end

end


function requestData(dataType, senderID, requestUUID)
  local data = getData(dataType)
  sendData(senderID, dataType, data, requestUUID)
end


function sendData(recieverID, dataType, data, requestUUID)
  
  if requestUUID then
    world.sendEntityMessage(recieverID, "recieveData", dataType, data, storage.ID, requestUUID)
    --recipient, string that identifies the data, the data itself, who am I, requestUUID
  else
    world.sendEntityMessage(recieverID, "recieveData", dataType, data, storage.ID)
  end
end


function recieveData(mData)
  if (type(rData) ~= "table") or (type(rData.dataType) ~= "string")then 
    return
  end
  local dataType = mData.dataType
  local requestAck = mData.requestAck or false
  local senderID = mData.senderID or false
  local requestUUID = mData.requestUUID or false
  local data = mData.data
  
  if dataType == "command" then
  
  elseif dataType == "setMode" then
    setMode(mData.whatMode, mData.modeArgs, requestAck, senderID, requestUUID)
  elseif dataType == "requestData" then
    local reqData = getData(mData.reqDataType)
    sendData(senderID, mData.reqDataType, reqData, requestUUID)
  end

end


function setMode(whatMode, whatArgs, requestAck, senderID, requestUUID)
  local accepted = true
  
  if whatArgs == nil then 
    accepted = false
  elseif whatMode == "Automatic" then
    storage.noAuto = not whatArgs
  elseif whatMode == "scanTargets" then
    storage.scanTargets = whatArgs
  elseif whatMode == "NPCuse" then
    storage.noNPCuse = not whatArgs
  elseif whatMode == "interactive" then
    storage.defaultInteractive = whatArgs
    updateInteractive()
  else
    accepted = false
  end
  
  if requestAck then
    sendData(senderID, "acknowledgement", accepted, requestUUID)
  end
end