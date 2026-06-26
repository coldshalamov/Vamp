#!/usr/bin/env python3
"""render_hero_clay.py — render the proportioned hero as rough CLAY frames.

Run headless:
    blender --background --python tools/visual/render_hero_clay.py -- --out <dir>

Builds the Rigify-proportioned hero (skin-modifier body + fitted longcoat + head
with hair/face structure), poses it across an animation set (idle + walk cycle +
attack), rotates through the facing directions, and renders rough grey/clay PNGs
from the 3/4 game camera. These clay frames are NOT the final art — each is
repainted into the VtM style by `agy` (see docs/CHARACTER_PIPELINE_SPEC.md §5b).
Clay frames only need correct pose/angle/proportion/silhouette.

Output: <dir>/clay_d<dir>_p<pose>.png  (transparent bg) + a manifest.json.
"""
from __future__ import annotations
import bpy, sys, os, math, json, argparse
from mathutils import Vector

# --- proportioned skeleton (Rigify-derived) ----------------------------------
# verts: 0 hipC 1 chest 2 neck 3 head  | 4-6 L arm  7-9 R arm | 10-12 L leg 13-15 R leg
BASE = [(0,0,1.02),(0,0,1.30),(0,0,1.46),(0,-0.02,1.66),
        (0.175,0,1.55),(0.205,0.02,1.24),(0.235,0.05,0.96),
        (-0.175,0,1.55),(-0.205,0.02,1.24),(-0.235,0.05,0.96),
        (0.10,0,1.04),(0.10,0.02,0.55),(0.105,0.04,0.09),
        (-0.10,0,1.04),(-0.10,0.02,0.55),(-0.105,0.04,0.09)]
EDGES = [(0,1),(1,2),(2,3),(1,4),(4,5),(5,6),(1,7),(7,8),(8,9),
         (0,10),(10,11),(11,12),(0,13),(13,14),(14,15)]
RAD = {0:0.135,1:0.150,2:0.060,3:0.050,4:0.072,5:0.050,6:0.038,7:0.072,8:0.050,9:0.038,
       10:0.092,11:0.066,12:0.050,13:0.092,14:0.066,15:0.050}

# animation poses: idle, walk0..3, attack  (10fps walk = 4-frame cycle)
POSES = ["idle", "walk0", "walk1", "walk2", "walk3", "attack"]


def pose_verts(name):
    v = [list(p) for p in BASE]
    def fwd(i, dy, dz=0.0): v[i][1]+=dy; v[i][2]+=dz
    if name.startswith("walk"):
        ph = {"walk0":0.0,"walk1":math.pi/2,"walk2":math.pi,"walk3":3*math.pi/2}[name]
        s, so = math.sin(ph), math.sin(ph+math.pi)
        # legs swing fore/aft + lift; arms counter-swing
        fwd(12, 0.16*s, max(0,-s)*0.10); fwd(11, 0.10*s, max(0,-s)*0.05)
        fwd(15, 0.16*so, max(0,-so)*0.10); fwd(14, 0.10*so, max(0,-so)*0.05)
        fwd(6, -0.10*s); fwd(9, -0.10*so)
        bob = abs(math.sin(ph*2))*0.02
        for i in (0,1,2,3,4,7): v[i][2]+=bob
        v[1][1]+=0.02; v[3][1]+=0.02            # slight forward lean
    elif name == "attack":
        fwd(6, 0.30, 0.06); fwd(5, 0.16, 0.03)  # right arm reaches/strikes
        v[1][1]+=0.06; v[3][1]+=0.05; fwd(14, 0.05)
    return v


