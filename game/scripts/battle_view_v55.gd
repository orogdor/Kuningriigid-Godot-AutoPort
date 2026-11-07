extends Control
## First tactical viewport in Godot. 5x5 visible detail tiles (3x3 combat
## plus retreat ring); original Stone Age GLBs reused as miniature markers.
## Inputs are explicit, battle_v55.gd owns the entire simulation and saving.
signal return_requested
signal battle_command_requested(id: int,order: String)
signal battle_tick_requested(seconds: float)
signal battle_move_requested(id: int,x: float,z: float)
signal battle_individual_move_requested(id: int,index: int,x: float,z: float)
signal battle_individual_return_requested(id: int,index: int)
signal battle_individual_attack_requested(id: int,index: int,
    enemy_squad: int,enemy_index: int)
signal battle_squad_attack_requested(id: int,enemy_squad: int)
signal battle_demo_retry_requested
signal battle_auto_paused

const Units=preload("res://scripts/web_units_v53.gd")
const Battlefield=preload("res://scripts/battle_v55.gd")
const Nav57=preload("res://scripts/battle_nav_v57.gd")
const Animation61=preload("res://scripts/battle_animation_v61.gd")
const Animation65=preload("res://scripts/battle_animation_v65.gd")
const DEATH_VISUAL_SECONDS_V69: float=1.8
# V93: track only corpses that still need render-time cleanup; weak refs
# cannot keep despawned 3D actors alive across battle reloads.
var fallen_actors_v93: Dictionary={}
var viewport: SubViewport
var battle_camera: Camera3D
var scene_root: Node3D
var actors_root: Node3D
var obstacles_root: Node3D
var projectiles_root: Node3D
var move_markers_root: Node3D
var battle_canvas_container: SubViewportContainer
var move_toggle: Button
var move_mode_enabled: bool=false
var individual_picker: OptionButton
var man_indices: Array[int]=[]
var individual_move_toggle: Button
var individual_move_mode: bool=false
var individual_attack_mode_v68: bool=false
var attack_toggle_v68: Button
var squad_attack_mode_v71: bool=false
var squad_attack_toggle_v71: Button
var auto_timer: Timer
var auto_button: Button
var demo_retry_button: Button
var auto_play_enabled: bool=false
var status_label: Label
var result_label: Label
var fps_label: Label
var skeletal_status_label: Label
var fps_refresh: float=0.0
var graphics_button: Button
var fast_graphics: bool=false
var obstacle_signature: String="__uninitialized__"
var order_picker: OptionButton
var id_list: Array[int]=[]
var current_battle: Dictionary={}
const DEFAULT_CAMERA_SIZE_V75: float=90.0
var cam_size: float=DEFAULT_CAMERA_SIZE_V75
const MIN_BATTLE_ZOOM: float=1.5
const MAX_BATTLE_ZOOM: float=1050.0
var pinch_points: Dictionary={}
var pinch_distance: float=0.0
var tap_start_v67: Vector2=Vector2.ZERO
var tap_index_v67: int=-1
var tap_cancelled_v67: bool=false
var follow_actor_key: String=""
var follow_origin: Vector3=Vector3.ZERO
var follow_button: Button

func set_fast_graphics(enable: bool) -> void:
    fast_graphics=enable
    # Godot SubViewportContainer owns the viewport's size when stretch=true.
    # stretch_shrink renders at half width and height on Android/iOS while
    # still scaling the image to fit the full tactical view.
    if battle_canvas_container!=null:
        battle_canvas_container.stretch_shrink=2 if fast_graphics else 1
    if graphics_button!=null:
        graphics_button.text="Pildikvaliteet: säästlik" if fast_graphics else \
            "Pildikvaliteet: terav"

func _toggle_graphics() -> void:
    set_fast_graphics(not fast_graphics)

func _process(delta: float) -> void:
    if not visible:return
    _render_soldier_motion_v65(delta)
    _render_fallen_v69(delta)
    _follow_soldier_frame()
    if fps_label==null:return
    fps_refresh+=delta
    if fps_refresh>=1.0:
        fps_refresh=0.0
        fps_label.text="FPS: %d" % int(Engine.get_frames_per_second())
        _refresh_skeletal_status()

func _refresh_skeletal_status() -> void:
    if skeletal_status_label==null or actors_root==null:return
    var animated: int=0
    var total: int=0
    for soldier in actors_root.get_children():
        total+=1
        if soldier.get_child_count()==0:continue
        var model: Node3D=soldier.get_child(0) as Node3D
        if model==null:continue
        var info: Dictionary=model.get_meta("source_animator_v65",{})
        var player: AnimationPlayer=info.get("player",null)
        if player!=null and is_instance_valid(player) and player.is_playing():
            animated+=1
    # Shows actual AnimationPlayer playback, not a simulated swing counter.
    # Useful for diagnosing missing animations on a particular Android GPU.
    skeletal_status_label.text="Animatsioon: %d/%d" % [animated,total]

