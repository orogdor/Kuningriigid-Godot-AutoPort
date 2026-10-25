extends RefCounted
## 0.25 City world-tile districts. The capital tile is always implicitly owned.
## Extensions are attached only to passable adjacent world tiles.
## City resources remain pooled; physical inter-district 3D walking is future work.
const World=preload("res://scripts/world_gen_v06.gd")
const WOOD_COST: float=20.0
const STONE_COST: float=10.0
const POP_PER_EXTRA: int=6
const CARDINAL: Array[Vector2i]=[Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]

static func origin(world: Dictionary) -> Vector2i:
    var sites: Array=world.get("starts",[])
    if sites.is_empty():return Vector2i(-1,-1)
    return Vector2i(int(sites[0].get("c",-1)),int(sites[0].get("r",-1)))

static func key(position: Vector2i) -> String:
    return str(position.x)+":"+str(position.y)

static func cells(city: Dictionary, world: Dictionary) -> Array[Vector2i]:
    var all: Array[Vector2i]=[]
    var home: Vector2i=origin(world)
    if home.x<0:return all
    all.append(home)
    var districts: Dictionary=city.get("districts_v25",{})
    if int(districts.get("seed",-1))!=int(world.get("seed",-2)):return all
    var visited: Dictionary={key(home):true}
    for entry in districts.get("tiles",[]):
        if not entry is Dictionary:continue
        var p:=Vector2i(int(entry.get("c",-1)),int(entry.get("r",-1)))
        if visited.has(key(p)) or not _passable(world,p):continue
        visited[key(p)]=true
        all.append(p)
    return all

static func _passable(world: Dictionary, p: Vector2i) -> bool:
    var tile: Dictionary=World.cell(world,p.x,p.y)
    if tile.is_empty():return false
    return bool(tile.get("land",false)) and String(tile.get("biome","sea"))!="hills"

static func owns(city: Dictionary, world: Dictionary, c: int,r: int) -> bool:
    var position:=Vector2i(c,r)
    for p in cells(city,world):
        if p==position:return true
    return false

static func limit(city: Dictionary) -> int:
    var pop: int=0
    var realms: Array=city.get("realms",[])
    if not realms.is_empty():pop=int(realms[0].get("pop",0))
    return 1+maxi(0,pop/POP_PER_EXTRA)

static func _other_city(world: Dictionary,p: Vector2i) -> bool:
    var starts: Array=world.get("starts",[])
    for i in range(1,starts.size()):
        if int(starts[i].get("c",-1))==p.x and int(starts[i].get("r",-1))==p.y:
            return true
    return false

static func reason(city: Dictionary, world: Dictionary, c: int, r: int) -> String:
    var p:=Vector2i(c,r)
    if not _passable(world,p):return "Sellel ruudul on meri või läbimatu mägi"
    if owns(city,world,c,r):return "Ruut kuulub juba linnale"
    if _other_city(world,p):return "Teise riigi algusruutu ei saa liita"
    var owned: Array[Vector2i]=cells(city,world)
    var touches: bool=false
    for q in owned:
        if absi(q.x-p.x)+absi(q.y-p.y)==1:touches=true
    if not touches:return "Uus linnaosa peab piirnema linnaga küljepidi"
    if owned.size()>=limit(city):return "Elanike arv ei võimalda veel suuremat linna (iga 6 elanikku +1 ruut)"
    var realms: Array=city.get("realms",[])
    if realms.is_empty():return "Linna majandusandmed puuduvad"
    var stock: Dictionary=realms[0].get("resources",{})
    if float(stock.get("wood",0))<WOOD_COST or float(stock.get("stone",0))<STONE_COST:
        return "Linna laiendamiseks on vaja 20 puitu ja 10 kivi"
    return ""

static func expand(city: Dictionary,world: Dictionary,c: int,r: int) -> String:
    var error: String=reason(city,world,c,r)
    if error!="":return error
    var stock: Dictionary=city["realms"][0]["resources"]
    stock["wood"]=float(stock["wood"])-WOOD_COST
    stock["stone"]=float(stock["stone"])-STONE_COST
    var old: Dictionary=city.get("districts_v25",{})
    var entries: Array=[]
    if int(old.get("seed",-1))==int(world.get("seed",-2)):
        entries=old.get("tiles",[]).duplicate(true)
    entries.append({"c":c,"r":r})
    city["districts_v25"]={"seed":int(world.get("seed",0)),"tiles":entries}
    return ""

static func connections(city: Dictionary,world: Dictionary) -> Array:
    var owned: Array[Vector2i]=cells(city,world)
    var known: Dictionary={}
    for p in owned:known[key(p)]=true
    var result: Array=[]
    for p in owned:
        for q in [p+Vector2i(1,0),p+Vector2i(0,1)]:
            if known.has(key(q)):
                result.append({"from":{"c":p.x,"r":p.y},"to":{"c":q.x,"r":q.y}})
    return result
