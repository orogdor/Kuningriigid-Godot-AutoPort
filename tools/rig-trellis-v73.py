#!/usr/bin/env python3
"""Bind unrigged V262 TRELLIS.2 warrior geometry to the original V148 animated glTF rig.

No Blender dependencies or per-soldier runtime rig computation. Copy the original
animation channels, bone hierarchy and inverse bind matrices byte-for-byte, replace
only the mesh primitives with textured V262 geometry and generated skin weights.
Both materials and animations are retained in a single reusable GLB per unit.
"""
import argparse
import copy
import hashlib
import json
import math
import statistics
import struct
from pathlib import Path

SOURCES = {"axeman": "kirvemees", "spearman": "odamees", "slinger": "lingmees"}
JSON_CHUNK = b"JSON"
BIN_CHUNK = b"BIN\0"


def pad4(payload: bytes, fill: bytes = b"\0") -> bytes:
    return payload + fill * ((-len(payload)) % 4)


def load_glb(path):
    raw = Path(path).read_bytes()
    if len(raw) < 28:
        raise ValueError(f"{path}: GLB too short")
    magic, version, total = struct.unpack_from("<4sII", raw)
    if magic != b"glTF" or version != 2 or total != len(raw):
        raise ValueError(f"{path}: invalid GLB header")
    offset = 12
    chunks = {}
    while offset < len(raw):
        length, kind = struct.unpack_from("<I4s", raw, offset)
        offset += 8
        payload = raw[offset:offset+length]
        if len(payload) != length:
            raise ValueError(f"{path}: truncated GLB chunk")
        chunks[kind] = payload
        offset += length
    if JSON_CHUNK not in chunks or BIN_CHUNK not in chunks:
        raise ValueError(f"{path}: expected JSON and BIN chunks")
    return json.loads(chunks[JSON_CHUNK]), bytearray(chunks[BIN_CHUNK])


def save_glb(path, document, binary):
    binary = bytearray(pad4(bytes(binary)))
    document["buffers"][0]["byteLength"] = len(binary)
    json_bytes = pad4(json.dumps(
        document, ensure_ascii=False, separators=(",", ":")).encode(), b" ")
    data = (struct.pack("<4sII", b"glTF", 2, 12+8+len(json_bytes)+8+len(binary))
            + struct.pack("<I4s", len(json_bytes), JSON_CHUNK) + json_bytes
            + struct.pack("<I4s", len(binary), BIN_CHUNK) + binary)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(data)
    return data


def vectors(document, binary, accessor_id):
    accessor = document["accessors"][accessor_id]
    if accessor["componentType"] != 5126 or accessor["type"] != "VEC3":
        raise ValueError("Expected float32 VEC3 positions/normals")
    view = document["bufferViews"][accessor["bufferView"]]
    base = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", 12)
    return [struct.unpack_from("<fff", binary, base + i*stride)
            for i in range(accessor["count"])], base, stride