func _render_soldier_motion_v65(delta: float) -> void:
    if actors_root==null:return
    var frame: float=clampf(delta,0.0,0.5)
    for node in actors_root.get_children():
        if node.has_meta("fallen_since_v69"):continue
        if not node.has_meta("interpolation_v63"):continue
        var state: Dictionary=node.get_meta("interpolation_v63")
        if state.is_empty():continue
        # V92: once the actor reaches a completely idle pose, let the source
        # AnimationPlayer loop the GLB's idle clip without rebuilding poses
        # and allocating a transient person Dictionary every render frame.
        # New snapshots or combat events always invalidate this cache.
        if bool(state.get("idle_pose_ready_v92",false)) and \
                not bool(state.get("move_active",false)) and \
                float(state.get("attack_clock",0.0))<=0.0 and \
                float(state.get("hit_clock",0.0))<=0.0 and \
                node.position.distance_squared_to(state["target"])<0.000004 and \
                absf(wrapf(node.rotation.y-float(state["to_heading"]),-PI,PI))<0.002:
            continue
        var duration: float=maxf(float(state.get("duration",0.4)),0.01)
        var fraction: float=clampf(float(state.get("fraction",0.0))+\
            frame/duration,0.0,1.50)
        var origin: Vector3=state["origin"]
        var target: Vector3=state["target"]
        # The tactical engine advances only 0.2 sim seconds per 0.4 real
        # seconds. Blend between real snapshots, then predict at most 0.2
        # extra real seconds of visually-only motion. V63 stopped its
        # animation exactly at fraction=1, leaving a visible freeze before
        # the next snapshot even when the viewport ran at 56+ FPS.
        var destination: Vector3=origin.lerp(target,minf(fraction,1.0))
        var moving: bool=bool(state.get("move_active",false))
        if fraction>1.0 and moving and auto_play_enabled:
            var velocity: Vector3=state.get("velocity",Vector3.ZERO)
            destination+=velocity*minf((fraction-1.0)*duration,0.20)
        # Smooth corrections after each deterministic simulation update.
        # Prevents the visible soldier from jumping backwards when the
        # previous frame used extrapolated movement.
        var follow: float=1.0 if delta>=0.3 else 1.0-exp(-frame*20.0)
        # V77: even an unexpectedly large deterministic correction or a
        # device stall must not teleport the visible actor during attacks.
        # The battle simulation remains authoritative and unchanged.
        const MAX_VISIBLE_SPEED_V77: float=24.0
        var correction: float=node.position.distance_to(destination)*follow
        node.position=node.position.move_toward(destination,
            minf(correction,MAX_VISIBLE_SPEED_V77*frame))
        node.rotation.y=lerp_angle(node.rotation.y,
            float(state["to_heading"]),follow)
        state["fraction"]=fraction
        var phase: float=float(state.get("phase",0.0))
        phase=fposmod(phase+frame*(Animation65.WALK_PHASE_SPEED if moving else 1.2),TAU)
        state["phase"]=phase
        var attack_clock: float=maxf(0.0,
            float(state.get("attack_clock",0.0))-frame*Battlefield.SCALE)
        var hit_clock: float=maxf(0.0,
            float(state.get("hit_clock",0.0))-frame*Battlefield.SCALE)
        state["attack_clock"]=attack_clock
        state["hit_clock"]=hit_clock
        # Motion and combat poses run each rendered frame, independent of
        # both the 0.25s timer and 0.2s deterministic simulation step.
        var model: Node3D=node.get_child(0) as Node3D
        if model!=null:
            # V92: "person" was already deep-copied from the authoritative
            # battle at set_battle(). Its render-only fields can be updated
            # in place; this does not modify the saved simulation state.
            var person: Dictionary=state["person"]
            person["moving"]=moving and (auto_play_enabled or fraction<1.0)
            person["anim_phase"]=phase
            person["attack_anim"]=attack_clock
            person["hit_anim_v61"]=hit_clock
            Animation65.apply(model,person,String(state["kind"]))
        state["idle_pose_ready_v92"]=model!=null and not moving and \
            fraction>=1.0 and attack_clock<=0.0 and hit_clock<=0.0 and \
            node.position.distance_squared_to(target)<0.000004 and \
            absf(wrapf(node.rotation.y-float(state["to_heading"]),-PI,PI))<0.002
        node.set_meta("interpolation_v63",state)

## The original GLB Skeleton3D has a death clip, but earlier view logic
## removed the model on the same snapshot in which HP reached zero.
## A fallen model gets a short, render-only lifetime and is not a real unit.
## The real battle state, collisions, HP and save format are untouched.
func _fallen_in_battle_v69(actor: Node3D) -> bool:
    var squad: int=int(actor.get_meta("squad_v67",-999999))
    var person: int=int(actor.get_meta("person_v67",-1))
    for fighter in current_battle.get("fighters",[]):
        if int(fighter.get("id",-1))!=squad:continue
        if String(fighter.get("mode",""))=="retreated":return false
        for man in fighter.get("men",[]):
            if int(man.get("index",-1))!=person:continue
            return float(man.get("hp",0.0))<=0.0 and \
                not bool(man.get("escaped",false))
    return false

func _start_fallen_v69(actor: Node3D) -> void:
    if actor.has_meta("fallen_since_v69"):return
    actor.set_meta("fallen_since_v69",0.0)
    actor.remove_meta("interpolation_v63")
    fallen_actors_v93[actor.get_instance_id()]=weakref(actor)
    var marker: Node3D=actor.get_node_or_null("TeamMarker") as Node3D
    if marker!=null:marker.hide()
    if actor.get_child_count()==0:return
    var model: Node3D=actor.get_child(0) as Node3D
    if model!=null:
        actor.set_meta("death_clip_v69",Animation65.play_death(model))

func _render_fallen_v69(delta: float) -> void:
    if actors_root==null or fallen_actors_v93.is_empty():return
    # V93: no per-frame scan of hundreds of living GLB soldiers.
    # The stable list also handles newly revived IDs and freed old actors.
    for actor_id in fallen_actors_v93.keys():
        var ref: WeakRef=fallen_actors_v93[actor_id] as WeakRef
        var actor: Node3D=ref.get_ref() as Node3D if ref!=null else null
        if actor==null or actor.get_parent()!=actors_root or \
                not actor.has_meta("fallen_since_v69"):
            fallen_actors_v93.erase(actor_id)
            continue
        var elapsed: float=float(actor.get_meta("fallen_since_v69",0.0))+\
            maxf(0.0,delta)
        if elapsed>=DEATH_VISUAL_SECONDS_V69:
            fallen_actors_v93.erase(actor_id)
            actors_root.remove_child(actor)
            actor.free()
            continue
        actor.set_meta("fallen_since_v69",elapsed)

func _follow_soldier_frame() -> void:
    if follow_actor_key=="" or battle_camera==null or actors_root==null:
        return
    var subject: Node3D=actors_root.get_node_or_null(follow_actor_key) as Node3D
    if subject==null:
        _stop_following()
        return
    var displacement: Vector3=subject.position-follow_origin
    # Shift camera parallel to the ground; preserve its angle and zoom.
    battle_camera.position+=Vector3(displacement.x,0.0,displacement.z)
    follow_origin=subject.position

func _stop_following() -> void:
    follow_actor_key=""
    if follow_button!=null:follow_button.text="Jälgi sõdurit"

func _follow_selected_soldier() -> void:
    if follow_actor_key!="":
        _stop_following()
        return
    var selected: Dictionary=_chosen_man()
    if selected.is_empty() or actors_root==null:return
    var key: String="TacticalMan_%d_%d" % [
        int(selected["squad"]),int(selected["index"])]
    var node: Node3D=actors_root.get_node_or_null(key) as Node3D
    if node==null:return
    _focus_individual()
    # Use the current interpolated position, not stale simulation coords,
    # to avoid a jump immediately after engaging follow.
    var from: Vector3=Vector3(
        float(selected.get("x",node.position.x)),0.0,
        float(selected.get("z",node.position.z)))
    battle_camera.position+=Vector3(
        node.position.x-from.x,0.0,node.position.z-from.z)
    follow_actor_key=key
    follow_origin=node.position
    if follow_button!=null:follow_button.text="Lõpeta jälgimine"

func _box(parent: Node3D,name: String,size: Vector3,pos: Vector3,color: Color) -> void:
    var node:=MeshInstance3D.new()
    node.name=name
    var mesh:=BoxMesh.new()
    mesh.size=size
    node.mesh=mesh
    node.position=pos
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=color
    mat.roughness=1.0
    node.material_override=mat
    parent.add_child(node)

func _button(title: String,callback: Callable) -> Button:
    var button:=Button.new()
    button.text=title
    button.custom_minimum_size=Vector2(95,43)
    button.pressed.connect(callback)
    return button

func _issue(cmd: String) -> void:
    var index: int=order_picker.selected
    if index>=0 and index<id_list.size():
        battle_command_requested.emit(id_list[index],cmd)

func _chosen_man() -> Dictionary:
    if individual_picker==null or order_picker==null:return {}
    var squad: int=order_picker.selected
    var person: int=individual_picker.selected
    if squad<0 or squad>=id_list.size() or \
            person<0 or person>=man_indices.size():return {}
    return {"squad":id_list[squad],"index":man_indices[person]}

