--ignore this for now.  Incomplete, implimentation not a settled matter.  Probably code failures throughout.



--easy use functions that can take multiple variables--
  --yes I'm aware that I'm "reinventing the wheel" with some of this 
  --but I like it my way!  I think some of my implimentation is nicer to use.
local version = 0.0
  
  
local alphaT = {
  "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
  "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
  }
  
local hexT = {
  "0" = 0, "1" = 1, "2" = 2, "3" = 3, "4" = 4,
  "5" = 5, "6" = 6, "7" = 7, "8" = 8, "9" = 9
  A = 10, B = 11, C = 12, D = 13, E = 14, F = 15
  }
  
  
--accepts any number of variables
--they'll return false if ANY one of them doesn't meet the condition

local isNumA    --number is true if integer or float
local isStrA    --string
local isFunA    --function
local isTabA    --table
local isNilA    --nil
local isIntA    --is a number AND an integer rather than float
local isFloA    --is a number AND a float rather than integer
                  --granted that would be rare to require floats such that integers won't work in LUA
                  --but all the same, here you are
                  
                  
--These will return a table containing the INDIVIDUAL boolean values for every argument sent
--so basically a batch function rather than massive AND statement
local isNumT
local isStrT
local isFunT
local isTabT
local isNilT
local isIntT
local isFloT


--single variable only for slightly cheaper calls and easy use
local isNum   
local isStr   
local isFun   
local isTab   
local isNil   
local isInt
local isFlo


--various
local revTab  --sends the table in reverse order, assumes numberic indexes
local nRange  --returns true or false depending if a var1 lies between var2 and var3
                  --it isn't particularly important if var2 is greater than var3 or not

--binary output from boolean
local binBool   --recieve either a 1 or 0 instead of true or false
local boolBin   --modfied implimentation LUA's boolean handling where in 0 becomes false
                  --otherwise identical to LUA's handling
local bin       --binary return
                  --if sent a number, return the binary representation
                  --otherwise evaluate the variable as boolean and return 1 or 0
local num2bin   --does the legwork of conversion, probably not directly exposed
local num2hex
local hex2num
local bin2num

local half      --/2 isn't useful as a function, but returning {whatVar /2, remainder} makes nice code
local divR      --same as half but define the divisor
local divHex    -- {whatVar / 16, remainder} with types of {string-hex, integer}
local num2hexDigit  --single digit hex return where the argument shouldn't be > 15
local hex2numDigit

local withoutIndexes  --similar in purpose to table.remove but accepts multiple indexes similtaniously,
                        --obviously returns a table identical to the first argument except for the removed indexes
                        --and is hopefully faster for mass table index removal
local matchAny

local appendTable
local appendList
                
isNumA = function(...)
  for _, v in ipairs(...) do
    if (type(v) ~= "number") then
      return false
    end
  end
  return true
end


isStrA = function(...)
  for _, v in ipairs(...) do
    if (type(v) ~= "string") then
      return false
    end
  end
  return true
end


isFunA = function(...)
  for _, v in ipairs(...) do
    if (type(v) ~= "function") then
      return false
    end
  end
  return true
end


isTabA = function(...)
  for _, v in ipairs(...) do
    if (type(v) ~= "table") then
      return false
    end
  end
  return true
end


isNilA = function(...)
  for _, v in ipairs(...) do
    if (v ~= nil) then
      return false
    end
  end
  return true
end


isIntA = function(...)
  for _, v in ipairs(...) do
    if not isNum(v) then
      return false
    elseif ( v ~= math.floor(v) ) then
      return false
    end
  end
  return true
end


isFloA = function(...)
  for _, v in ipairs(...) do
    if not isNum(v) then
      return false
    elseif ( v == math.floor(v) ) then  --this line should not be called if not a number
      return false
    end
  end
  return true
end


isNumT = function(...)
  local rTable = {}
  for k, v in ipairs(...) do
    rTable[k] = (type(v) == "number")
  end
  return rTable
end


isStrT = function(...)
  local rTable = {}
  for k, v in ipairs(...) do
    rTable[k] = (type(v) == "string")
  end
  return rTable
end


isFunT = function(...)
  local rTable = {}
  for k, v in ipairs(...) do
    rTable[k] = (type(v) == "function")
  end
  return rTable
end


isTabT = function(...)
  local rTable = {}
  for k, v in ipairs(...) do
    rTable[k] = (type(v) == "table")
  end
  return rTable
end


isNilT = function(...)
  local rTable = {}
  for k, v in ipairs(...) do
    rTable[k] = (v == nil)
  end
  return rTable
end


isIntT = function(...)
  local rTable = {}
  for k, v in ipairs(...) do
    rTable[k] = isInt(v)
  end
  return rTable
end


isFloT = function(...)
  local rTable = {}
  for k, v in ipairs(...) do
    rTable[k] = isFlo(v)
  end
  return rTable
end


isNum = function(whatVar)
  return (type(whatVar) == "number")
end


isStr = function(whatVar)
  return (type(whatVar) == "string")
end


isFun = function(whatVar)
  return (type(whatVar) == "function")
end


isTab = function(whatVar)
  return (type(whatVar) == "table")
end


isNil = function(whatVar)
  return (whatVar == nil)
end


isInt = function(whatVar)
  --I was going to skip the number check for lower cost
  --but sending math.floor anything but a number could crash the script
  --and that's just not acceptable for a checking function like this!
  if (type(whatVar) == "number") then
    return (whatVar == math.floor(whatVar))
  end
  return false
end


