--ignore this for now.  Incomplete, implimentation not a settled matter.  Probably code failures throughout.

require("/scripts/bk3k/bk3k_stacks(0.0).lua")

--sbo package--

local request_data
  --this is for requesting data in a more standardarized fashion using standardized data type/structures
local send_data
  --this is for sending data in a more standardized fashion using standardized data type/structures
local recieve_data
  --this is for recieving data in a more standardized fashion using standardized data type/structures
  --these will replace the idea of getting data strictly from function returns
    --for one thing that allows asychronous transfer
  
local request_rawData
  --requrest data in a way that requires you to know the local implimentation
  --faster, less versitile, and more prone to breaking when code changes on either end
local send_rawData
  --send data in a way that requires you to know the local implimentation
  --faster, less versitile, and more prone to breaking when code changes on either end
local recieve_rawData

local call_localFunction
  --requires you to know local implimentation
  
local request_commands
  --ask a recieving object to do something, such as change states, modes etc.
  
local recieve_commands
  --command recieved from other object
  
local notify_commandRefused
local notify_commandAccepted
  --only when indicated that a confirmation was requested
local notify_commandsInvalid
  --the recieved command was either improperly formated, or not supported by the local object
local notify_commandsSupported
  --this would include commands currently disabled
local notify_commandsAvailable
  --this would only include commands both supported and currently not disabled

local request_ENV  --not sure about this yet