## Use the actual projected source-GLB model positions. Do not run a battle
## update when selecting: doing so would snap all interpolated men backward
## even though the screen is rendering at 56+ FPS.
func _select_soldier_at_v67(screen_pos: Vector2) -> bool:
    if battle_camera==null or battle_canvas_container==null or \
            viewport==null or actors_root==null or id_list.is_empty():
        return false
    if battle_canvas_container.size.x<=1.0 or \
            battle_canvas_container.size.y<=1.0:return false
    var point: Vector2=screen_pos*Vector2(
        float(viewport.size.x)/battle_canvas_container.size.x,
        float(viewport.size.y)/battle_canvas_container.size.y)
    var distance_limit: float=pow(maxf(26.0,float(viewport.size.y)*0.04),2.0)
    var winner: Node3D=null
    for candidate in actors_root.get_children():
        var actor: Node3D=candidate as Node3D
        if actor==null or actor.has_meta("fallen_since_v69") or \
                int(actor.get_meta("team_v67",-1))!=0:continue
        var centre: Vector3=actor.global_position+Vector3(0.0,2.5,0.0)
        if battle_camera.is_position_behind(centre):continue
        var px: Vector2=battle_camera.unproject_position(centre)
        var dist: float=px.distance_squared_to(point)
        if dist>=distance_limit:continue
        distance_limit=dist
        winner=actor
    if winner==null:return false
    var squad: int=int(winner.get_meta("squad_v67",-1))
    var person: int=int(winner.get_meta("person_v67",-1))
    var selected_squad: int=id_list.find(squad)
    if selected_squad<0:return false
    _stop_following()
    order_picker.select(selected_squad)
    _refresh_individual_picker()
    var selected_man: int=man_indices.find(person)
    if selected_man<0:return false
    individual_picker.select(selected_man)
    _refresh_selection_markers_v67()
    return true

func _selected_attack_target_v68() -> Dictionary:
    var chosen: Dictionary=_chosen_man()
    if chosen.is_empty():return {}
    for fighter in current_battle.get("fighters",[]):
        if int(fighter.get("id",-1))!=int(chosen["squad"]) or \
                int(fighter.get("team",-1))!=0:continue
        for man in fighter.get("men",[]):
            if int(man.get("index",-1))==int(chosen["index"]):
                return man.get("attack_target_v68",{})
    return {}

func _select_enemy_at_v68(screen_pos: Vector2) -> bool:
    if (not individual_attack_mode_v68 and not squad_attack_mode_v71) or \
            int(current_battle.get("version",0))<68 or \
            battle_camera==null or actors_root==null or \
            battle_canvas_container==null or viewport==null:
        return false
    var chosen: Dictionary=_chosen_man()
    if chosen.is_empty():return false
    if battle_canvas_container.size.x<1.0 or \
            battle_canvas_container.size.y<1.0:return false
    var p: Vector2=screen_pos*Vector2(
        float(viewport.size.x)/battle_canvas_container.size.x,
        float(viewport.size.y)/battle_canvas_container.size.y)
    var threshold: float=pow(maxf(26.0,float(viewport.size.y)*0.04),2.0)
    var winner: Node3D=null
    for candidate in actors_root.get_children():
        var actor: Node3D=candidate as Node3D
        if actor==null or actor.has_meta("fallen_since_v69") or \
                int(actor.get_meta("team_v67",-1))!=1:
            continue
        var centre: Vector3=actor.global_position+Vector3(0,2.5,0)
        if battle_camera.is_position_behind(centre):continue
        var distance: float=battle_camera.unproject_position(
            centre).distance_squared_to(p)
        if distance>=threshold:continue
        threshold=distance
        winner=actor
    if winner==null:return false
    if squad_attack_mode_v71:
        _toggle_squad_attack_v71()
        battle_squad_attack_requested.emit(int(chosen["squad"]),
            int(winner.get_meta("squad_v67",-1)))
    else:
        _toggle_individual_attack_v68()
        battle_individual_attack_requested.emit(int(chosen["squad"]),
            int(chosen["index"]),int(winner.get_meta("squad_v67",-1)),
            int(winner.get_meta("person_v67",-1)))
    return true

func _toggle_individual_attack_v68() -> void:
    squad_attack_mode_v71=false
    if squad_attack_toggle_v71!=null:
        squad_attack_toggle_v71.text="Ründa väesalgaga"
    if int(current_battle.get("version",0))<68 or \
            String(current_battle.get("result",""))!="" or \
            _chosen_man().is_empty():
        individual_attack_mode_v68=false
    else:
        individual_attack_mode_v68=not individual_attack_mode_v68
    move_mode_enabled=false
    individual_move_mode=false
    if move_toggle!=null:move_toggle.text="Liigu kaardil"
    if individual_move_toggle!=null:individual_move_toggle.text="Sõdur liigub"
    if attack_toggle_v68!=null:
        attack_toggle_v68.text="Puuduta vastast" if individual_attack_mode_v68 else \
            "Ründa valitud vastast"

func _selected_squad_target_v71() -> int:
    if int(current_battle.get("version",0))<71:return -999999
    var chosen: Dictionary=_chosen_man()
    if chosen.is_empty():return -999999
    for fighter in current_battle.get("fighters",[]):
        if int(fighter.get("id",-1))==int(chosen["squad"]) and \
                int(fighter.get("team",-1))==0:
            return int(fighter.get("squad_target_v71",-999999))
    return -999999

func _toggle_squad_attack_v71() -> void:
    var can_order: bool=int(current_battle.get("version",0))>=71 and \
        String(current_battle.get("result",""))=="" and \
        not _chosen_man().is_empty()
    squad_attack_mode_v71=can_order and not squad_attack_mode_v71
    individual_attack_mode_v68=false
    individual_move_mode=false
    move_mode_enabled=false
    if attack_toggle_v68!=null:
        attack_toggle_v68.text="Ründa valitud vastast"
    if individual_move_toggle!=null:
        individual_move_toggle.text="Sõdur liigub"
    if move_toggle!=null:move_toggle.text="Liigu kaardil"
    if squad_attack_toggle_v71!=null:
        squad_attack_toggle_v71.text="Puuduta vaenlase väesalka" if \
            squad_attack_mode_v71 else "Ründa väesalgaga"

func _refresh_selection_markers_v67() -> void:
    if actors_root==null:return
    var selection: Dictionary=_chosen_man()
    var focused: Dictionary=_selected_attack_target_v68()
    var focused_squad: int=_selected_squad_target_v71()
    for candidate in actors_root.get_children():
        var actor: Node3D=candidate as Node3D
        if actor==null:continue
        var marker: MeshInstance3D=actor.get_node_or_null("TeamMarker") as MeshInstance3D
        if marker==null:continue
        var mat: StandardMaterial3D=marker.material_override as StandardMaterial3D
        if mat==null:continue
        var team: int=int(actor.get_meta("team_v67",-1))
        var chosen: bool=team==0 and not selection.is_empty() and \
            int(actor.get_meta("squad_v67",-1))==int(selection["squad"]) and \
            int(actor.get_meta("person_v67",-1))==int(selection["index"])
        var pinned: bool=team==1 and ((
            not focused.is_empty() and \
            int(actor.get_meta("squad_v67",-1))==int(focused.get("squad",-1)) and \
            int(actor.get_meta("person_v67",-1))==int(focused.get("index",-1))) or \
            int(actor.get_meta("squad_v67",-1))==focused_squad)
        mat.albedo_color=Color("#ffe250") if chosen else \
            (Color("#ff9b32") if pinned else \
            (Color("#65caff") if team==0 else Color("#ed6b56")))

