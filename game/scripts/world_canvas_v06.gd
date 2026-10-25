extends Control
## Fast world map raster: persistent 220x165 atlas + rivers/cities as overlays.
signal cell_selected(c: int, r: int)
const World = preload("res://scripts/world_gen_v06.gd")
var world: Dictionary = {}
var atlas: ImageTexture
var zoom: float = 3.0
var pan: Vector2 = Vector2.ZERO
var chosen: Vector2i = Vector2i(-1,-1)
var drag_start: Vector2 = Vector2.ZERO
var last_pointer: Vector2 = Vector2.ZERO
var dragging: bool = false
var movement: float = 0.0
var initialized_view: bool = false
var trade_route: Dictionary={}
var trade_caravans: Array=[]

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    resized.connect(_on_resized)

func set_world(next: Dictionary) -> void:
    world=next
    var cells: Array=world.get("cells",[])
    if cells.is_empty():return
    var image:=Image.create(World.COLS,World.ROWS,false,Image.FORMAT_RGBA8)
    for r in range(World.ROWS):
        for c in range(World.COLS):
            var p: Dictionary=cells[r*World.COLS+c]
            var biome: String=String(p["biome"])
            var color: Color=Color("#20567b")
            if biome=="plains":
                color=Color("#a1b46b")
            elif biome=="forest":
                color=Color("#43845b")
            elif biome=="hills":
                color=Color("#a6a49a")
            elif float(p["h"]) < -12.0:
                color=Color("#17415f")
            if bool(p["land"]):
                var coast: bool=false
                for delta in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
                    var x: int=c+delta.x
                    var y: int=r+delta.y
                    if x>=0 and y>=0 and x<World.COLS and y<World.ROWS and not bool(cells[y*World.COLS+x]["land"]):
                        coast=true
                if coast and biome!="hills":color=Color("#e1c78c")
            image.set_pixel(c,r,color)
    atlas=ImageTexture.create_from_image(image)
    initialized_view=false
    call_deferred("fit_to_view")

func set_trade_route(route: Dictionary, moving: Array) -> void:
    trade_route=route.duplicate(true)
    trade_caravans=moving.duplicate(true)
    queue_redraw()

func fit_to_view() -> void:
    if size.x<=10 or size.y<=10:return
    zoom=maxf(1.0,minf(size.x/World.COLS,size.y/World.ROWS)*0.94)
    pan=(size-Vector2(World.COLS,World.ROWS)*zoom)*0.5
    initialized_view=true
    queue_redraw()

func _on_resized() -> void:
    if not initialized_view and not world.is_empty():
        fit_to_view()
    else:
        queue_redraw()

func point(c: float, r: float) -> Vector2:
    return pan+Vector2(c,r)*zoom

func tile_at(local_point: Vector2) -> Vector2i:
    if zoom<=0.0:return Vector2i(-1,-1)
    var p: Vector2=(local_point-pan)/zoom
    return Vector2i(int(floor(p.x)),int(floor(p.y)))

func select_cell(c: int, r: int) -> void:
    if c<0 or r<0 or c>=World.COLS or r>=World.ROWS:return
    chosen=Vector2i(c,r)
    queue_redraw()
    cell_selected.emit(c,r)

