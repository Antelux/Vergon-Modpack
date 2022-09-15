--efficient math for tables which you know to be 2d coordinates
--contact bk3k for any requested expansions or to report problems
--free to use reproduce/distribute/modify/etc, but rename to avoid conflict please
--yes that includes commercial use such as by Chuckelfish, in which case I'd appreciate a shout out

--the obvious is that coordinates are a table with two indexes, both of them numbers to represent [x, y]
--boxes are defined as a table containing 2 coordinate tables,
  --those coordinates should represent opposite corners of the box and therefore the outer-perimeter
  --because otherwise you have a line rather than a box

--the intent here is that this is easy to use, intuative, results in cleaner code,
  --and makes coding mistakes dealing with coordinates considerably more obvious thus easier to fix
--also this should be faster than some other more generalized ways of dealing with tables etc,
  --since we know exactly what to expect rather than tables of unknown size, content etc.  The code can be more specific.
  --but not difficult to write


--I think some of this probably should be split off for the reason that some parts are dealing with boxes etc
--instead of pure coordinates.  I happened that way thanks to being very similar code so it seemed natural to do.
--But the original intention is getting blurred. A final decision has not yet been made so for now everything stays
--but 'may' branch off at the next version.  You're always welcome to stick with the current version as it will have
--a different file name than new versions.

local version = 0.2
local add     --adds the [x, y] of two coordinates and returns the resulting coordinate
local sub     --subtracts the [x, y] of two coordinates and returns the resulting coordinate
local addX    --adds only the x coordinates from the 2nd argument to the first, the y coordinate will be from the 1st
local addY    --adds only the y coordinates from the 2nd argument to the first, the x coordinate will be from the 1st
local subX    --subtracts only the x coordinates from the 2nd argument to the first, the y coordinate will be from the 1st
local subY    --subtracts only the y coordinates from the 2nd argument to the first, the x coordinate will be from the 1st
local dist    --returns the distance between two points using the pythagorean theorem, result is a number
local xDist   --returns only the x distance between two points
local yDist   --returns only the y distance between two points
local size    --tells the size as defined by two opposing corners, equivalent to {xDist, yDist}
local mag     --tells the magnitude of an rectangle as defined by 2 opposing corner coordinates
local floor   --applies math.floor() to x and y of a coordinate table, returns the resulting coordinate
local match   --determines if two coordinate tables are identical, returns boolean
local matchAny--determines if any arguments match the first, takes variable amounts of arguments
local matchX  --determines if the x of two coordinates is the same, returns boolean
local matchY  --determines if the y of two coordinates is the same, returns boolean
local highX   --takes a table of coordinates, returns highest x value as a number
local highY   --takes a table of coordinates, returns highest y value as a number
local lowX    --takes a table of coordinates, returns lowest x value as a number
local lowY    --takes a table of coordinates, returns lowest y value as a number
local midPoint  --returns the halfway coordinate between two coodinates, this would be the center if opposite corners
local travel  --returns a table of two numbers that specifies the relative [x,y] number of spaces you'd need to travel
                --to reach coordinate 2 from coordinate 1
local xTravel --returns a number that specifies traveling along the x coodinate line
local yTravel --returns a number that specifies traveling along the y coodinate line
local cString --returns a string representation of a coordinate like "(12.25, 146)"
local tString --returns a string representation of a table of coordinate like "(12.25, 146), (22.9, 82.6), (12, 7)"
                --acceptes a table with any number of coordinates, but returns a single string either way
local coDirection   --returns a string with the direction of the second coordinate relative to the first "northwest" etc
local boxDirection  --returns a string with the direction of the second box relative to the first "south" etc
local boxCollision  --returns a boolean to indicate if the boxes collide
local boxCollisions --returns a boolean to indicate if any boxes collide with the first
                      --accepts variable number of boxes
                      --optional second return is table of numeric indexes for those boxes that collided with the 1st
                        --corresponds to the argument send order
                        --to use that, table.unpack() a table of boxes as an argument when sending
                        --and then you'll have the indexes of the colliding boxes to use