func _refresh_individual_picker() -> void:
    if individual_picker==null or order_picker==null:return
    var previous: int=-1
    var selected: int=individual_picker.selected
    if selected>=0 and selected<man_indices.size():
        previous=man_indices[selected]
    man_indices.clear()
    individual_picker.clear()
    var squad_pos: int=order_picker.selected
    if squad_pos<0 or squad_pos>=id_list.size():return
    var current_id: int=id_list[squad_pos]
    var selected_position: int=0
    for fighter in current_battle.get("fighters",[]):
        if int(fighter.get("id",-1))!=current_id or \
                int(fighter.get("team",-1))!=0:continue
        for man in fighter.get("men",[]):
            if float(man.get("hp",0))<=0 or bool(man.get("escaped",false)):
                continue
            var index: int=int(man.get("index",-1))
            if index<0:continue
            if index==previous:selected_position=man_indices.size()
            man_indices.append(index)
            individual_picker.add_item("#%d • %.1f HP" % [
                index+1,float(man.get("hp",0.0))])
        break
    if not man_indices.is_empty():
        individual_picker.select(selected_position)

func _on_person_changed(_index: int) -> void:
    squad_attack_mode_v71=false
    if squad_attack_toggle_v71!=null:squad_attack_toggle_v71.text="Ründa väesalgaga"
    individual_attack_mode_v68=false
    if attack_toggle_v68!=null:attack_toggle_v68.text="Ründa valitud vastast"
    _stop_following()
    if not current_battle.is_empty():set_battle(current_battle)

func _toggle_individual_move() -> void:
    squad_attack_mode_v71=false
    if squad_attack_toggle_v71!=null:squad_attack_toggle_v71.text="Ründa väesalgaga"
    individual_attack_mode_v68=false
    if attack_toggle_v68!=null:attack_toggle_v68.text="Ründa valitud vastast"
    if int(current_battle.get("version",0))<60 or _chosen_man().is_empty():
        individual_move_mode=false
    else:
        individual_move_mode=not individual_move_mode
    move_mode_enabled=false
    if move_toggle!=null:move_toggle.text="Liigu kaardil"
    if individual_move_toggle!=null:
        individual_move_toggle.text="Puuduta sõduri sihti" if individual_move_mode else "Sõdur liigub"

func _individual_rejoin() -> void:
    var chosen: Dictionary=_chosen_man()
    if chosen.is_empty() or int(current_battle.get("version",0))<60:return
    individual_move_mode=false
    if individual_move_toggle!=null:individual_move_toggle.text="Sõdur liigub"
    battle_individual_return_requested.emit(int(chosen["squad"]),int(chosen["index"]))

func _focus_individual() -> void:
    _stop_following()
    var chosen: Dictionary=_chosen_man()
    if chosen.is_empty() or battle_camera==null:return
    for fighter in current_battle.get("fighters",[]):
        if int(fighter.get("id",-1))!=int(chosen["squad"]):continue
        for man in fighter.get("men",[]):
            if int(man.get("index",-1))!=int(chosen["index"]):continue
            var x: float=float(man["x"])
            var z: float=float(man["z"])
            battle_camera.position=Vector3(x,670.0,z+520.0)
            battle_camera.look_at(Vector3(x,0,z),Vector3.UP)
            cam_size=3.0
            battle_camera.size=cam_size
            return

func _toggle_move_mode() -> void:
    squad_attack_mode_v71=false
    if squad_attack_toggle_v71!=null:squad_attack_toggle_v71.text="Ründa väesalgaga"
    individual_attack_mode_v68=false
    if attack_toggle_v68!=null:attack_toggle_v68.text="Ründa valitud vastast"
    if int(current_battle.get("version",0))<59 or id_list.is_empty():
        move_mode_enabled=false
    else:
        move_mode_enabled=not move_mode_enabled
    individual_move_mode=false
    if individual_move_toggle!=null:individual_move_toggle.text="Sõdur liigub"
    if move_toggle!=null:
        move_toggle.text="Puuduta sihtpunkti" if move_mode_enabled else "Liigu kaardil"

func _zoom_pan(delta: Vector2) -> void:
    if battle_camera==null or battle_canvas_container==null:return
    _stop_following()
    var relative: float=cam_size/maxf(1.0,battle_canvas_container.size.y)
    var right: Vector3=battle_camera.global_transform.basis.x
    var up: Vector3=battle_camera.global_transform.basis.y
    var motion: Vector3=(-right*delta.x+up*delta.y)*relative
    battle_camera.position+=Vector3(motion.x,0.0,motion.z)

func _pinch_length() -> float:
    if pinch_points.size()<2:return 0.0
    var active: Array=pinch_points.values()
    return (active[0] as Vector2).distance_to(active[1] as Vector2)

func _battle_camera_input(event: InputEvent) -> bool:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index==MOUSE_BUTTON_WHEEL_UP:
            _zoom(0.82)
            return true
        if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(1.22)
            return true
    if event is InputEventMouseMotion and \
            (event.button_mask & MOUSE_BUTTON_MASK_RIGHT)!=0:
        _zoom_pan(event.relative)
        return true
    if event is InputEventScreenTouch:
        var choosing: bool=not move_mode_enabled and not individual_move_mode
        if event.pressed:
            if choosing and pinch_points.is_empty():
                tap_start_v67=event.position
                tap_index_v67=event.index
                tap_cancelled_v67=false
            else:
                tap_cancelled_v67=true # Any second finger is a pinch, not a tap.
            pinch_points[event.index]=event.position
        else:
            var tapped: bool=choosing and not tap_cancelled_v67 and \
                tap_index_v67==event.index and pinch_points.size()==1 and \
                event.position.distance_to(tap_start_v67)<=18.0
            pinch_points.erase(event.index)
            if tapped:
                if individual_attack_mode_v68 or squad_attack_mode_v71:
                    _select_enemy_at_v68(event.position)
                else:
                    _select_soldier_at_v67(event.position)
            if event.index==tap_index_v67:tap_index_v67=-1
        pinch_distance=_pinch_length()
        return choosing
    if event is InputEventScreenDrag:
        if event.index==tap_index_v67 and \
                event.position.distance_to(tap_start_v67)>18.0:
            tap_cancelled_v67=true
        if pinch_points.has(event.index):
            pinch_points[event.index]=event.position
        if pinch_points.size()>=2:
            var next_distance: float=_pinch_length()
            if pinch_distance>10.0 and next_distance>10.0:
                _zoom(pinch_distance/next_distance)
            pinch_distance=next_distance
            return true
        if not move_mode_enabled and not individual_move_mode:
            _zoom_pan(event.relative)
            return true
    return false

