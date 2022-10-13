--[[

enneade cahedron



Left Click -> Apply Brush
	+ Shift -> Use Dropper
Right Click -> Erase
	+ Shift -> Undo

Double Shift -> Change Layer




	Tools: (All are two-handed!)

		Brush: Paint the world to your liking.
			
			Brush Type:
				* Square
				* Circle
				* Diamond
				* Bucket
			
			Brush Size:
				* 1 - 10

		Area: Choose parts of the world to limit drawing in.

			* Double clicking on a block selects all blocks that are exactly the same.
			* Can cut/copy current area into palette, or save it.

		Measure: Set up nice rulers / protractors wherever.

		Stamp: Paste a palette exactly where you want it.
			
			* Rotatable
			* Scalable
			* Shearable
			* Flippable

		Gradient: Create fancy gradients across long stretches of blocks.
		Lightshift: Same as the above, except deals with lightness.

		Dropper: Copy just one tile exactly into the current palette.
	
	Tool Filter: Only apply tools to tiles that match these.
		- Has whitelist & blacklist


	Palette: NxN matrix of blocks to paint with
		Feed Type:
		* Random	<- Choose block randomly from input.
		* Pattern	<- Apply input as if it were wallpaper.
		* Noise		<- Choose block noisily from input.
		>> You can choose which parts of the palette to use, i.e. using it in the way brimm wanted.
		>> You can click on any tile within the palette to edit it specifically.

	Palette Filter: Only take these attributes from the filter.
		Material
		* Hueshift
		Mod
		* Hueshift
		Liquid
		* Amount
		Collision
		Paint
		-> Presets: Material Only, Mod Only, Liquid Only, etc...


	Nice example of it's power:
		
		Problem:
			- You see some paint pattern that your particularly like.
			  You want to copy it and apply it elsewhere, but only want the pattern, not the blocks.

		Solution:
			- Select the area that you like.
			- Copy the area into your palette.
			- Set the palette filter to only modify paint.
			- Now use the stamp tool.














	- Two-Handed Tools:
		* Area Select: Rectangle, Circle
			- Resizeable
			- Copyable -> Into Clipboard
			- Cutable
		* Paster
			
		
		* Measurer

	- Filter (Togglable, Applies to all tools)
		* Whitelist/Blacklist
		* By Material
		* By Liquid
		* By Matmod
		* By Layer

	- Default Tools:
		* Left: Pencil
		* Right: Eraser



						
							 GUI

	Left Click        Right Click
	X X X X X           X X X X X     <- Tool Icons, with tooltips to explain them.

	Tool Settings   Tool Settings
	<Pane>                 <Pane>

	Input                   Input
	- Material      ->        ...
		* Hueshift              ...
	- Matmod                  ...
		* Hueshift
	- Liquid
		* Amount
	- Collision
		* Type
	- Paint
		* Color

	Output                 Output
	- Brush
		* Square
		* Circle
		* Diamond
		* Fill
	- Size
		* 1 - 20

	Filter
		- Only apply THESE to blocks.
	Filter
		- Only apply THESE from tool.


		Undo    Clipboard     Redo
--]]


-----------------------------------------------------------------------

math.__painter = math.__painter or {
	size = 1;
	layer = 'foreground';
	leftTool = 'brush';
	rightTool = 'eraser';
	isOpen = false;
	feedMode = 'random';

	input = {
		tiles = {
			{
				{
					material = {
						name = 'brick'; -- string
						hueshift = nil; -- number
					};

					matmod = {
						name = nil;     -- string
						hueshift = nil; -- number
					};

					liquid = {
						name = nil;   -- string
						amount = nil; -- float
					};
					
					collision = nil; -- string
					paint = nil;     -- string
				}
			}
		};
	};

	areas = {};
}

math.__painter.input.tiles = {
	{
		{
			material = {
				name = 'brick'; -- string
				hueshift = nil; -- number
			};

			matmod = {
				name = nil;     -- string
				hueshift = nil; -- number
			};

			liquid = {
				name = nil;   -- string
				amount = nil; -- float
			};
			
			collision = nil; -- string
			paint = nil;     -- string
		},
		{
			material = {
				name = 'ice'; -- string
				hueshift = nil; -- number
			};

			matmod = {
				name = nil;     -- string
				hueshift = nil; -- number
			};

			liquid = {
				name = nil;   -- string
				amount = nil; -- float
			};
			
			collision = nil; -- string
			paint = nil;     -- string
		}
	},
	{
		{
			material = {
				name = 'rock03'; -- string
				hueshift = nil; -- number
			};

			matmod = {
				name = nil;     -- string
				hueshift = nil; -- number
			};

			liquid = {
				name = nil;   -- string
				amount = nil; -- float
			};
			
			collision = nil; -- string
			paint = nil;     -- string
		},
		{
			material = {
				name = 'slopedhullpanel'; -- string
				hueshift = nil; -- number
			};

			matmod = {
				name = nil;     -- string
				hueshift = nil; -- number
			};

			liquid = {
				name = nil;   -- string
				amount = nil; -- float
			};
			
			collision = nil; -- string
			paint = nil;     -- string
		}
	}
};


painter = {}

-----------------------------------------------------------------------

function painter:getToolInput()

	return math.__painter.input

end

-----------------------------------------------------------------------

function painter:getAreas()

	return math.__painter.areas

end

-----------------------------------------------------------------------

function painter:open()

	if not math.__painter.isOpen then

		player.interact('ScriptPane', '/interface/stmanipulator/stmanipulator.config')
		math.__painter.isOpen = true

	end

end

function painter:close()

	math.__painter.isOpen = false

end

-----------------------------------------------------------------------

function painter:setBrushSize(size)

	math.__painter.size = size

end

function painter:getBrushSize()

	return math.__painter.size

end

-----------------------------------------------------------------------

function painter:swapLayer()

	math.__painter.layer = (math.__painter.layer == 'foreground') and 'background' or 'foreground'

end

function painter:setLayer(layerName)

	math.__painter.layer = layerName:lower():find('fore') and 'foreground' or 'background'

end

function painter:getLayer()

	return math.__painter.layer

end

-----------------------------------------------------------------------

function painter:setLeftTool(toolName)

	math.__painter.leftTool = toolName

end

function painter:getLeftTool()

	return math.__painter.leftTool

end

-----------------------------------------------------------------------

function painter:setRightTool(toolName)

	math.__painter.rightTool = toolName

end

function painter:getRightTool()

	return math.__painter.rightTool

end

-----------------------------------------------------------------------

function painter:setFeedMode(modeName)

	math.__painter.feedMode = modeName

end

function painter:getFeedMode()

	return math.__painter.feedMode

end

-----------------------------------------------------------------------