local boxNeighbor  --same as boxCollision, but returns if neighbor as defined by threshhold argument, if colliding
local boxNeighbors --same as boxCollisions, but returns if neighbor as defined by threshhold argument,
                     --table of neighbors, if collision, table of collisions
local coNeighbor   --tell if two sets of coordinates are neighbors as defined by [x,y] offset
                      --presumably the coordinates are centers of entities, with the offset being entity dimensions
                      --and the entities presumed the same size
                      --because if you know all that to be true, this is cheaper than box checks.
local coNeighbors   --same as coNeighor, but returns if any coordinates neighbor the first as defined by threshhold argument
                      --and optional table of argument indexes for neighbors
local outer         --internal function for now, returns highX, lowX, highY, lowY as numbers
local nRange        --internal function returns boolean to indicate if a number is within a range
                      --this will be available as an external function in another of my packages.
                      --that version also checks if arguments are numbers and this doesn't
local branch        --returns a table of 4 coordinates based off of a source coordinate and [x,y] offset
                      --the most common use would probably be a [1,1] offset for direct neighbors.
                      --but offset could be a object's size when wanting to find object neighbors at those locations
local encircle      --like branch, but includes diagonals and so returns a table of 8 coordinates n,ne,e,se,s,sw,w,nw
                      --returned table is ordered like a clock, starting at 12 aka north
local branchN       --when your branching is more literal, you don't want to consider your source as a destination too
local branchE       --while you COULD use table.remove, this is cheaper and this sort of call probably gets made often
local branchW       --and the difference can add up, so it is nice to have options
local branchS
local increase      --will apply the value of t2 towards t1 in a way that moves away from zero
                      --aka adding to positive values or subtracting from negative values
                      --for motion calculations where speeding up is intended
local increaseX
local increaseY


local reduce        --the oppose of increase.  t2 values will shoot towards zero, although if too large they will pass it
                      --for motion calculations where slowing is intended, although too much in t2 could overdo it.
local reduceX
local reduceY
local rect2Bound  --starbound uses an odd way to define rectangles.  {LL.x, LL.y, UR.x, UR.y}
                      --instead of { {x,y}, {x,y} } representing opposite corners
                      --so this function will translate to what Starbound expects and isn't picky about
                      --which opposing corners you select
local rectV2Bound   --same as rect2Bound but more efficient if you know(r) to be {{LL}{UR}} already
local bound2rect  --opposite of rect2bound.
                  --Translates starbound's wierd way of defining rectangles into normal rectangles aka
                    --a table containing 2 coordinates - each which represent opposing corners of a box
                    --Unlike the starbound rectangles, any opposing corners are valid and therefore this is easier to use.


add = function (t1, t2)
  return {(t1[1] + t2[1]), (t1[2] + t2[2])}
end

sub = function(t1, t2)
  return {(t1[1] - t2[1]), (t1[2] - t2[2])}
end

addX = function (t1, t2)
  return {(t1[1] + t2[1]), t1[2]}
end

subX = function(t1, t2)
  return {(t1[1] - t2[1]), t1[2]}
end

addY = function (t1, t2)
  return {t1[1], (t1[2] + t2[2])}
end

subY = function(t1, t2)
  return {t1[1], (t1[2] - t2[2])}
end

dist = function(t1, t2)
  return math.sqrt(((t1[1] - t2[1])^2) + ((t1[2] - t2[2])^2))
end

xDist = function(t1, t2)
  return math.abs(t1[1] - t2[1])
end

yDist = function(t1, t2)
  return math.abs(t1[2] - t2[2])
end

size = function(t1, t2)
  return {math.abs(t1[1] - t2[1]), math.abs(t1[2] - t2[2])}
end

mag = function(t1, t2)
  return math.sqrt(math.abs(t1[1] - t2[1])^2 + math.abs(t1[2] - t2[2])^2)