func _on_battle_canvas_input(event: InputEvent) -> void:
    if _battle_camera_input(event):return
    if not move_mode_enabled and not individual_move_mode:
        if event is InputEventMouseButton and event.pressed and \
                event.button_index==MOUSE_BUTTON_LEFT:
            if individual_attack_mode_v68 or squad_attack_mode_v71:
                _select_enemy_at_v68(event.position)
            else:
                _select_soldier_at_v67(event.position)
        return
    if id_list.is_empty() or int(current_battle.get("version",0))<59:return
    var pos: Vector2
    if event is InputEventMouseButton:
        if not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
        pos=event.position
    elif event is InputEventScreenTouch:
        if not event.pressed:return
        pos=event.position
    else:return
    if battle_camera==null or battle_canvas_container==null:return
    if battle_canvas_container.size.x<1.0 or battle_canvas_container.size.y<1.0:
        return
    var screen_point: Vector2=pos*Vector2(
        float(viewport.size.x)/battle_canvas_container.size.x,
        float(viewport.size.y)/battle_canvas_container.size.y)
    var origin: Vector3=battle_camera.project_ray_origin(screen_point)
    var ray: Vector3=battle_camera.project_ray_normal(screen_point)
    if absf(ray.y)<0.00001:return
    var distance: float=-origin.y/ray.y
    if distance<=0.0:return
    var ground: Vector3=origin+ray*distance
    if individual_move_mode:
        var chosen: Dictionary=_chosen_man()
        if chosen.is_empty():return
        individual_move_mode=false
        if individual_move_toggle!=null:individual_move_toggle.text="Sõdur liigub"
        battle_individual_move_requested.emit(int(chosen["squad"]),
            int(chosen["index"]),ground.x,ground.z)
        return
    var index: int=order_picker.selected
    if index<0 or index>=id_list.size():return
    battle_move_requested.emit(id_list[index],ground.x,ground.z)
    move_mode_enabled=false
    if move_toggle!=null:move_toggle.text="Liigu kaardil"

func set_auto_battle(enable: bool) -> void:
    var was_running: bool=auto_play_enabled
    auto_play_enabled=enable and \
        String(current_battle.get("result",""))=="" and \
        not current_battle.is_empty()
    if auto_timer!=null:
        if auto_play_enabled:
            auto_timer.start()
        else:
            auto_timer.stop()
    if auto_button!=null:
        auto_button.text="⏸ Peata võitlus" if auto_play_enabled else "▶ Jätka võitlust"
    if was_running and not auto_play_enabled and \
            String(current_battle.get("result",""))=="":
        battle_auto_paused.emit()

func _toggle_auto_battle() -> void:
    set_auto_battle(not auto_play_enabled)

func _automatic_battle_step() -> void:
    if not auto_play_enabled or not visible or \
            String(current_battle.get("result",""))!="":
        set_auto_battle(false)
        return
    # Real-time playback: do not run four simulated seconds every second.
    # V61 ran 1.0 s at 0.25 s intervals and could finish the demo in 30 s.
    battle_tick_requested.emit(auto_timer.wait_time)

func _restart_demo() -> void:
    if not bool(current_battle.get("demo_v61",false)) or \
            String(current_battle.get("result",""))=="":return
    set_auto_battle(false)
    battle_demo_retry_requested.emit()

func _reset_camera() -> void:
    _stop_following()
    pinch_points.clear()
    pinch_distance=0.0
    tap_index_v67=-1
    tap_cancelled_v67=false
    cam_size=DEFAULT_CAMERA_SIZE_V75
    if battle_camera!=null:
        battle_camera.position=Vector3(0,670,520)
        battle_camera.look_at(Vector3.ZERO,Vector3.UP)
        battle_camera.size=cam_size

