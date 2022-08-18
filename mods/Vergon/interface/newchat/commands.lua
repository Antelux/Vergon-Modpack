-----------------------------------------------------------------------

require '/scripts/util/json.lua'

-----------------------------------------------------------------------

local Chat   = math.__chat

-- TODO: Steal more from https://starbounder.org/Commands

-----------------------------------------------------------------------

Chat.addCommand
(
	'whoami',

	'Display your character\'s name, UUID, and admin status.',

	function(Chat, args)

		local Player = math.__player

		Chat.clientMessage('You are "^blue;' .. world.entityName(Player.id()) .. '^reset;". You ' .. (Player.isAdmin() and '^green;are^reset;' or '^red;are not^reset;') .. ' an Admin. Your UUID is ^blue;' .. Player.uniqueId() .. '^reset;.')

	end
)

-----------------------------------------------------------------------

Chat.addCommand
(
	'whereami',

	'Displays your current location in celestial coordinates.',

	function(Chat, args)

		local Player = math.__player

		local WorldID = Player.worldId()
			:gsub(':(.-):', ':^lightblue;%1^reset;:')
			:gsub(':(.-)$', ':^lightblue;%1^reset;')
			:gsub('(.-):', '^lightmagenta;%1^reset;:', 1)

		Chat.clientMessage('Your current location is ' .. WorldID)

	end
)

-----------------------------------------------------------------------

Chat.addCommand
(
	'played',

	'Displays your total play time on your character.',

	function(Chat, args)

		local Player = math.__player

		local Lines = {}

		local function InsertTime(type, amount)

			if amount > 0 then

				local PrettyAmount = tostring(math.floor(amount))
					:reverse()
					:gsub('(%d%d%d)', '%1,')
					:reverse()

				table.insert(Lines, '^yellow;' .. PrettyAmount .. '^reset; ' .. type .. (amount > 1 and 's' or ''))

			end

		end

		local Playtime = Player.playTime()
		local Hours    = Playtime // 3600
		local Minutes  = (Playtime - (Hours * 3600)) // 60
		local Seconds  = (Playtime - (Hours * 3600) - (Minutes * 60)) // 1

		InsertTime('hour', Hours)
		InsertTime('minute', Minutes)
		InsertTime('second', Seconds)

		local Count = #Lines
		local Sentence =
			((Count == 1) and Lines[1]) or
			((Count == 2) and (Lines[1] .. ' and ' .. Lines[2])) or
			((Count == 3) and (Lines[1] .. ', ' .. Lines[2]  .. ', and ' .. Lines[3])) or
			'???'

		Chat.clientMessage('Total play time: ' .. Sentence .. '.')

	end
)

-----------------------------------------------------------------------
--[[
Chat.addCommand
(
	'suicide',

	'No, don\'t do it!! :(',

	function(args)

		

	end
)
--]]
-----------------------------------------------------------------------

Chat.addCommand
(
	'spawnitem (itemName: string) (count: uint?) (parameters: json?)',	

	'Spawn the specified item into your inventory. Count defaults to 1. If the item does not exist, it will spawn a perfectly generic item.',

	function(Chat, args)

		local Player = math.__player

		local ItemName = args[1]
		local Count = tonumber(args[2] or 1)
		local Parameters = {};

		if args[3] then

			Parameters = ''

			for i = 3, #args do

				Parameters = Parameters .. args[i] .. ' '

			end

			-- Remove trailing whitespace.
			Parameters = Parameters:sub(1, -2)
			-- Grab JSON string.
			sb.logInfo('|' .. Parameters .. '|')
			Parameters = Parameters:match("^'(.*)'$") or Parameters
			sb.logInfo('|' .. Parameters .. '|')
			-- Decode.
			Parameters = json.decode(Parameters) or {}

		end

		if type(ItemName) ~= 'string' then

			Chat.clientMessage('Parameter \'^cyan;itemName^reset;\' must be a valid ^lightred;string^reset;.')
			return

		elseif type(Count) ~= 'number' then

			Chat.clientMessage('Parameter \'^cyan;count^reset;\' must be a valid ^lightred;number^reset;.')
			return

		elseif Count <= 0 then

			Chat.clientMessage('Parameter \'^cyan;count^reset;\' must be ^lightred;greater than 0^reset;.')
			return

		elseif type(Parameters) ~= 'table' then

			Chat.clientMessage('Parameter \'^cyan;parameters^reset;\' must be a valid ^lightred;JSON^reset;.')
			return

		end

		Player.giveItem({
			name = ItemName,
			count = Count,
			parameters = Parameters
		})

		Chat.clientMessage('Spawned \'^yellow;' .. ItemName .. '^reset;\' x^yellow;' .. Count)

	end
)

-----------------------------------------------------------------------

Chat.addCommand
(
	'alias (name: string) (frequency: uint?)',

	'Creates or clears an alias for use in {radio} elements. Aliases are case insensitive.',

	function(Chat, args)

		local Alias = args[1] and args[1]:lower()
		local Frequency = tonumber(args[2])
		local Exists = Alias and (Chat.__aliases[Alias:upper()] ~= nil)

		if type(Alias) ~= 'string' then

			Chat.clientMessage('Parameter \'^cyan;name^reset;\' must be a valid ^lightred;string^reset;.')
			return

		elseif (args[2] or (not Exists)) and (type(Frequency) ~= 'number') then

			Chat.clientMessage('Parameter \'^cyan;frequency^reset;\' must be a valid ^lightred;number^reset;.')
			return

		elseif (args[2] or (not Exists)) and ((Frequency < 0) or (Frequency > 65535)) then

			Chat.clientMessage('Parameter \'^cyan;frequency^reset;\' must be ^lightred;between 0 and 65535^reset;.')
			return

		end

		if args[2] then

			Chat.clientMessage('Set alias \'^cyan;' .. Alias .. '^reset;\' to frequency ^cyan;' .. Frequency .. '^reset;.')
			Chat.__aliases[Alias:upper()] = Frequency;

		else

			Chat.clientMessage('Cleared alias \'^cyan;' .. Alias .. '^reset;\' (was frequency ^cyan;' .. tostring(Chat.__aliases[Alias:upper()]) .. '^reset;).')
			Chat.__aliases[Alias:upper()] = nil;

		end

	end
)

-----------------------------------------------------------------------

Chat.addCommand
(
	'aliases',

	'Lists all your aliases for use in {radio} elements.',

	function(Chat, args)

		local line = 'Aliases:'

		for Alias, Frequency in pairs(Chat.__aliases) do

			line = line .. '\n\'^cyan;' .. Alias .. '^reset;\' -> ^cyan;' .. Frequency .. '^reset;'
		end

		Chat.clientMessage(line)

	end
)

-----------------------------------------------------------------------
--[[
Chat.addCommand
(
	'',

	'',

	function(Chat, args)

		

	end
)
--]]
-----------------------------------------------------------------------