def vadd(a,b): return (a[0]+b[0],a[1]+b[1],a[2]+b[2])
def vsub(a,b): return (a[0]-b[0],a[1]-b[1],a[2]-b[2])
def vmul(a,s): return (a[0]*s,a[1]*s,a[2]*s)
def dot(a,b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def norm2(a): return dot(a,a)


def qmul(a,b):
    ax,ay,az,aw=a
    bx,by,bz,bw=b
    return (aw*bx+ax*bw+ay*bz-az*by,
            aw*by-ay*bw+az*bx-ax*bz,
            aw*bz+az*bw+ax*by-ay*bx,
            aw*bw-ax*bx-ay*by-az*bz)


def qrot(q,v):
    xyz=q[:3]
    cross=(xyz[1]*v[2]-xyz[2]*v[1],
           xyz[2]*v[0]-xyz[0]*v[2],
           xyz[0]*v[1]-xyz[1]*v[0])
    outer=(xyz[1]*cross[2]-xyz[2]*cross[1],
           xyz[2]*cross[0]-xyz[0]*cross[2],
           xyz[0]*cross[1]-xyz[1]*cross[0])
    return vadd(v,vmul(vadd(vmul(cross,q[3]),outer),2.0))


def bind_segments(doc):
    nodes = doc["nodes"]
    skin = doc["skins"][0]
    parents = {}
    for i, node in enumerate(nodes):
        for child in node.get("children", []):
            parents[child] = i
    memo = {}
    def world(i):
        if i in memo: return memo[i]
        node = nodes[i]
        loc = tuple(node.get("translation", (0.,0.,0.)))
        rot = tuple(node.get("rotation", (0.,0.,0.,1.)))
        if i in parents:
            parent_pos,parent_rot=world(parents[i])
            loc=vadd(parent_pos,qrot(parent_rot,loc))
            rot=qmul(parent_rot,rot)
        memo[i]=(loc,rot)
        return memo[i]
    positions = {node_id:world(node_id)[0] for node_id in skin["joints"]}
    output = []
    for index,node_id in enumerate(skin["joints"]):
        name = nodes[node_id].get("name","")
        if name == "root": continue
        start = positions[node_id]
        child_bones = [c for c in nodes[node_id].get("children", []) if c in positions]
        if child_bones:
            end = tuple(sum(positions[c][k] for c in child_bones)/len(child_bones)
                        for k in range(3))
        elif name == "head":
            end = vadd(start,(0.,.22,0.))
        elif name.startswith("shin"):
            end = vadd(start,(0.,-.43,.045))
        elif name.startswith("hand"):
            end = vadd(start,(0.,-.12,.02))
        else:
            end = vadd(start,(0.,.15,0.))
        side = "L" if name.endswith("_L") else "R" if name.endswith("_R") else None
        output.append((index,name,side,start,end))
    return output, len(skin["joints"])


def distance_to_segment(point,a,b):
    delta = vsub(b,a)
    t = max(0.,min(1.,dot(vsub(point,a),delta)/max(norm2(delta),1.e-10)))
    return math.sqrt(norm2(vsub(point,vadd(a,vmul(delta,t)))))


def model_positions(doc,old_doc,new_binary,kind):
    primitive = doc["meshes"][0]["primitives"][0]
    old_max = max(a["max"][1] for mesh in old_doc["meshes"]
                  for item in mesh["primitives"]
                  for a in [old_doc["accessors"][item["attributes"]["POSITION"]]])
    old_min = min(a["min"][1] for mesh in old_doc["meshes"]
                  for item in mesh["primitives"]
                  for a in [old_doc["accessors"][item["attributes"]["POSITION"]]])
    raw,offset,stride = vectors(doc,new_binary,primitive["attributes"]["POSITION"])
    raw_min_y = min(p[1] for p in raw)
    raw_max_y = max(p[1] for p in raw)
    scale = (old_max-old_min) / max(raw_max_y-raw_min_y,1e-8)
    # The V262 slinger is authored in profile and rotated in the V299 web renderer.
    turn = -math.pi/2 if kind == "slinger" else 0.
    cos_t,sin_t=math.cos(turn),math.sin(turn)
    turned=[(cos_t*x+sin_t*z,y,-sin_t*x+cos_t*z) for x,y,z in raw]
    # Center on the torso, rather than the asymmetric weapon bounding box.
    mid=[p for p in turned if raw_min_y+.62*(raw_max_y-raw_min_y) < p[1]
         < raw_min_y+.82*(raw_max_y-raw_min_y)]
    center_x=statistics.median(p[0] for p in mid) if mid else 0.
    center_z=statistics.median(p[2] for p in mid) if mid else 0.
    coords=[((x-center_x)*scale,(y-raw_min_y)*scale+old_min,
             (z-center_z)*scale) for x,y,z in turned]
    for i,p in enumerate(coords):
        struct.pack_into("<fff",new_binary,offset+i*stride,*p)
    accessor=doc["accessors"][primitive["attributes"]["POSITION"]]
    accessor["min"]=[min(p[k] for p in coords) for k in range(3)]
    accessor["max"]=[max(p[k] for p in coords) for k in range(3)]
    normal,normal_offset,normal_stride=vectors(
        doc,new_binary,primitive["attributes"]["NORMAL"])
    if turn:
        for i,(x,y,z) in enumerate(normal):
            struct.pack_into("<fff",new_binary,normal_offset+i*normal_stride,
                             cos_t*x+sin_t*z,y,-sin_t*x+cos_t*z)
    return coords


def shaft_line(vertices,scale_height):
    # The spear is a rigid object; do not blend its butt into boot/thigh bones.
    top=[p for p in vertices if p[0] < -.23*scale_height
         and p[1] > .75*scale_height]
    bottom=[p for p in vertices if p[0] < -.23*scale_height
            and .06*scale_height < p[1] < .3*scale_height]
    if not top or not bottom:return None
    a=tuple(sum(p[i] for p in bottom)/len(bottom) for i in range(3))
    b=tuple(sum(p[i] for p in top)/len(top) for i in range(3))
    return a,b


def skin_weights(vertices,old_doc,kind):
    segments,num_joints=bind_segments(old_doc)
    if num_joints < 12:
        raise ValueError("Source V148 Skeleton3D has unexpectedly few joints")
    hand={name:i for i,name,_,_,_ in segments if name.startswith("hand_")}
    height=max(p[1] for p in vertices)-min(p[1] for p in vertices)
    shaft=shaft_line(vertices,height) if kind=="spearman" else None
    weights,joints=[],[]
    used=set()
    for p in vertices:
        chosen=None
        if shaft and distance_to_segment(p,*shaft)<.040*height and \
                p[1]>.10*height:
            chosen=[(hand["hand_R"],1.0)]
        # Some generated weapons protrude far outside the body and must
        # remain rigid in the gripping hand, not collapse into the elbow.
        if chosen is None and abs(p[0])>.34*height and p[1]>.51*height:
            side="hand_L" if p[0]>0 else "hand_R"
            chosen=[(hand[side],1.0)]
        if chosen is None:
            ranked=[]
            for joint_id,name,side,a,b in segments:
                if side and abs(p[0])>.025*height and \
                        (p[0]>0)!=(side=="L"):
                    continue
                is_arm = ("Arm" in name or "forearm" in name or "hand" in name)
                if is_arm and abs(p[0])<.09*height:continue
                if is_arm and p[1]<.48*height:continue
                if ("thigh" in name or "shin" in name) and p[1]>.70*height:
                    continue
                d=distance_to_segment(p,a,b)
                if name=="body" and p[1]<a[1]-.06:d+=.06
                ranked.append((d,joint_id))
            ranked.sort()
            if not ranked:
                raise ValueError("No bones can influence generated vertex")
            ranked=ranked[:3]
            unscaled=[1.0/(d+.025)**4 for d,_ in ranked]
            total=sum(unscaled)
            chosen=[(joint_id,amount/total)
                    for (d,joint_id),amount in zip(ranked,unscaled)]
        joint=[0,0,0,0]
        weight=[0.,0.,0.,0.]
        for i,(bone,w) in enumerate(chosen):
            joint[i]=bone
            weight[i]=w
            used.add(bone)
        joints.extend(joint)
        weights.extend(weight)
    if len(used)<6:
        raise ValueError("Rig influences too few bones: "+repr(used))
    return joints,weights,len(used)


def read_accessor(doc, binary, accessor_id):
    """Read a legacy GLB accessor including optional interleaved strides."""
    accessor = doc["accessors"][accessor_id]
    view = doc["bufferViews"][accessor["bufferView"]]
    components = {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}[accessor["type"]]
    fmt = {5121:"B",5123:"H",5125:"I",5126:"f"}[accessor["componentType"]]
    item_format = "<"+fmt*components
    item_size = struct.calcsize(item_format)
    stride = view.get("byteStride",item_size)
    offset = view.get("byteOffset",0)+accessor.get("byteOffset",0)
    values = [struct.unpack_from(item_format,binary,offset+i*stride)
              for i in range(accessor["count"])]
    if components==1:
        return [value[0] for value in values]
    return values


def copy_intact_v148_spear(doc, binary):
    """Keep all shaft and tip triangles rigid on hand_R; no guessed skin weights.

    The legacy V148 spear is authored as real, unbroken geometry on one bone,
    whereas the V262 photogrammetry spear is only a rough fragment. Filtering
    by 100% hand_R skin influence separates the original shaft and point from
    the character's torso, clothing and animated limbs.
    """
    original = doc["meshes"][0]["primitives"][0]
    attributes = original["attributes"]
    positions = read_accessor(doc,binary,attributes["POSITION"])
    joints = read_accessor(doc,binary,attributes["JOINTS_0"])
    weights = read_accessor(doc,binary,attributes["WEIGHTS_0"])
    indices = read_accessor(doc,binary,original["indices"])
    hand_node = next((i for i,node in enumerate(doc["nodes"])
                      if node.get("name")=="hand_R"),None)
    if hand_node is None:
        raise ValueError("V148 spear has no right-hand attachment bone")
    hand = doc["skins"][0]["joints"].index(hand_node)
    def rigid_on_hand(index):
        influences = weights[index]
        strongest = max(range(4),key=lambda k:influences[k])
        return joints[index][strongest]==hand and influences[strongest]>=0.90
    selected = []
    for k in range(0,len(indices),3):
        tri = indices[k:k+3]
        if all(rigid_on_hand(index) for index in tri):
            selected.extend(tri)
    if len(selected)<450:
        raise ValueError("Source spear tip or shaft is missing: too few triangles")
    z = [positions[index][2] for index in selected]
    if min(z)>-0.65 or max(z)<1.25:
        raise ValueError("Source spear must include complete butt, shaft and tip")
    return original, selected


def append_view(doc,binary,payload):
    binary.extend(b"\0"*((-len(binary))%4))
    offset=len(binary)
    binary.extend(pad4(payload))
    index=len(doc["bufferViews"])
    doc["bufferViews"].append({"buffer":0,"byteOffset":offset,
                               "byteLength":len(payload)})
    return index


def merge(kind,old_path,new_path,destination):
    old_doc,old_binary=load_glb(old_path)
    new_doc,new_binary=load_glb(new_path)
    if len(old_doc.get("skins",[]))!=1 or len(new_doc.get("meshes",[]))!=1:
        raise ValueError(f"{kind}: unexpected source rig/mesh count")
    if new_doc.get("skins") or new_doc.get("animations"):
        raise ValueError(f"{kind}: expected unrigged V262 geometry")
    if len(old_doc.get("animations",[]))<6:
        raise ValueError(f"{kind}: old attack/death animations not found")
    positions=model_positions(new_doc,old_doc,new_binary,kind)
    joints,weights,used=skin_weights(positions,old_doc,kind)
    result=copy.deepcopy(old_doc)
    binary=bytearray(old_binary)
    binary.extend(b"\0"*((-len(binary))%4))
    start=len(binary)
    binary.extend(new_binary)
    view_shift=len(result["bufferViews"])
    accessor_shift=len(result["accessors"])
    sampler_shift=len(result.get("samplers",[]))
    image_shift=len(result.get("images",[]))
    texture_shift=len(result.get("textures",[]))
    material_shift=len(result.get("materials",[]))
    for view in new_doc["bufferViews"]:
        item=copy.deepcopy(view)
        item["buffer"]=0
        item["byteOffset"]=start+item.get("byteOffset",0)
        result["bufferViews"].append(item)
    for accessor in new_doc["accessors"]:
        item=copy.deepcopy(accessor)
        item["bufferView"]+=view_shift
        result["accessors"].append(item)
    result.setdefault("samplers",[]).extend(copy.deepcopy(new_doc.get("samplers",[])))
    for image in new_doc.get("images",[]):
        item=copy.deepcopy(image)
        if "bufferView" in item:item["bufferView"]+=view_shift
        result.setdefault("images",[]).append(item)
    for texture in new_doc.get("textures",[]):
        item=copy.deepcopy(texture)
        if "sampler" in item:item["sampler"]+=sampler_shift
        if "source" in item:item["source"]+=image_shift
        for ext in item.get("extensions",{}).values():
            if "source" in ext:ext["source"]+=image_shift
        result.setdefault("textures",[]).append(item)
    for material in new_doc.get("materials",[]):
        item=copy.deepcopy(material)
        for slot in ("baseColorTexture","metallicRoughnessTexture"):
            if slot in item.get("pbrMetallicRoughness",{}):
                item["pbrMetallicRoughness"][slot]["index"]+=texture_shift
        for slot in ("normalTexture","occlusionTexture","emissiveTexture"):
            if slot in item:item[slot]["index"]+=texture_shift
        result.setdefault("materials",[]).append(item)
    for key in ("extensionsUsed","extensionsRequired"):
        values=result.setdefault(key,[])
        for extension in new_doc.get(key,[]):
            if extension not in values:values.append(extension)
    joint_view=append_view(result,binary,struct.pack("<"+"H"*len(joints),*joints))
    weight_view=append_view(result,binary,struct.pack("<"+"f"*len(weights),*weights))
    vertex_count=len(positions)
    joint_accessor=len(result["accessors"])
    result["accessors"].append({"bufferView":joint_view,"byteOffset":0,
        "componentType":5123,"count":vertex_count,"type":"VEC4"})
    weight_accessor=len(result["accessors"])
    result["accessors"].append({"bufferView":weight_view,"byteOffset":0,
        "componentType":5126,"count":vertex_count,"type":"VEC4"})
    primitives=[]
    for src in new_doc["meshes"][0]["primitives"]:
        p=copy.deepcopy(src)
        p["indices"]+=accessor_shift
        p["attributes"]={key:value+accessor_shift
                         for key,value in src["attributes"].items()}
        p["attributes"]["JOINTS_0"]=joint_accessor
        p["attributes"]["WEIGHTS_0"]=weight_accessor
        if "material" in p:p["material"]+=material_shift
        primitives.append(p)
    intact_spear_triangles=0
    if kind=="spearman":
        # The old V148 spear is rigid on right-hand bone 9. Reuse its intact
        # shaft and tip as a second skinned surface; never stretch a spear
        # point between torso/forearm/hand bones via nearest-bone guesses.
        original,selected=copy_intact_v148_spear(old_doc,old_binary)
        index_view=append_view(result,binary,
            struct.pack("<"+"H"*len(selected),*selected))
        index_accessor=len(result["accessors"])
        result["accessors"].append({
            "bufferView":index_view, "byteOffset":0,
            "componentType":5123, "count":len(selected), "type":"SCALAR",
            "min":[min(selected)],"max":[max(selected)]})
        intact_primitive=copy.deepcopy(original)
        intact_primitive["indices"]=index_accessor
        primitives.append(intact_primitive)
        intact_spear_triangles=len(selected)//3
    result["meshes"][0]["primitives"]=primitives
    result["meshes"][0]["name"]=kind+"_V262_TRELLIS_RIGGED_V77"
    result.setdefault("extras",{})["autoportV73"]={
        "geometry":"models-trellis-v262", "skeleton":"models-v148/glb",
        "unit":kind, "weightedBones":used,
        "intactSpearTrianglesV77":intact_spear_triangles}
    content=save_glb(destination,result,binary)
    verify_doc,_=load_glb(destination)
    if len(verify_doc["animations"]) != len(old_doc["animations"]):
        raise ValueError("Rig transfer lost original animation channels")
    for p in verify_doc["meshes"][0]["primitives"]:
        if not {"JOINTS_0","WEIGHTS_0","TEXCOORD_0"}.issubset(p["attributes"]):
            raise ValueError("Rigged mesh has no bones, weights or source texture")
    return {"bytes":len(content),"sha256":hashlib.sha256(content).hexdigest(),
            "source_mesh_sha256":hashlib.sha256(Path(new_path).read_bytes()).hexdigest(),
            "rig_sha256":hashlib.sha256(Path(old_path).read_bytes()).hexdigest(),
            "vertices":vertex_count,"animations":[a.get("name","") for a in old_doc["animations"]],
            "weighted_bones":used,"skins":1,
            "intact_spear_triangles_v77":intact_spear_triangles}


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--legacy",required=True)
    p.add_argument("--trellis",required=True)
    p.add_argument("--out",required=True)
    p.add_argument("--commit",required=True)
    args=p.parse_args()
    out=Path(args.out)
    out.mkdir(parents=True,exist_ok=True)
    manifest={"source_repository":"orogdor/Kuningriigid",
              "source_commit":args.commit,"models":{}}
    for kind in SOURCES:
        old=Path(args.legacy)/(kind+".glb")
        new=Path(args.trellis)/(kind+".glb")
        if not old.is_file() or not new.is_file():
            raise FileNotFoundError(f"Missing V148/V262 asset: {old} / {new}")
        info=merge(kind,old,new,out/(kind+".glb"))
        manifest["models"][kind]=info
        print("RIGGED_TRELLIS_V73",kind,info["vertices"],"vertices,",
              info["weighted_bones"],"weighted bones,",
              len(info["animations"]),"source animations")
    (out/"manifest.json").write_text(
        json.dumps(manifest,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print("RIGGED_TRELLIS_V73 SUCCESS: 3 textured warriors retain original V148 skeleton and animations")


if __name__ == "__main__":
    main()