func _ready() -> void:
    var column:=VBoxContainer.new()
    column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(column)
    # Single horizontal toolbar: wrapping into 2-3 lines shrank the actual
    # 3D viewport and made 5.2m warriors smaller than a few display pixels.
    var bar_frame:=Control.new()
    bar_frame.name="BattleTopToolbarV75"
    bar_frame.custom_minimum_size=Vector2(0,46)
    bar_frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    column.add_child(bar_frame)
    var bar_scroll:=ScrollContainer.new()
    bar_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    bar_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    bar_frame.add_child(bar_scroll)
    bar_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bar:=HBoxContainer.new()
    bar.add_theme_constant_override("separation",4)
    bar_scroll.add_child(bar)
    bar.add_child(_button("Tagasi linna",func():return_requested.emit()))
    bar.add_child(_button("+1 s",func():battle_tick_requested.emit(1.0)))
    bar.add_child(_button("+10 s",func():battle_tick_requested.emit(10.0)))
    bar.add_child(_button("+30 s",func():battle_tick_requested.emit(30.0)))
    auto_button=_button("▶ Jätka võitlust",_toggle_auto_battle)
    bar.add_child(auto_button)
    graphics_button=_button("Pildikvaliteet",_toggle_graphics)
    bar.add_child(graphics_button)
    fps_label=Label.new()
    fps_label.name="BattleFpsV62"
    fps_label.text="FPS: —"
    bar.add_child(fps_label)
    skeletal_status_label=Label.new()
    skeletal_status_label.name="BattleSkeletalStatusV66"
    skeletal_status_label.text="Animatsioon: —"
    bar.add_child(skeletal_status_label)
    demo_retry_button=_button("Proovilahing uuesti",_restart_demo)
    demo_retry_button.disabled=true
    bar.add_child(demo_retry_button)
    bar.add_child(_button("Kogu lahing",_reset_camera))
    bar.add_child(_button("Suumi +",func():_zoom(0.70)))
    bar.add_child(_button("Suumi −",func():_zoom(1.40)))
    bar.add_child(_button("Väga lähedale",func():_zoom(0.15)))
    var tactical_frame:=Control.new()
    tactical_frame.name="BattleOrderToolbarV75"
    tactical_frame.custom_minimum_size=Vector2(0,46)
    tactical_frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    column.add_child(tactical_frame)
    var tactical_scroll:=ScrollContainer.new()
    tactical_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
    tactical_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    tactical_frame.add_child(tactical_scroll)
    tactical_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var tactical:=HBoxContainer.new()
    tactical.add_theme_constant_override("separation",4)
    tactical_scroll.add_child(tactical)
    order_picker=OptionButton.new()
    order_picker.custom_minimum_size=Vector2(160,44)
    tactical.add_child(order_picker)
    order_picker.item_selected.connect(func(_index: int):
        _refresh_individual_picker()
        set_battle(current_battle))
    individual_picker=OptionButton.new()
    individual_picker.custom_minimum_size=Vector2(130,44)
    individual_picker.item_selected.connect(_on_person_changed)
    tactical.add_child(individual_picker)
    move_toggle=_button("Liigu kaardil",_toggle_move_mode)
    tactical.add_child(move_toggle)
    individual_move_toggle=_button("Sõdur liigub",_toggle_individual_move)
    tactical.add_child(individual_move_toggle)
    tactical.add_child(_button("Tagasi rivvi",_individual_rejoin))
    attack_toggle_v68=_button("Ründa valitud vastast",_toggle_individual_attack_v68)
    attack_toggle_v68.name="AttackTargetV68"
    tactical.add_child(attack_toggle_v68)
    squad_attack_toggle_v71=_button("Ründa väesalgaga",_toggle_squad_attack_v71)
    squad_attack_toggle_v71.name="SquadAttackV71"
    tactical.add_child(squad_attack_toggle_v71)
    tactical.add_child(_button("Suumi sõdurile",_focus_individual))
    follow_button=_button("Jälgi sõdurit",_follow_selected_soldier)
    tactical.add_child(follow_button)
    for option in [
        ["Ründa","attack"],["Hoia positsiooni","hold"],
        ["Odade vastuvõtt","spear_wall"],["Hajurivi","loose"],
        ["Lase ja eemaldu","skirmish"],["Tavarivi","line"],
        ["Tagane üle piiri","retreat"]
    ]:
        tactical.add_child(_button(option[0],_issue.bind(option[1])))
    auto_timer=Timer.new()
    auto_timer.name="DemoAutoTickV61"
    auto_timer.wait_time=0.25
    auto_timer.one_shot=false
    auto_timer.timeout.connect(_automatic_battle_step)
    add_child(auto_timer)
    status_label=Label.new()
    status_label.name="BattleStatusV55"
    # The long 9-squad status is available in a tooltip. Never let it push
    # the 3D battlefield off screen as it grows with combat events.
    status_label.autowrap_mode=TextServer.AUTOWRAP_OFF
    status_label.clip_text=true
    status_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    status_label.custom_minimum_size=Vector2(0,24)
    status_label.add_theme_font_size_override("font_size",13)
    column.add_child(status_label)
    result_label=Label.new()
    result_label.name="BattleResultV62"
    result_label.add_theme_font_size_override("font_size",20)
    result_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    result_label.hide()
    column.add_child(result_label)
    var container:=SubViewportContainer.new()
    battle_canvas_container=container
    container.gui_input.connect(_on_battle_canvas_input)
    container.custom_minimum_size=Vector2(240,180)
    container.stretch=true
    container.size_flags_vertical=Control.SIZE_EXPAND_FILL
    column.add_child(container)
    viewport=SubViewport.new()
    viewport.name="TacticalViewV55"
    viewport.own_world_3d=true
    set_fast_graphics(OS.get_name()=="Android" or OS.get_name()=="iOS")
    viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
    container.add_child(viewport)
    scene_root=Node3D.new()
    scene_root.name="BattlefieldV55"
    viewport.add_child(scene_root)
    var environment:=WorldEnvironment.new()
    var env:=Environment.new()
    env.background_mode=Environment.BG_COLOR
    env.background_color=Color("#8da4ae")
    env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color=Color("#c6c7b6")
    env.ambient_light_energy=1.0
    environment.environment=env
    scene_root.add_child(environment)
    var sun:=DirectionalLight3D.new()
    sun.rotation_degrees=Vector3(-48,-40,0)
    sun.light_energy=1.3
    scene_root.add_child(sun)
    battle_camera=Camera3D.new()
    battle_camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    battle_camera.size=cam_size
    battle_camera.position=Vector3(0,670,520)
    battle_camera.current=true
    scene_root.add_child(battle_camera)
    battle_camera.look_at(Vector3.ZERO,Vector3.UP)
    # x=-2..2, z=-2..2: the outer 16 tiles are the retreat ring.
    for r in range(-2,3):
        for c in range(-2,3):
            var retreat: bool=absi(c)==2 or absi(r)==2
            var color:=Color("#a48967") if retreat else Color("#6a8561")
            _box(scene_root,"Tile_%d_%d" % [c,r],
                Vector3(224.5,1.0,194.5),Vector3(c*225.0,-1.0,r*195.0),color)
    var red:=Color("#bd3734")
    for x in [-Battlefield.HALF_X,Battlefield.HALF_X]:
        _box(scene_root,"RetreatLineX_"+str(x),
            Vector3(1.8,0.5,585.0),Vector3(x,0,0),red)
    for z in [-Battlefield.HALF_Z,Battlefield.HALF_Z]:
        _box(scene_root,"RetreatLineZ_"+str(z),
            Vector3(675.0,0.5,1.8),Vector3(0,0,z),red)
    obstacles_root=Node3D.new()
    obstacles_root.name="BattleObstaclesV57"
    scene_root.add_child(obstacles_root)
    actors_root=Node3D.new()
    actors_root.name="TacticalActorsV55"
    scene_root.add_child(actors_root)
    projectiles_root=Node3D.new()
    projectiles_root.name="StoneFlightsV58"
    scene_root.add_child(projectiles_root)
    move_markers_root=Node3D.new()
    move_markers_root.name="MoveDestinationsV59"
    scene_root.add_child(move_markers_root)

func _refresh_obstacles() -> void:
    var fingerprint: String=JSON.stringify(
        current_battle.get("terrain_v57",{}).get("obstacles",[]))
    if fingerprint==obstacle_signature:return
    obstacle_signature=fingerprint
    for node in obstacles_root.get_children():
        obstacles_root.remove_child(node)
        node.free()
    var terrain: Dictionary=current_battle.get("terrain_v57",{})
    if terrain.is_empty():return
    for i in range(terrain.get("obstacles",[]).size()):
        var rock: Dictionary=terrain["obstacles"][i]
        var holder:=Node3D.new()
        holder.name="StoneBoulder_%d" % i
        holder.position=Vector3(float(rock["x"]),0,float(rock["z"]))
        obstacles_root.add_child(holder)
        var stone:=MeshInstance3D.new()
        stone.name="BoulderMesh"
        var mesh:=SphereMesh.new()
        mesh.radius=float(rock["r"])
        mesh.height=float(rock.get("height",2.0))
        mesh.radial_segments=10
        mesh.rings=5
        stone.mesh=mesh
        stone.position.y=float(rock.get("height",2.0))*0.4
        stone.rotation_degrees.y=float(posmod(i*71,180))
        var stone_material:=StandardMaterial3D.new()
        stone_material.albedo_color=Color("#5b5b55").lightened(float(i)*0.035)
        stone_material.roughness=1.0
        stone.material_override=stone_material
        holder.add_child(stone)

func _refresh_projectiles() -> void:
    # Reuse marker meshes between updates; one saved projectile is one 3D stone.
    var active: Dictionary={}
    for stone in current_battle.get("projectiles_v58",[]):
        var label: String="Stone_%d" % int(stone.get("id",0))
        active[label]=true
        var marker: MeshInstance3D=projectiles_root.get_node_or_null(label) as MeshInstance3D
        if marker==null:
            marker=MeshInstance3D.new()
            marker.name=label
            var mesh:=SphereMesh.new()
            mesh.radius=0.18
            mesh.height=0.36
            mesh.radial_segments=8
            mesh.rings=4
            marker.mesh=mesh
            var mat:=StandardMaterial3D.new()
            mat.albedo_color=Color("#68645b")
            mat.roughness=0.95
            marker.material_override=mat
            projectiles_root.add_child(marker)
        marker.position=Vector3(float(stone["x"]),
            float(stone.get("height",1.1)),float(stone["z"]))
    for node in projectiles_root.get_children():
        if active.has(String(node.name)):continue
        projectiles_root.remove_child(node)
        node.free()

