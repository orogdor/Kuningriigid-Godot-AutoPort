extends RefCounted
## 0.38 — player-controlled capital AI. Keeps emergent roads intact.
const City=preload("res://scripts/city_sim_v05.gd")
const Spatial=preload("res://scripts/spatial_economy_v08.gd")
const Planner=preload("res://scripts/city_planner_v24.gd")
const BronzePlan=preload("res://scripts/bronze_city_ai_v37.gd")
const INTERVAL: int=3

static func enabled(state: Dictionary) -> bool:
    return bool(state.get("capital_ai_v38",{}).get("enabled",false))

static func set_enabled(state: Dictionary,on: bool) -> void:
    var ai: Dictionary=state.get("capital_ai_v38",{})
    ai["enabled"]=on
    if not ai.has("next_turn"):ai["next_turn"]=0
    if not ai.get("history",[]) is Array:ai["history"]=[]
    state["capital_ai_v38"]=ai
    if on:
        # Existing workers, terrain, paths and roads survive initialization.
        Spatial.initialize(state)

static func step(state: Dictionary) -> String:
    if not enabled(state) or bool(state.get("ended",false)):return ""
    if not state.has("research_v35") or not state.has("realms"):return ""
    var ai: Dictionary=state["capital_ai_v38"]
    var turn: int=int(float(state.get("time",0.0))/60.0)
    if turn<int(ai.get("next_turn",0)):return ""
    ai["next_turn"]=turn+INTERVAL
    for b in state.get("buildings",[]):
        if not bool(b.get("ready",false)):return ""
    Spatial.initialize(state)
    var kind: String=BronzePlan.choose(state,City.definitions())
    if kind=="":return ""
    var plan: Dictionary=Planner.plan(state,kind)
    if plan.is_empty():return ""
    var pos: Vector2=plan["position"]
    state["pending_site"]={
        "x":pos.x,"z":pos.y,"rotation":int(plan.get("rotation",0))
    }
    var outcome: String=City.build(state,kind)
    state.erase("pending_site")
    if outcome!="":return ""
    var history: Array=ai.get("history",[])
    history.append({"turn":turn,"type":kind,"x":pos.x,"z":pos.y,
        "rotation":int(plan.get("rotation",0)),"age":int(state.get("age",0))})
    if history.size()>30:history.pop_front()
    ai["history"]=history
    return kind

static func summary(state: Dictionary) -> String:
    var ai: Dictionary=state.get("capital_ai_v38",{})
    var history: Array=ai.get("history",[])
    var setting: String="sees" if enabled(state) else "väljas"
    if history.is_empty():return "Pealinna ehitus-AI: "+setting+" | Veel ehitamata"
    var last: Dictionary=history[history.size()-1]
    return "Pealinna ehitus-AI: %s | %d plaani | Viimane: %s (%d, %d m)" % [
        setting,history.size(),String(last.get("type","")),
        int(last.get("x",0)),int(last.get("z",0))]