isFlo = function(whatVar)
  if (type(whatVar) == "number") then
    return (whatVar ~= math.floor(whatVar))
  end
  return false
end


binBool = function(whatVar)
  if whatvar then
    return 1
  else
    return 0
  end
end


boolBin = function(whatVar)
  if whatVar then
    return (whatVar ~= 0)
  else
    return false
  end
end


bin = function(whatVar)
  if whatVar then
    if isInt(whatVar) then
      if nRange(whatVar, 0, 1) then
        return whatVar
      elseif (whatVar > 1) then 
        return num2bin(whatVar)
      else
        sb.logError("function \"bin\" recieved negative integer!, returned 0")
        return 0
      end
    else  --boolean true, but not an integer
      return 1
    end
  else --boolean false
    return 0
  end
end


num2bin = function (whatN)
  local bTable = {}
  local tempNum = whatN
  local i = 1
  
  while tempNum > 0 do
    tempNum, bTable[i] = half(tempNum)
    i = i + 1
  end
  
  bTable = revTab(bTable)
  return table.concat(bTable) --may change my mind on this
end


num2hex = function(whatN)
  local hTable = {}
  local tempNum = whatN
  local i = 1
  
  while tempNum > 0 do
    tempNum, hTablep[i] = divHex(tempNum)
    i = i + 1
  end
  
  hTable = revTab(hTable)
  return table.concat(hTable)
end

 
nRange = function(num, n1, n2)
  if not isNumA(num, n1, n2) then
    return false
  end
     
  return (num == n1) or (num == n2) or (num > n1 and num < n2) or (num < n1 and num > n2)
end


half = function(whatN)
  return {math.floor(whatN / 2), math.modf(whatN / 2)}
end


divR = function(whatN, whatDiv)
  return {math.floor(whatN / whatDiv), math.modf(whatN / whatDiv)}
end


divHex = function(whatN)
  local hexN = num2hexDigit(math.floor(whatN / 16))
  return {hexN, math.modf(whatN / 16)}
end


num2hexDigit - function(whatN)
  if nRange(whatN, 0, 9) then
    return tostring(whatN)
  else
    return alphaT[whatN - 9]
  end
end


hex2num = function(whatHex)
  

end



bin2num = function(whatBin)


end


hex2numDigit - function(whatHex)
  
  
end



revTab = function(sourceTable)
  local rTable = {}
  local rI = 1 --return table index
  local sI = #sourceTable --source table index starts at end
  
  while (sI > 0) do
    rTable[rI] = sourceTable[sI]
    sI = sI - 1
    rI = rI + 1
  end
  
  return rTable
end


withoutIndexes = function(t, ...)
  local culledIndexes = ...
  local retTable
  local i = 1
  for k, v in ipairs(t)
    if not matchAny(k, culledIndexes) then
      retTable[i] = v
      i = i + 1
    end
  end
  return retTable
  
end


matchAny = function(value, matches)
  for k,v in ipairs(matches)
    if v == value then
      return true
    end
  end
  return false
end

math.fRandom = function(fMin, fMax, precision)
  --precision should be 10, 100, 1000, etc with a zero for every digit you want in precision
  --if not utilized, default to 100
  precision = precision or 100
  --this returns a random float number between min and max
  --with the exception that the arguments with be effectively reduced to 2 digits of precision.
  
  return math.random( math.floor(fMin * precision), math.floor(fMax * precision) ) / precision
end


appendTable = function(mainT, addonT, nestAppend)
  --this will not over-write any values from addonT that do exist in mainT
  --it will append any nested tables if nestAppend is set.
  for k, v in pairs(addonT) do
    if (maintT[k] == nil) then
      mainT[k] = addonT[k]
    elseif nestAppend and isTab(mainT[k]) and isTab(addonT[k]) then
      appendTable(mainT[k], addonT, true)
    end
  end
  return mainT
end

appendList = function(mainL, addonL)
  --this will not over-write any values from addonT that do exist in mainT
  local offset = #mainT
  for k, v in ipairs(addonL) do
    mainL[k + offset] = addonL[k]
  end
  return mainL
end

vSort = function(t, key, priority) -- sort a table
  --unfinished
  priority = priority or {"n", "a"}
  
end


_ENV["bk3kUtil" .. tostring(version)] = {
  alphaT = alphaT,
  hexT = hexT,
  isNumA = isNumA,
  isStrA = isStrA,
  isFunA = isFunA,
  isTabA = isTabA,
  isNilA = isNilA,
  isIntA = isIntA,
  isFloA = isFloA,
  isNumT = isNumT,
  isStrT = isStrT,
  isFunT = isFunT,
  isTabT = isTabT,
  isNilT = isNilT,
  isIntT = isIntT,
  isFloT = isFloT,
  isNum = isNum,
  isStr = isStr,
  isFun = isFun,
  isTab = isTab,
  isNil = isNil,
  isInt = isInt,
  isFlo = isFlo,
  revTab = revTab,
  nRange = nRange,
  binBool = binBool,
  boolBin = boolBin,
  bin = bin,
  num2bin = num2bin,
  num2hex = num2hex,
  hex2num = hex2num,
  bin2num = bin2num,
  half = half,
  divR = divR,
  divHex = divHex,
  num2hexDigit = num2hexDigit,
  hex2numDigit = hex2numDigit,
  withoutIndexes = withoutIndexes,
  matchAny = matchAny,
  appendList = appendList,
  appendTable = appendTable
  }

return _ENV["bk3kUtil" .. tostring(version)]