func _refresh_move_markers() -> void:
    var needed: Dictionary={}
    for fighter in current_battle.get("fighters",[]):
        if int(fighter.get("team",-1))!=0 or \
                String(fighter.get("mode",""))!="move":continue
        var target: Variant=fighter.get("move_target_v59",null)
        if not target is Dictionary or target.is_empty():continue
        var key: String="Waypoint_%d" % int(fighter["id"])
        needed[key]=true
        var marker: MeshInstance3D=move_markers_root.get_node_or_null(key) as MeshInstance3D
        if marker==null:
            marker=MeshInstance3D.new()
            marker.name=key
            var mesh:=CylinderMesh.new()
            mesh.top_radius=1.5
            mesh.bottom_radius=1.5
            mesh.height=0.12
            marker.mesh=mesh
            var mat:=StandardMaterial3D.new()
            mat.albedo_color=Color("#f1d24d")
            mat.roughness=1.0
            marker.material_override=mat
            move_markers_root.add_child(marker)
        marker.position=Vector3(float(target["x"]),0.12,float(target["z"]))
    # Independent soldier orders use a smaller warm-coloured target marker.
    for fighter in current_battle.get("fighters",[]):
        if int(fighter.get("team",-1))!=0:continue
        for man in fighter.get("men",[]):
            if float(man.get("hp",0.0))<=0.0:continue
            var personal: Variant=man.get("individual_target_v60",null)
            if not personal is Dictionary or personal.is_empty():continue
            var key: String="PersonalWaypoint_%d_%d" % [
                int(fighter["id"]),int(man.get("index",-1))]
            needed[key]=true
            var point: MeshInstance3D=move_markers_root.get_node_or_null(key) as MeshInstance3D
            if point==null:
                point=MeshInstance3D.new()
                point.name=key
                var mesh:=CylinderMesh.new()
                mesh.top_radius=0.7
                mesh.bottom_radius=0.7
                mesh.height=0.18
                point.mesh=mesh
                var mat:=StandardMaterial3D.new()
                mat.albedo_color=Color("#f5ab46")
                mat.roughness=0.9
                point.material_override=mat
                move_markers_root.add_child(point)
            point.position=Vector3(float(personal["x"]),0.2,float(personal["z"]))
    for node in move_markers_root.get_children():
        if needed.has(String(node.name)):continue
        move_markers_root.remove_child(node)
        node.free()

func _zoom(factor: float) -> void:
    cam_size=clampf(cam_size*factor,MIN_BATTLE_ZOOM,MAX_BATTLE_ZOOM)
    if battle_camera!=null:battle_camera.size=cam_size

