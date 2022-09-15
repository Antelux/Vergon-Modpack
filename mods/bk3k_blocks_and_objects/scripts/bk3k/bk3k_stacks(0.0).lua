--ignore this for now.  Incomplete, implimentation not a settled matter.  Probably code failures throughout.



--The concept is one from assembly language.  I'm appliying it to add commands/tasks/whatever you want to call it.
--It could just as well be data handled in this way rather than commands.
--You don't deal with stacks by referencing elements.  You deal with them sequentially.
--The order you deal with them depends on the type.
--One could think of a stack of cards.  FIFO meaning you pull from the top, and LIFO meaning you pull from the bottom.
--All the same. new cards go on top.
--now because this isn't a literal stack, we can cheat a bit while maintaining the notion
  --peek, swap, 

require("/scripts/bk3k/bk3k_sugar(0.0).lua")

local stack = {}

local FIFO
  --first in, first out aka in order recieved
    --not the regular mode!  Perhaps you'd call this a "queue" instead of a "stack" but we'll offer it all the same.
local LIFO
  --last in, first out aka new on top, old on bottom
  
local push  --add to the top of the stack
local pop   --pull from the top of the stack
  --a strick stack would use only these 2 methods
  
local peek  --read from top, but leave on stack
local swap  --trade the top 2 on the stack
local rotateRight --puts the top of the stack on bottom
local rotateLeft  --puts the bottom of the stack on top
  --rotating is easy to accomplish in LUA thanks to the way LUA handles indexes

local overflow  --function call when the max stack size has been exceeded.



stack.mode = "LIFO"  --regular stack
stack.data = {}
stack.highIndex = 1  --highIndex doesn't hold a value!  That's where the next value would go.
stack.lowIndex = 1  --if lowIndex == highIndex, stack is empty!
  --note that indexes may go negative and that isn't a problem.  This will really only occur when rotation is used.
stack.maxSize = 65535  --That's just a placeholder value for now

stack.initialize = function(maxSize, mode)
  if type(maxSize) == "number"
  stack.mode
end

stack.size = function()
  return stack.highIndex - stack.lowIndex
  --note that it isn't 
end