func _draw() -> void:
    if atlas==null:return
    var destination:=Rect2(pan,Vector2(World.COLS,World.ROWS)*zoom)
    draw_texture_rect(atlas,destination,false)
    if zoom>=9.0:
        var c0: int=maxi(0,int(floor(-pan.x/zoom)))
        var c1: int=mini(World.COLS,int(ceil((size.x-pan.x)/zoom)))
        var r0: int=maxi(0,int(floor(-pan.y/zoom)))
        var r1: int=mini(World.ROWS,int(ceil((size.y-pan.y)/zoom)))
        for c in range(c0,c1+1):
            draw_line(point(c,r0),point(c,r1),Color(0.05,0.16,0.18,0.25),1.0)
        for r in range(r0,r1+1):
            draw_line(point(c0,r),point(c1,r),Color(0.05,0.16,0.18,0.25),1.0)
    for p in world["cells"]:
        if bool(p["river"]):
            var idx: int=int(p["river_to"])
            if idx>=0:
                var to: Dictionary=world["cells"][idx]
                var a: Vector2=point(float(p["c"])+0.5,float(p["r"])+0.5)
                var b: Vector2=point(float(to["c"])+0.5,float(to["r"])+0.5)
                var thickness: float=clampf(zoom*0.28,1.0,4.5)
                draw_line(a,b,Color("#62c9ee"),thickness,true)
    var road: Array=trade_route.get("tiles",[])
    if road.size()>=2:
        # Roads follow traversable grid tiles, never straight through water.
        for n in range(1,road.size()):
            var before: Dictionary=road[n-1]
            var after: Dictionary=road[n]
            var a: Vector2=point(float(before["c"])+0.5,float(before["r"])+0.5)
            var b: Vector2=point(float(after["c"])+0.5,float(after["r"])+0.5)
            draw_line(a,b,Color("#624c2b"),maxf(2.4,zoom*0.69),true)
            draw_line(a,b,Color("#d2a45a"),maxf(1.25,zoom*0.31),true)
        var town: Dictionary=road[road.size()-1]
        var marker: Vector2=point(float(town["c"])+0.5,float(town["r"])+0.5)
        draw_circle(marker,maxf(5.0,zoom*1.15),Color("#ffc562"))
        draw_arc(marker,maxf(7.0,zoom*1.4),0.0,TAU,22,Color("#51320f"),2.0,true)
        for caravan in trade_caravans:
            var duration: float=maxf(1.0,float(caravan.get("duration",6)))
            var pct: float=clampf(float(caravan.get("progress",0))/duration,0.0,1.0)
            if String(caravan.get("from","capital"))=="outpost":pct=1.0-pct
            var offset: float=pct*float(road.size()-1)
            var idx: int=clampi(int(floor(offset)),0,road.size()-2)
            var f: float=clampf(offset-idx,0.0,1.0)
            var first: Dictionary=road[idx]
            var second: Dictionary=road[idx+1]
            var pos: Vector2=point(lerpf(float(first["c"])+0.5,float(second["c"])+0.5,f),
                lerpf(float(first["r"])+0.5,float(second["r"])+0.5,f))
            draw_circle(pos,maxf(3.5,zoom*0.8),Color("#ff7548"))
            draw_arc(pos,maxf(4.5,zoom),0.0,TAU,14,Color("#38201a"),1.4,true)
    var colors: Array[Color]=[Color("#e9f6ff"),Color("#ff9f87"),Color("#ffc85d"),Color("#bb95e8")]
    for i in range(world.get("starts",[]).size()):
        var site: Dictionary=world["starts"][i]
        var center: Vector2=point(float(site["c"])+0.5,float(site["r"])+0.5)
        draw_circle(center,maxf(5.0,zoom*1.2),colors[i%colors.size()])
        draw_arc(center,maxf(7.0,zoom*1.5),0.0,TAU,20,Color("#182533"),2.0,true)
    if chosen.x>=0:
        draw_rect(Rect2(point(chosen.x,chosen.y),Vector2.ONE*zoom),Color("#ffe989"),false,maxf(2.0,zoom*0.1))

func _gui_input(event: InputEvent) -> void:
    if world.is_empty():return
    if event is InputEventMouseButton:
        var mb: InputEventMouseButton=event
        if mb.button_index==MOUSE_BUTTON_WHEEL_UP or mb.button_index==MOUSE_BUTTON_WHEEL_DOWN:
            if mb.pressed:
                var original: Vector2=(mb.position-pan)/zoom
                zoom=clampf(zoom*(1.18 if mb.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.18),0.9,28.0)
                pan=mb.position-original*zoom
                queue_redraw()
                accept_event()
        elif mb.button_index==MOUSE_BUTTON_LEFT:
            if mb.pressed:
                dragging=true
                drag_start=mb.position
                last_pointer=mb.position
                movement=0.0
            else:
                if dragging and movement<7.0:
                    var selected: Vector2i=tile_at(mb.position)
                    select_cell(selected.x,selected.y)
                dragging=false
            accept_event()
    elif event is InputEventMouseMotion and dragging:
        var motion: InputEventMouseMotion=event
        movement+=motion.position.distance_to(last_pointer)
        pan+=motion.position-last_pointer
        last_pointer=motion.position
        queue_redraw()
        accept_event()
    elif event is InputEventScreenTouch:
        var touch: InputEventScreenTouch=event
        if touch.pressed:
            dragging=true
            drag_start=touch.position
            last_pointer=touch.position
            movement=0.0
        else:
            if dragging and movement<7.0:
                var selected: Vector2i=tile_at(touch.position)
                select_cell(selected.x,selected.y)
            dragging=false
        accept_event()
    elif event is InputEventScreenDrag:
        var screen_drag: InputEventScreenDrag=event
        movement+=screen_drag.position.distance_to(last_pointer)
        pan+=screen_drag.position-last_pointer
        last_pointer=screen_drag.position
        queue_redraw()
        accept_event()