func set_battle(b: Dictionary,preserve_motion: bool=false) -> void:
    var earlier_elapsed: float=float(current_battle.get("elapsed",-1.0))
    var later_elapsed: float=float(b.get("elapsed",-1.0))
    var elapsed_delta: float=later_elapsed-earlier_elapsed
    # Only animate small automatic simulation advances. The +30 s button,
    # battle restarts and loading a save must immediately show true positions.
    var can_interpolate: bool=auto_play_enabled and earlier_elapsed>=0.0 and \
        elapsed_delta>0.001 and elapsed_delta<1.0 and \
        int(b.get("version",0))>=61 and String(b.get("result",""))==""
    # User commands can update the persistent saved battle without advancing
    # the deterministic clock. In that case keep the currently rendered
    # interpolated soldier transforms instead of snapping the whole army.
    var keep_visual: bool=preserve_motion and auto_play_enabled and \
        absf(elapsed_delta)<0.000001 and earlier_elapsed>=0.0 and \
        String(b.get("result",""))==""
    var blend_seconds: float=clampf(elapsed_delta/Battlefield.SCALE,0.15,0.6)
    current_battle=b.duplicate(true)
    if status_label==null:return
    if String(current_battle.get("result",""))!="":
        set_auto_battle(false)
    if demo_retry_button!=null:
        demo_retry_button.disabled=not (
            bool(current_battle.get("demo_v61",false)) and
            String(current_battle.get("result",""))!="")
    if result_label!=null:
        var finished: String=String(current_battle.get("result",""))
        result_label.visible=finished!=""
        if finished!="":
            var outcome: String="VÕIT" if finished=="victory" else \
                ("TAGANEMINE" if finished=="retreat" else "KAOTUS")
            var restart: String=" Vajuta „Proovilahing uuesti“." if \
                bool(current_battle.get("demo_v61",false)) else \
                " Naase linna või maailmakaardile."
            result_label.text="Lahing on lõppenud — "+outcome+"."+restart
    _refresh_obstacles()
    _refresh_projectiles()
    _refresh_move_markers()
    var existing_id: int=-1
    if order_picker.selected>=0 and order_picker.selected<id_list.size():
        existing_id=id_list[order_picker.selected]
    id_list.clear()
    order_picker.clear()
    var selected_index: int=0
    for fighter in current_battle.get("fighters",[]):
        if int(fighter.get("team",-1))!=0:continue
        var id: int=int(fighter.get("id",-1))
        if id<0:continue
        id_list.append(id)
        order_picker.add_item("#%d %s • %.0f HP" % [
            id,String(fighter["kind"]),float(fighter["hp"])])
        if id==existing_id:selected_index=id_list.size()-1
    if not id_list.is_empty():order_picker.select(selected_index)
    _refresh_individual_picker()
    var label: String="Suur tasuta proovilahing • 5 oma ja 4 vastase väesalka, kokku 216 sõdurit." if \
        bool(current_battle.get("large_demo_v64",false)) else \
        ("Tasuta proovilahing • kolm sõbralikku väesalka, üks vastane; kaotused ei muuda kampaaniat." if \
        bool(current_battle.get("demo_v61",false)) else \
        ("Kampaanialahing • iga sõdur liigub ja võitleb eraldi." if \
            bool(current_battle.get("campaign_v56",false)) else \
            "Harjutuslahing päris sõduritega • kaotused on püsivad."))
    var lines: Array[String]=[label]
    lines.append("Lahinguaeg %.1f s • tulemus: %s" % [
        float(current_battle.get("elapsed",0)),
        "käimas" if current_battle.get("result","")=="" else String(current_battle["result"])])
    if bool(current_battle.get("demo_v61",false)):
        lines.append("▶ Automaatvõitlus" if auto_play_enabled else
            "⏸ Paus — võid anda käsklusi või vajutada ▶")
    for fighter in current_battle.get("fighters",[]):
        lines.append("%s %s %.0f/%.0f HP • %s (%d sõdurit)" % [
            "Sinu" if int(fighter["team"])==0 else "Vastane",
            String(fighter["kind"]),float(fighter["hp"]),float(fighter["max_hp"]),
            String(fighter.get("mode","")),int(fighter.get("menAlive",0))])
    var chosen: Dictionary=_chosen_man()
    if not chosen.is_empty():
        lines.append("Valitud sõdur: #%d:%d" % [
            int(chosen["squad"]),int(chosen["index"])+1])
        var pinned: Dictionary=_selected_attack_target_v68()
        if not pinned.is_empty():
            lines.append("Sihitud vastane: #%d:%d" % [
                int(pinned["squad"]),int(pinned["index"])+1])
        var target_squad: int=_selected_squad_target_v71()
        if target_squad!=-999999:
            lines.append("Väesalk ründab: #%d" % target_squad)
    status_label.text=" | ".join(lines)
    status_label.tooltip_text=status_label.text
    var used: Dictionary={}
    var total: int=0
    for fighter in current_battle.get("fighters",[]):
        if float(fighter.get("hp",0))<=0 or fighter.get("mode","")=="retreated":
            continue
        var kind: String=String(fighter.get("kind",""))
        var men: Array=fighter.get("men",[])
        if men.is_empty():
            men=[{"index":0,"x":fighter["x"],"z":fighter["z"],
                "hp":fighter["hp"],"escaped":false,"heading":0.0}]
        for man in men:
            if float(man.get("hp",0))<=0 or bool(man.get("escaped",false)):
                continue
            if total>=216:break
            var key: String="TacticalMan_%d_%d" % [
                int(fighter["id"]),int(man.get("index",0))]
            var holder: Node3D=actors_root.get_node_or_null(key) as Node3D
            if holder==null:
                var model: Node3D=Units.instance(kind,5.2,false,true)
                if model==null:continue
                holder=Node3D.new()
                holder.name=key
                holder.set_meta("source_id",int(fighter["source_id"]))
                actors_root.add_child(holder)
                holder.add_child(model)
                var foot:=CylinderMesh.new()
                foot.top_radius=0.39
                foot.bottom_radius=0.39
                foot.height=0.10
                var marker:=MeshInstance3D.new()
                marker.name="TeamMarker"
                marker.mesh=foot
                marker.position.y=0.04
                var mat:=StandardMaterial3D.new()
                mat.albedo_color=Color("#65caff") if int(fighter["team"])==0 else Color("#ed6b56")
                marker.material_override=mat
                holder.add_child(marker)
            holder.set_meta("team_v67",int(fighter["team"]))
            holder.set_meta("squad_v67",int(fighter["id"]))
            holder.set_meta("person_v67",int(man.get("index",0)))
            var team_marker: MeshInstance3D=holder.get_node_or_null("TeamMarker") as MeshInstance3D
            if team_marker!=null:
                var base_material: StandardMaterial3D=team_marker.material_override as StandardMaterial3D
                if base_material!=null:
                    var is_selected: bool=not chosen.is_empty() and \
                        int(fighter["team"])==0 and \
                        int(fighter["id"])==int(chosen["squad"]) and \
                        int(man.get("index",-1))==int(chosen["index"])
                    base_material.albedo_color=Color("#ffe250") if is_selected else \
                        (Color("#65caff") if int(fighter["team"])==0 else Color("#ed6b56"))
            var target_position:=Vector3(float(man["x"]),0.0,float(man["z"]))
            var target_heading: float=float(man.get("heading",
                PI*0.5 if int(fighter["team"])==0 else -PI*0.5))
            var model_node: Node3D=holder.get_child(0) as Node3D
            # A new battle can reuse the same soldier IDs before the corpse
            # lifetime expires. Restore the living model without duplicates.
            if holder.has_meta("fallen_since_v69"):
                holder.remove_meta("fallen_since_v69")
                holder.remove_meta("death_clip_v69")
                if team_marker!=null:team_marker.show()
                holder.position=target_position
                holder.rotation.y=target_heading
                if model_node!=null:
                    Animation65.apply(model_node,man,kind)
            if int(current_battle.get("version",0))>=61:
                var previous: Dictionary=holder.get_meta("interpolation_v63",{})
                if keep_visual and not previous.is_empty():
                    previous["person"]=man.duplicate(true)
                    previous["kind"]=kind
                    previous["idle_pose_ready_v92"]=false
                    holder.set_meta("interpolation_v63",previous)
                else:
                    # V77: keep the same actor interpolation even for a >12 m
                    # correction. Snapping to the target made a visible
                    # teleport precisely when crowds engage in melee.
                    var smooth: bool=can_interpolate and not previous.is_empty()
                    if not smooth:
                        holder.position=target_position
                        holder.rotation.y=target_heading
                    var velocity: Vector3=Vector3.ZERO
                    if smooth:
                        velocity=(target_position-previous.get("target",holder.position))/\
                            blend_seconds
                    holder.set_meta("interpolation_v63",{
                        "origin":holder.position,"target":target_position,
                        "from_heading":holder.rotation.y,"to_heading":target_heading,
                        "fraction":0.0 if smooth else 1.0,
                        "duration":blend_seconds if smooth else 0.01,
                        "velocity":velocity,
                        "move_active":bool(man.get("moving",false)) or \
                            velocity.length_squared()>0.01,
                        "phase":float(previous.get("phase",man.get("anim_phase",0.0))) if smooth else \
                            float(man.get("anim_phase",0.0)),
                        "attack_clock":maxf(float(man.get("attack_anim",0.0)),
                            float(previous.get("attack_clock",0.0))) if smooth else \
                            float(man.get("attack_anim",0.0)),
                        "hit_clock":maxf(float(man.get("hit_anim_v61",0.0)),
                            float(previous.get("hit_clock",0.0))) if smooth else \
                            float(man.get("hit_anim_v61",0.0)),
                        "person":man.duplicate(true),"kind":kind})
                    if not smooth and model_node!=null:
                        Animation65.apply(model_node,man,kind)
            else:
                holder.position=target_position
                holder.rotation.y=target_heading
                if model_node!=null:
                    var phase: float=float(man.get("anim_phase",0.0))
                    var walking: bool=bool(man.get("moving",false))
                    var attacking: float=float(man.get("attack_anim",0.0))
                    model_node.position.y=absf(sin(phase))*0.12 if walking else 0.0
                    model_node.rotation.x=-0.27*sin(attacking/0.36*PI) if attacking>0.0 else 0.0
                    model_node.rotation.z=0.065*sin(phase) if walking else 0.0
            used[key]=true
            total+=1
    _refresh_selection_markers_v67()
    var animate_fallen: bool=int(current_battle.get("version",0))>=69 and \
        earlier_elapsed>=0.0 and elapsed_delta>=0.0 and \
        elapsed_delta<1.0
    for node in actors_root.get_children():
        if used.has(String(node.name)):continue
        if node.has_meta("fallen_since_v69"):continue
        if animate_fallen and _fallen_in_battle_v69(node):
            _start_fallen_v69(node)
            continue
        actors_root.remove_child(node)
        node.free()