end

floor = function(t)
  return {math.floor(t[1]), math.floor(t[2])}
end

match = function(t1, t2)
  return (t1[1] == t2[1]) and (t1[2] == t2[2])
end

matchAny = function(...)
  local t = ...
  local f = t[1]
  local tSize = #... + 1
  local i = 2
  local matches = {}
  while i < tSize do
    if (t.i[1] == f[1]) and (t.i[2] == f[2]) then
      table.insert(matches, i)
    end
    i = i + 1
  end
  return (#matches > 0), matches
end

matchX = function(t1, t2)
  return (t1[1] == t2[1])
end

matchY = function(t1, t2)
  return (t1[2] == t2[2])
end

highX = function(coT)
  local s = coT[1]  --s = first set of coordinates in table coT
  local highest = s[1]
  for _, co in ipairs(coT) do
    if (co[1] > highest) then
      highest = co[1]
    end
  end
  return highest
end

highY = function(coT)
  local s = coT[1]
  local highest = s[2]
  for _, co in ipairs(coT) do
    if (co[2] > highest) then
      highest = co[2]
    end
  end
  return highest
end

lowX = function(coT)
  local s = coT[1]
  local lowest = s[1]
  for _, co in ipairs(coT) do
    if (co[1] < lowest) then
      lowest = co[1]
    end
  end
  return lowest
end

lowY = function(coT)
  local s = coT[1]
  local lowest = s[2]
  for _, co in ipairs(coT) do
    if (co[2] < lowest) then
      lowest = co[2]
    end
  end
  return lowest
end

midPoint = function(t1, t2)
  return {
    (t1[1] + t2[1]) / 2,
    (t1[2] + t2[2]) / 2
    }
end

travel = function(source, dest)
  return {(dest[1] - source[1]), (dest[2] - source[2])}
end

xTravel = function(source, dest)
  return dest[1] - source[1]
end

yTravel = function(source, dest)
  return dest[2] - source[2]
end

cString = function(t)
  return "(" .. tostring(t[1]) .. ", " .. tostring(t[2]) .. ")"
end

tString = function(coT)
  local toReturn = ""
  local s = #coT
  for t, c in ipairs(coT) do
    toReturn = toReturn .. "(" .. tostring(c[1]) .. ", " .. tostring(c[2]) .. ")"
    if (s ~= t) then
      toReturn = toReturn .. ", "
    end
  end
  return toReturn
end

coDirection = function(s, d) --(source, destination/relative object)
  local travelT = { d[1] - s[1], d[2] - s[2] }
  local outStr = ""

  if travelT[2] > 0 then
    outStr = "north"
  elseif travelT[2] < 0 then
    outStr = "south"
  else
    --no need
  end

  if travelT[1] > 0 then
    outStr = outStr .. "east"
  elseif travelT[1] < 0 then
    outStr = outStr .. "west"
  elseif not (#outStr == 5 ) then
    outStr = "collision"
  end

  return outStr, travelT --optional second return
end

boxDirection = function(b1, b2)
  return coDirection(midPoint(b1[1], b1[2]), midPoint(b2[1], b2[2]))
end

boxCollision = function(b1, b2)
  local poly = { highX = {}, highY = {}, lowX = {}, lowY = {} }

  poly.highX[1], poly.highY[1], poly.lowX[1], poly.lowY[1] = outer(b1)
  poly.highX[2], poly.highY[2], poly.lowX[2], poly.lowY[2] = outer(b2)

  --seeing if poly2's high and low are in range of poly 1's high and low
  if nRange(poly.highX[2], poly.highX[1], poly.lowX[1]) or nRange(poly.lowX[2], poly.highX[1], poly.lowX[1]) then
    --x overlaps, see if y overlaps too because if so we have a collision
    if nRange(poly.highY[2], poly.highY[1], poly.lowY[1]) or nRange(poly.lowY[2], poly.highY[1], poly.lowY[1]) then
      return true
    end
  end

  return false
end

boxCollisions = function(...)
  local poly = { highX = {}, highY = {}, lowX = {}, lowY = {} }
  local collisions = {}

  for k, v in ipairs(...) do
    poly.highX[k], poly.highY[k], poly.lowX[k], poly.lowY[k] = outer(v)
    poly.highX[k], poly.highY[k], poly.lowX[k], poly.lowY[k] = outer(v)
  end

  local nArgs = #... + 1 --offset + 1 so I can use < instead of <= which I bet is cheaper
  local i = 2  --I don't want to compare the first argument against itself
  while i < nArgs do
    if ( nRange(poly.highX[i], poly.highX[1], poly.lowX[1]) or nRange(poly.lowX[i], poly.highX[1], poly.lowX[1]) ) and
      ( nRange(poly.highY[i], poly.highY[1], poly.lowY[1]) or nRange(poly.lowY[i], poly.highY[1], poly.lowY[1]) )
    then
      table.insert(collisions, i)
    end
    i = i + 1
  end

  return (#collisions > 0), collisions
end

boxNeighbor = function(b1, b2, thr)
  local poly = { highX = {}, highY = {}, lowX = {}, lowY = {} }

  poly.highX[1], poly.highY[1], poly.lowX[1], poly.lowY[1] = outer(b1)
  poly.highX[2], poly.highY[2], poly.lowX[2], poly.lowY[2] = outer(b2)

  poly.highX[0], poly.highY[0], poly.lowX[0], poly.lowY[0] = poly.highX[1] + thr, poly.highY[1] + thr, poly.lowX[1] + thr, poly.lowY[1] + thr

  local neighbor = false
  local collision = false

  --seeing if poly2's high and low are in range of poly 1's high and low
  if ( nRange(poly.highX[2], poly.highX[0], poly.lowX[0]) or nRange(poly.lowX[2], poly.highX[0], poly.lowX[0]) ) and
    ( nRange(poly.highY[2], poly.highY[0], poly.lowY[0]) or nRange(poly.lowY[2], poly.highY[0], poly.lowY[0]) ) then
      neighbor = true
  elseif
    ( nRange(poly.highX[2], poly.highX[1], poly.lowX[1]) or nRange(poly.lowX[2], poly.highX[1], poly.lowX[1]) ) and
    ( nRange(poly.highY[2], poly.highY[1], poly.lowY[1]) or nRange(poly.lowY[2], poly.highY[1], poly.lowY[1]) ) then
      collision = true
  end
  return neighbor, collision
end

boxNeighbors = function(...)
  local poly = { highX = {}, highY = {}, lowX = {}, lowY = {} }
  local collisions = {}
  local neighbors = {}

  for k, v in ipairs(...) do
    poly.highX[k], poly.highY[k], poly.lowX[k], poly.lowY[k] = outer(v)
    poly.highX[k], poly.highY[k], poly.lowX[k], poly.lowY[k] = outer(v)
  end

  poly.highX[0], poly.highY[0], poly.lowX[0], poly.lowY[0] = poly.highX[1] + thr, poly.highY[1] + thr, poly.lowX[1] - thr, poly.lowY[1] - thr

  local nArgs = #... + 1 --offset + 1 so I can use < instead of <= which I bet is cheaper
  local i = 2  --I don't want to compare the first argument against itself
  while i < nArgs do
    if ( nRange(poly.highX[i], poly.highX[0], poly.lowX[0]) or nRange(poly.lowX[i], poly.highX[0], poly.lowX[0]) ) and
      ( nRange(poly.highY[i], poly.highY[0], poly.lowY[0]) or nRange(poly.lowY[i], poly.highY[0], poly.lowY[0]) )
    then
      table.insert(neighbors, i)
    elseif
      ( nRange(poly.highX[i], poly.highX[1], poly.lowX[1]) or nRange(poly.lowX[i], poly.highX[1], poly.lowX[1]) ) and
      ( nRange(poly.highY[i], poly.highY[1], poly.lowY[1]) or nRange(poly.lowY[i], poly.highY[1], poly.lowY[1]) )
    then
      table.insert(collisions, i)
    end
    i = i + 1
  end

  return (#neighbors > 0), neighbors, (#collisions > 0), collisions
end

outer = function (c1, c2)
  local highX
  local highY
  local lowX
  local lowY

  if c1[1] < c2[1] then
    highX, lowX = c2[1], c1[1]
  else
    highX, lowX = c1[1], c2[1]
  end

  if c1[2] < c2[2] then
    highY, lowY = c2[2], c1[2]
  else
    highY, lowY = c1[2], c2[2]
  end

  return highX, highY, lowX, lowY
end

nRange = function(num, n1, n2)
  return (num == n1) or (num == n2) or (num > n1 and num < n2) or (num < n1 and num > n2)
end

coNeighbor = function(c1, c2, cThr)
  return matchAny( c2, branch(c1, cThr) )  --completely disregarding the second return from matchAny
end

coNeighbors = function(...)
  local t = ...
  local tSize = #t --last argument is the cThr but +1 offset to use < instead of <= so those cancel each other out
  local neighbors = {}
  local checks = branch(t[1], t[tSize]) --t[#t] will pull the last argument, which should be the checking offset
  local i = 2

  while i < tSize do
    if matchAny(t[i], table.unpack(checks)) then  --completely disregarding the second return
      table.insert(neighbors, i)
    end
    i = i + 1
  end

  return (#neighbors > 0), neighbors
end

branch = function(t1, t2)
  return {
      { t1[1], t1[2] + t2[2] },           --to the north of t1
      { t1[1] + t2[1], t1[2] },           --to the east of t1
      { t1[1], t1[2] - t2[2] },           --to the south of t1
      { t1[1] - t2[1], t1[2] }            --to the west of t1
    }
end

encircle = function(t1, t2)
  return {
      { t1[1], t1[2] + t2[2] },           --to the north of t1
      { t1[1] + t2[1], t1[1] + t2[2] },   --to the northeast of t1
      { t1[1] + t2[1], t1[2] },           --to the east of t1
      { t1[1] + t2[1], t1[1] - t2[2] },   --to the southeast of t1
      { t1[1], t1[2] - t2[2] },           --to the south of t1
      { t1[1] - t2[1], t1[1] - t2[2] },   --to the southwest of t1
      { t1[1] - t2[1], t1[2] },           --to the west of t1
      { t1[1] - t2[1], t1[1] + t2[2] }    --to the northwest of t1
    }
end

branchN = function(t1, t2)
  return {
      { t1[1], t1[2] + t2[2] },           --to the north of t1
      { t1[1] + t2[1], t1[2] },           --to the east of t1
      { t1[1] - t2[1], t1[2] }            --to the west of t1
    }
end

branchS = function(t1, t2)
  return {
      { t1[1] + t2[1], t1[2] },           --to the east of t1
      { t1[1], t1[2] - t2[2] },           --to the south of t1
      { t1[1] - t2[1], t1[2] }            --to the west of t1
    }
end

branchE = function(t1, t2)
  return {
      { t1[1], t1[2] + t2[2] },           --to the north of t1
      { t1[1] + t2[1], t1[2] },           --to the east of t1
      { t1[1], t1[2] - t2[2] },           --to the south of t1
    }
end

branchW = function(t1, t2)
  return {
      { t1[1], t1[2] + t2[2] },           --to the north of t1
      { t1[1], t1[2] - t2[2] },           --to the south of t1
      { t1[1] - t2[1], t1[2] }            --to the west of t1
    }
end

increase = function(t1, t2)
  if t1[1] > 0 then
    if t1[2] > 0 then
      return {t1[1] + t2[1], t1[2] + t2[2]}
    else
      return {t1[1] + t2[1], t1[2] - t2[2]}
    end
  elseif t1[2] > 0 then
    return {t1[1] - t2[1], t1[2] + t2[2]}
  else
    return {t1[1] - t2[1], t1[2] - t2[2]}
  end
end

increaseX = function(t1, t2)
  if t1[1] > 0 then
    return {t1[1] + t2[1], t1[2]}
  else
    return {t1[1] - t2[1], t1[2]}
  end
end


increaseY = function(t1, t2)
  if t1[2] > 0 then
    return {t1[1], t1[2] + t2[2]}
  else
    return {t1[1], t1[2] - t2[2]}
  end
end


reduce = function(t1, t2)
  if t1[1] > 0 then
    if t1[2] > 0 then
      return {t1[1] - t2[1], t1[2] - t2[2]}
    else
      return {t1[1] - t2[1], t1[2] + t2[2]}
    end
  elseif t1[2] > 0 then
    return {t1[1] + t2[1], t1[2] - t2[2]}
  else
    return {t1[1] + t2[1], t1[2] + t2[2]}
  end
end


rect2Bound = function(r)                            --r should be a structure like{{x,y}, {x,y}}
                                                      --so just do rect2Bound({c1, c2})
  local highX
  local highY
  local lowX
  local lowY
  highX, highY, lowX, lowY = outer(r[1], r[2])
  return {lowX, lowY, highX, highY}


--  if r[2][2] > r[1][2] then                         --check y
--    if r[2][1] > r[1][1] then                       --t2[y] > t1[y], check [x]
--      return {r[1][1], r[1][2], r[2][1], r[2][2]}   --was already sent as LL, UR as starbound expects
--    else
--      return {r[2][1], r[1][2], r[1][1], r[2][2]}   --was sent as LR, UL, translated to LL, UR
--    end
--  else                                               --t2[y] < t2[y], check [x]
--    if r[2][1] > r[1][1] then
--      return {r[1][1], r[2][2], r[2][1], r[1][2]}
--    else
--      return {r[2][1], r[2][2], r[1][1], r[1][2]}
--    end
--  end
end

rectV2Bound = function(r)
  return {r[1][1], r[1][2], r[2][1], r[2][2]}
end


bound2rect = function(b)
return {{b1, b2}, {b3, b4}}
end





--if bk3kcMath2d and bk3kcMath2d.version > version then
  --using my handle makes for a name unlikely to already exist in _ENV
_ENV["bk3kcMath2d"..tostring(version)] = {
  add = add,
  sub = sub,
  addX = addX,
  subX = subX,
  addY = addY,
  subY = subY,
  xDist = xDist,
  yDist = yDist,
  size = size,
  mag = mag,
  floor = floor,
  match = match,
  matchAny = matchAny,
  matchX = matchX,
  matchY = matchY,
  highX = highX,
  highY = highY,
  lowX = lowX,
  lowY = lowY,
  midPoint = midPoint,
  travel = travel,
  xTravel = xTravel,
  yTravel = yTravel,
  cString = cString,
  tString = tString,
  coDirection = coDirection,
  boxDirection = boxDirection,
  boxCollision = boxCollision,
  boxCollisions = boxCollisions,
  boxNeighbor = boxNeighbor,
  boxNeighbors = boxNeighbors,
  coNeighbor = coNeighbor,
  coNeighbors = coNeighbors,
  branch = branch,
  branchN = branchN,
  branchS = branchS,
  branchW = branchW,
  branchE = branchE,
  encircle = encircle,
  increase = increase,
  increaseX = increaseX,
  increaseY = increaseY,
  reduce = reduce,
  reduceX = reduceX,
  reduceY = reduceY,
  rect2Bound = rect2Bound,
  rectV2Bound = rectV2Bound,
  bound2rect = bound2rect
  }

return _ENV["bk3kcMath2d" .. tostring(version)]