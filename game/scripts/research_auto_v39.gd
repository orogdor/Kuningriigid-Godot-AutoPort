extends RefCounted
## AutoPort 0.39: optional national research autopilot.
## Resolves actual upstream tech dependencies recursively, including oneOf
## alternatives and the Bronze age gate. Never grants free science or stock.
const Research=preload("res://scripts/research_v35.gd")
const TARGETS: Array[String]=[
    "stone_tools","water","agriculture","bronze",
    "woodworking","milling","storage","commerce","cellaring",
    "bronze_crafts","wheel","road_construction","bridges",
    "fortifications","animal_husbandry","writing","shipbuilding"
]

static func enabled(state: Dictionary) -> bool:
    return bool(state.get("research_ai_v39",{}).get("enabled",false))

static func set_enabled(state: Dictionary,active: bool) -> void:
    var data: Dictionary=state.get("research_ai_v39",{})
    data["enabled"]=active
    if not data.get("history",[]) is Array:data["history"]=[]
    state["research_ai_v39"]=data

static func _next(state: Dictionary,target: String,seen: Dictionary) -> String:
    var catalog: Dictionary=Research.catalog()
    if seen.has(target) or not catalog.has(target):return ""
    seen[target]=true
    var known: Array=Research.ensure(state)["known"]
    if known.has(target):return ""
    var spec: Dictionary=catalog[target]
    if int(spec.get("age",0))>1:return ""
    # Age-1 technologies (except the Bronze transition itself) depend on
    # bronze even if the generated tech has no explicit Bronze edge.
    if int(spec.get("age",0))>0 and target!="bronze" and not known.has("bronze"):
        var earlier: String=_next(state,"bronze",seen)
        if earlier!="":return earlier
        if not known.has("bronze"):return ""
    for prerequisite in spec.get("requires",[]):
        var required: String=String(prerequisite)
        if known.has(required):continue
        var dependency: String=_next(state,required,seen)
        if dependency!="":return dependency
        if not known.has(required):return ""
    var one_of: Array=spec.get("oneOf",[])
    if not one_of.is_empty():
        var resolved: bool=false
        for candidate in one_of:
            if known.has(String(candidate)):
                resolved=true
                break
        if not resolved:
            # Prefer the low-cost early Stone Age hunting branch where legal.
            var alternatives: Array=one_of.duplicate()
            alternatives.sort_custom(func(a,b):return Research.cost(String(a))<Research.cost(String(b)))
            for candidate in alternatives:
                var alternative: String=_next(state,String(candidate),seen)
                if alternative!="":return alternative
            return ""
    if Research.block(state,target)=="":return target
    return ""

static func next_discovery(state: Dictionary) -> String:
    if int(state.get("age",0))>1:return ""
    for objective in TARGETS:
        var candidate: String=_next(state,objective,{})
        if candidate!="":return candidate
    return ""

static func step(state: Dictionary) -> String:
    if not enabled(state) or bool(state.get("ended",false)):return ""
    if not state.has("research_v35"):return ""
    var research: Dictionary=Research.ensure(state)
    # Respect player-created work, accumulated progress and the atomic Bronze
    # materials wait. Do not cancel, advance or replace active research.
    if String(research.get("active",""))!="":return ""
    var id: String=next_discovery(state)
    if id=="" or Research.start(state,id)!="":return ""
    var data: Dictionary=state["research_ai_v39"]
    var entries: Array=data.get("history",[])
    entries.append({"id":id,"time":float(state.get("time",0.0))})
    if entries.size()>30:entries.pop_front()
    data["history"]=entries
    return id

static func summary(state: Dictionary) -> String:
    var setting: String="sees" if enabled(state) else "väljas"
    var active: String=String(state.get("research_v35",{}).get("active",""))
    var item: String=Research.name_of(active) if active!="" else "Uuringut pole"
    var waiting: String=String(state.get("research_v35",{}).get("age_wait",""))
    if waiting!="":return "Teadus-AI: %s | %s" % [setting,waiting]
    return "Teadus-AI: %s | %s" % [setting,item]