def build():
    scn = bpy.data.scenes.get("HeroClay")
    if scn: bpy.data.scenes.remove(scn, do_unlink=True)
    scn = bpy.data.scenes.new("HeroClay"); bpy.context.window.scene = scn
    coll = scn.collection
    root = bpy.data.objects.new("FigRoot", None); coll.objects.link(root)

    def gritty(name, base, rough, bump=0.3, bscale=40):
        m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
        b = nt.nodes.get("Principled BSDF")
        b.inputs["Base Color"].default_value = (*base, 1); b.inputs["Roughness"].default_value = rough
        n = nt.nodes.new("ShaderNodeTexNoise"); n.inputs["Scale"].default_value = bscale; n.inputs["Detail"].default_value = 8
        bp = nt.nodes.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = bump
        nt.links.new(n.outputs["Fac"], bp.inputs["Height"]); nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
        return m
    mat_skin = gritty("skin", (0.62,0.55,0.52), 0.55, 0.08, 120)
    mat_leather = gritty("leather", (0.022,0.020,0.026), 0.42, 0.5, 55)
    mat_hair = gritty("hair", (0.04,0.035,0.04), 0.7, 0.4, 90)
    mat_dark = gritty("dark", (0.03,0.03,0.035), 0.7, 0.4, 80)

    bm = bpy.data.meshes.new("body"); bm.from_pydata([Vector(v) for v in BASE], EDGES, []); bm.update()
    body = bpy.data.objects.new("body", bm); coll.objects.link(body); body.parent = root
    body.modifiers.new("Skin", "SKIN")
    sv = bm.skin_vertices[0].data
    for i, r in RAD.items(): sv[i].radius = (r, r)
    sv[0].use_root = True
    body.modifiers.new("Sub", "SUBSURF").levels = 2
    body.data.materials.append(mat_dark)

    head = _sphere(coll, "head", (0,-0.015,1.82), (0.090,0.106,0.120), mat_skin, root)
    hair = _sphere(coll, "hair", (0,-0.035,1.845), (0.094,0.108,0.10), mat_hair, root)
    _sphere(coll, "jaw", (0,0.05,1.745), (0.060,0.072,0.055), mat_skin, root)
    # face hints
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.018, radius2=0.006, depth=0.05, location=(0,0.08,1.81))
    nz = bpy.context.active_object; nz.rotation_euler=(math.radians(90),0,0); nz.parent=root; nz.data.materials.append(mat_skin)
    for sx in (1,-1):
        e = _sphere(coll, "eye", (sx*0.033,0.067,1.832), (0.018,0.014,0.014), None, root)
        em = bpy.data.materials.new("eyed"); em.use_nodes=True; em.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=(0.02,0.01,0.015,1)
        e.data.materials.append(em)

    # coat (fitted longcoat, open front)
    prof=[(1.60,0.115,0.090),(1.55,0.215,0.150),(1.40,0.205,0.140),(1.18,0.185,0.130),(0.95,0.190,0.135),(0.66,0.195,0.140),(0.42,0.190,0.138)]
    M=28; vent={19,20,21,22}; cv=[]; cf=[]; mi=[]
    for (z,w,d) in prof:
        for j in range(M):
            a=2*math.pi*j/M; cv.append((w*math.cos(a),d*math.sin(a),z))
    for i in range(len(prof)-1):
        for j in range(M):
            if i>=3 and j in vent: continue
            j2=(j+1)%M; cf.append((i*M+j,i*M+j2,(i+1)*M+j2,(i+1)*M+j)); mi.append(0)
    cm=bpy.data.meshes.new("coat"); cm.from_pydata(cv,[],cf); cm.update()
    coat=bpy.data.objects.new("coat",cm); coll.objects.link(coat); coat.parent=root
    coat.modifiers.new("Sol","SOLIDIFY").thickness=0.02; coat.modifiers.new("Sub","SUBSURF").levels=2
    coat.data.materials.append(mat_leather)
    macc=bpy.data.materials.new("acc"); macc.use_nodes=True
    ba=macc.node_tree.nodes.get("Principled BSDF"); ba.inputs["Base Color"].default_value=(0.30,0.02,0.04,1)
    coat.data.materials.append(macc)
    for poly in coat.data.polygons:
        if poly.center.z>1.50: poly.material_index=1

    # world + lights + cam (3/4 game angle)
    w=bpy.data.worlds.new("W"); scn.world=w; w.use_nodes=True; w.node_tree.nodes.get("Background").inputs[1].default_value=0.18
    def area(loc,en,col,sz,tgt=(0,0,1.0)):
        l=bpy.data.lights.new("L",'AREA'); l.energy=en; l.color=col; l.size=sz
        ob=bpy.data.objects.new("L",l); coll.objects.link(ob); ob.location=loc
        ob.rotation_euler=(Vector(tgt)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    area((-2.4,-1.2,3.1),900,(0.55,0.68,1.0),1.6); area((2.4,2.0,1.2),700,(1.0,0.5,0.2),0.8,(0,0,1.2)); area((0.2,-2.8,0.9),40,(0.5,0.6,0.9),2.0)
    cd=bpy.data.cameras.new("C"); cam=bpy.data.objects.new("C",cd); coll.objects.link(cam); scn.camera=cam
    cd.type='ORTHO'; cd.ortho_scale=2.25
    az=math.radians(-50); el=math.radians(44); R=6; tgt=Vector((0,0,1.02))
    cam.location=(R*math.cos(el)*math.cos(az),R*math.cos(el)*math.sin(az),tgt.z+R*math.sin(el))
    cam.rotation_euler=(tgt-Vector(cam.location)).to_track_quat('-Z','Y').to_euler()
    scn.render.engine='CYCLES'; scn.cycles.device='CPU'; scn.cycles.samples=16; scn.cycles.use_denoising=True
    scn.render.resolution_x=384; scn.render.resolution_y=512; scn.render.film_transparent=True
    scn.view_settings.view_transform='AgX'; scn.view_settings.look='AgX - Base Contrast'; scn.view_settings.exposure=0.4
    return scn, root, body


def _sphere(coll, name, loc, scale, mat, parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=loc)
    o=bpy.context.active_object; o.name=name; o.scale=scale; o.parent=parent
    if mat: o.data.materials.append(mat)
    bpy.ops.object.shade_smooth(); return o


def main(argv):
    ap=argparse.ArgumentParser(); ap.add_argument("--out",required=True)
    ap.add_argument("--dirs",type=int,default=4); ap.add_argument("--poses",default="")
    a=ap.parse_args(argv)
    os.makedirs(a.out,exist_ok=True)
    poses=a.poses.split(",") if a.poses else POSES
    scn,root,body=build()
    me=body.data
    manifest={"dirs":a.dirs,"poses":poses,"frames":[]}
    for pi,pose in enumerate(poses):
        pv=pose_verts(pose)
        for i in range(16): me.vertices[i].co=Vector(pv[i])
        me.update()
        for d in range(a.dirs):
            root.rotation_euler=(0,0,math.radians(d*(360.0/a.dirs)))
            bpy.context.view_layer.update()
            fn=f"clay_d{d}_p{pi}.png"; scn.render.filepath=os.path.join(a.out,fn)
            bpy.ops.render.render(write_still=True)
            manifest["frames"].append({"dir":d,"pose":pi,"pose_name":pose,"file":fn})
            print(f"[clay] {pose} dir{d}",flush=True)
    json.dump(manifest,open(os.path.join(a.out,"manifest.json"),"w"),indent=2)
    print(f"[clay] done: {len(manifest['frames'])} frames -> {a.out}",flush=True)


if __name__=="__main__":
    argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    main(argv)
