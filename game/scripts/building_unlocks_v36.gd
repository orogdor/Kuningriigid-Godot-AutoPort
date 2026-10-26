extends RefCounted
## AutoPort 0.36: national construction research gates from upstream BUILD_TECH.
## Legacy 0.5 test states without research_v35 retain unchanged parity.
const Rules=preload("res://scripts/generated_rules.gd")
const REQUIRED: Dictionary={
    "quarry":"stone_tools","well":"water","farm":"agriculture",
    "saw":"woodworking","mill":"milling","bakery":"milling",
    "market":"commerce","warehouse":"storage","cellar":"cellaring",
    "vegetable_garden":"agriculture"
}

static func technology(kind: String) -> String:
    return String(REQUIRED.get(kind,""))

static func block(state: Dictionary,kind: String) -> String:
    var id: String=technology(kind)
    if id=="" or not state.has("research_v35"):return ""
    var research: Variant=state["research_v35"]
    if not research is Dictionary:return "Riigi uurimisseisund puudub."
    var known: Variant=research.get("known",[])
    if not known is Array:return "Riigi uurimisseisund puudub."
    if known.has(id):return ""
    var specs: Dictionary=Rules.read_table("tech_tree")
    return "Enne tuleb uurida: "+String(specs.get(id,{}).get("name",id))

static func allowed(state: Dictionary,kind: String) -> bool:
    return block(state,kind)==""
