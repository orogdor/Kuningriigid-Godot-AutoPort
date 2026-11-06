extends RefCounted
## V80: fog of war uses the V79 save bitmap without expanding the save file.
## A single 220 x 165 texture controls both map renderers; no per-tile nodes.
const World=preload("res://scripts/world_gen_v06.gd")
const VIEW_RADIUS: int=4
const CAPITAL_RADIUS: int=3

static func _valid(scout: Dictionary,world: Dictionary) -> bool:
    return not world.is_empty() and not scout.is_empty() and \
        int(scout.get("seed",-1))==int(world.get("seed",-2)) and \
        int(scout.get("c",-1))>=0 and int(scout.get("r",-1))>=0 and \
        int(scout.get("c",-1))<World.COLS and int(scout.get("r",-1))<World.ROWS

static func signature(scout: Dictionary,world: Dictionary) -> String:
    if not _valid(scout,world):return "clear"
    # Include the actual bitmap so reloaded / rolled-back saves with the
    # same visit count never incorrectly reuse an older GPU fog texture.
    return "%d:%d:%d:%s" % [int(world.get("seed",-1)),
        int(scout["c"]),int(scout["r"]),
        String(scout.get("explored_bits_v79",""))]

static func _reveal(mask: PackedByteArray,c: int,r: int,radius: int) -> void:
    for y in range(maxi(0,r-radius),mini(World.ROWS,r+radius+1)):
        for x in range(maxi(0,c-radius),mini(World.COLS,c+radius+1)):
            var dx: int=x-c
            var dy: int=y-r
            if dx*dx+dy*dy<=radius*radius:
                mask[y*World.COLS+x]=2

static func visibility(scout: Dictionary,world: Dictionary) -> PackedByteArray:
    var size: int=World.COLS*World.ROWS
    var mask:=PackedByteArray()
    mask.resize(size)
    if not _valid(scout,world):
        mask.fill(2) # No scout loaded yet: preserve the legacy map.
        return mask
    mask.fill(0)
    var visited: PackedByteArray=Marshalls.base64_to_raw(
        String(scout.get("explored_bits_v79","")))
    if visited.size()==int(ceili(float(size)/8.0)):
        for index in range(size):
            if (int(visited[int(index/8)]) & (1<<(index%8)))!=0:
                mask[index]=1
    var starts: Array=world.get("starts",[])
    if not starts.is_empty():
        var home: Dictionary=starts[0]
        _reveal(mask,int(home["c"]),int(home["r"]),CAPITAL_RADIUS)
    _reveal(mask,int(scout["c"]),int(scout["r"]),VIEW_RADIUS)
    return mask

static func visible_at(scout: Dictionary,world: Dictionary,c: int,r: int) -> bool:
    if not _valid(scout,world):return true
    if c<0 or c>=World.COLS or r<0 or r>=World.ROWS:return false
    var dx: int=c-int(scout["c"])
    var dy: int=r-int(scout["r"])
    if dx*dx+dy*dy<=VIEW_RADIUS*VIEW_RADIUS:return true
    var starts: Array=world.get("starts",[])
    if not starts.is_empty():
        dx=c-int(starts[0]["c"])
        dy=r-int(starts[0]["r"])
        if dx*dx+dy*dy<=CAPITAL_RADIUS*CAPITAL_RADIUS:return true
    return false

## V82 shared visibility policy: friendly units never vanish, enemies reveal only in sight.
static func unit_visible_v82(scout: Dictionary,world: Dictionary,army: Dictionary) -> bool:
    if int(army.get("team",0))==0:return true
    if bool(army.get("defeated",false)):return false
    return visible_at(scout,world,int(army.get("c",-1)),int(army.get("r",-1)))

static func atlas_image(scout: Dictionary,world: Dictionary) -> Image:
    var mask: PackedByteArray=visibility(scout,world)
    var image:=Image.create(World.COLS,World.ROWS,false,Image.FORMAT_RGBA8)
    for r in range(World.ROWS):
        for c in range(World.COLS):
            var state: int=int(mask[r*World.COLS+c])
            var shade: Color=Color(0.025,0.05,0.085,0.85)
            if state==1:shade=Color(0.025,0.04,0.07,0.27)
            elif state==2:shade=Color(0,0,0,0)
            image.set_pixel(c,r,shade)
    return image

static func terrain_image(scout: Dictionary,world: Dictionary) -> Image:
    var mask: PackedByteArray=visibility(scout,world)
    var image:=Image.create(World.COLS,World.ROWS,false,Image.FORMAT_RGBA8)
    for r in range(World.ROWS):
        for c in range(World.COLS):
            var state: int=int(mask[r*World.COLS+c])
            var shade: Color=Color(0.12,0.14,0.18,1.0)
            if state==1:shade=Color(0.65,0.66,0.68,1.0)
            elif state==2:shade=Color.WHITE
            image.set_pixel(c,r,shade)
    return image

## V83: UI tile inspection uses the saved V79 bitset without generating
## a 36K-cell image for each click.
static func visibility_at_v83(scout: Dictionary,world: Dictionary,c: int,r: int) -> int:
    if not _valid(scout,world):return 2
    if c<0 or c>=World.COLS or r<0 or r>=World.ROWS:return 0
    if visible_at(scout,world,c,r):return 2
    var index: int=r*World.COLS+c
    var visited: PackedByteArray=Marshalls.base64_to_raw(
        String(scout.get("explored_bits_v79","")))
    if visited.size()==int(ceili(float(World.COLS*World.ROWS)/8.0)) and \
            (int(visited[int(index/8)]) & (1<<(index%8)))!=0:
        return 1
    return 0
