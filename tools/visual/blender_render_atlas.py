#!/usr/bin/env python3
"""blender_render_atlas.py — Vampire City 3D->2D atlas renderer.

Run headless:
    blender --background --python tools/visual/blender_render_atlas.py -- \
        --archetype hero --out assets/visual/cells --cell 192x256 \
        --samples 28 --supersample 1.0

Builds a parametric modern-gothic humanoid (Skin-modifier body on a vertex
skeleton + Subsurf + a lofted open-front long coat + separate head), poses it
across the 16 semantic rows, rotates it through the 8 authored directions, and
renders three passes per cell:

  * diffuse  - lit beauty (cold moon key + warm streetlamp rim), alpha sprite
  * normal   - camera-space surface normal, encoded N*0.5+0.5 (green flipped
               for Godot), flat outside the silhouette
  * spec     - per-object material-keyed grayscale specular intensity

Cells are written as PNGs into <out>/<archetype>_<pass>_r<row>_c<col>.png and
stitched into atlases by tools/visual/assemble_atlas.py (pure PIL, no Blender).

This is presentation source generation only. It never touches the Godot
simulation. The atlas contract (8 cols, 16 rows, baseline) is mirrored in
CharacterAtlas2D.gd and tools/visual/visual_atlas_contract.py.
"""
from __future__ import annotations
import sys, os, math, argparse, json
from pathlib import Path

import bpy  # type: ignore
from mathutils import Vector  # type: ignore

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vc_materials  # layered PBR + grit + AO + blood materials (same dir)

V = Vector  # local-space joint coords are mathutils Vectors

# --------------------------------------------------------------------------
# Atlas contract (kept in sync with CharacterAtlas2D.gd / the validator).
COLS = 8                       # E, SE, S, SW, W, NW, N, NE
ROWS = 16
DIR_LABELS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
# World-Z rotation per column. Calibrated so col0 reads as "facing screen-right"
# under the fixed three-quarter camera; +offset turns the whole ring.
DIR_OFFSET_DEG = -52.0         # aligns local +Y forward with the camera azimuth
NORMAL_FLIP_G = True           # Godot 2D normal maps want +Y up

# --------------------------------------------------------------------------
# Roster.  Mirrors tools/visual/visual_asset_core.py PROFILES, but typed for a
# 3D build (materials + silhouette flags + per-region specular).
def C(r, g, b):  # convenience
    return (r, g, b)

PROFILES = {
    "hero":     dict(coat=C(0.016,0.020,0.030), under=C(0.022,0.024,0.030),
                     skin=C(0.70,0.64,0.66), accent=C(0.34,0.025,0.05),
                     metal=C(0.66,0.68,0.72), build=0.98, weapon="claws",
                     long_coat=True, hooded=True, masked=False, armored=False,
                     helmeted=False, hair=C(0.05,0.05,0.06), vampire=True),
    "thug":     dict(coat=C(0.14,0.10,0.07), under=C(0.10,0.08,0.06),
                     skin=C(0.66,0.48,0.37), accent=C(0.36,0.10,0.11),
                     metal=C(0.50,0.50,0.52), build=1.16, weapon="bat",
                     long_coat=False, hooded=False, masked=False, armored=False,
                     helmeted=False, hair=C(0.07,0.05,0.04)),
    "gunner":   dict(coat=C(0.12,0.09,0.10), under=C(0.09,0.07,0.08),
                     skin=C(0.66,0.51,0.41), accent=C(0.36,0.12,0.15),
                     metal=C(0.55,0.56,0.58), build=1.03, weapon="pistol",
                     long_coat=False, hooded=False, masked=False, armored=False,
                     helmeted=False, hair=C(0.06,0.05,0.05)),
    "cop":      dict(coat=C(0.06,0.10,0.18), under=C(0.05,0.07,0.12),
                     skin=C(0.70,0.57,0.48), accent=C(0.38,0.50,0.70),
                     metal=C(0.60,0.64,0.70), build=1.06, weapon="pistol",
                     long_coat=False, hooded=False, masked=False, armored=True,
                     helmeted=False, hair=C(0.06,0.05,0.05)),
    "swat":     dict(coat=C(0.05,0.07,0.10), under=C(0.04,0.05,0.07),
                     skin=C(0.66,0.55,0.47), accent=C(0.30,0.40,0.55),
                     metal=C(0.45,0.48,0.52), build=1.19, weapon="rifle",
                     long_coat=False, hooded=False, masked=True, armored=True,
                     helmeted=True, hair=C(0.05,0.05,0.06)),
    "hunter":   dict(coat=C(0.10,0.10,0.11), under=C(0.07,0.07,0.08),
                     skin=C(0.74,0.68,0.60), accent=C(0.55,0.42,0.22),
                     metal=C(0.66,0.62,0.55), build=1.10, weapon="rifle",
                     long_coat=True, hooded=True, masked=False, armored=True,
                     helmeted=False, hair=C(0.20,0.16,0.10)),
    "elder":    dict(coat=C(0.06,0.06,0.08), under=C(0.05,0.05,0.06),
                     skin=C(0.80,0.76,0.70), accent=C(0.62,0.48,0.24),
                     metal=C(0.70,0.66,0.58), build=1.24, weapon="rifle",
                     long_coat=True, hooded=True, masked=False, armored=True,
                     helmeted=False, hair=C(0.80,0.78,0.74), vampire=True),
    "thrall":   dict(coat=C(0.10,0.08,0.12), under=C(0.07,0.05,0.08),
                     skin=C(0.70,0.62,0.68), accent=C(0.46,0.25,0.51),
                     metal=C(0.58,0.55,0.60), build=0.99, weapon="pistol",
                     long_coat=True, hooded=True, masked=True, armored=False,
                     helmeted=False, hair=C(0.10,0.07,0.10), vampire=True),
    "civilian": dict(coat=C(0.16,0.18,0.21), under=C(0.11,0.13,0.16),
                     skin=C(0.74,0.62,0.52), accent=C(0.40,0.44,0.50),
                     metal=C(0.52,0.52,0.54), build=0.94, weapon="",
                     long_coat=False, hooded=False, masked=False, armored=False,
                     helmeted=False, hair=C(0.12,0.09,0.07)),
}

# Per-region specular intensity (matte cloth / soft skin / glossy metal).
SPEC = dict(cloth=0.14, under=0.12, skin=0.34, accent=0.30, metal=0.92,
            hair=0.18, hood=0.13, mask=0.16)


# ==========================================================================
# Skeleton + posing
BASE = {
    "hipC": V((0.0, 0.0, 0.93)),  "chest": V((0.0, 0.0, 1.33)),
    "neck": V((0.0, 0.0, 1.49)),  "head":  V((0.0, 0.0, 1.585)),
    "shL": V((-0.185, 0.0, 1.40)), "elL": V((-0.295, 0.05, 1.10)), "wrL": V((-0.335, 0.135, 0.83)),
    "shR": V(( 0.185, 0.0, 1.40)), "elR": V(( 0.295, 0.05, 1.10)), "wrR": V(( 0.335, 0.135, 0.83)),
    "hipL": V((-0.095, 0.0, 0.90)), "knL": V((-0.115, 0.04, 0.47)), "anL": V((-0.12, 0.075, 0.02)),
    "hipR": V(( 0.095, 0.0, 0.90)), "knR": V(( 0.10, -0.02, 0.47)), "anR": V(( 0.115, 0.06, 0.02)),
}
ORDER = ["hipC","chest","neck","head","shL","elL","wrL","shR","elR","wrR",
         "hipL","knL","anL","hipR","knR","anR"]
EDGES = [(0,1),(1,2),(2,3),(1,4),(4,5),(5,6),(1,7),(7,8),(8,9),
         (0,10),(10,11),(11,12),(0,13),(13,14),(14,15)]
RADII = {0:0.126,1:0.138,2:0.066,3:0.048,4:0.090,5:0.050,6:0.038,
         7:0.090,8:0.050,9:0.038,10:0.090,11:0.066,12:0.048,13:0.090,14:0.066,15:0.048}


def pose_joints(row: int, build: float) -> dict:
    """Return local-space joint coords for one of the 16 semantic rows."""
    p = {k: v.copy() for k, v in BASE.items()}

    def fwd(joint, dy, dz=0.0):
        p[joint].y += dy; p[joint].z += dz

    if row == 0:                                   # idle A
        p["chest"].z += 0.010
    elif row == 1:                                 # idle B (breathe out)
        p["chest"].z -= 0.008; fwd("wrL", 0.01); fwd("wrR", 0.01)
    elif 2 <= row <= 7:                            # walk 0..5
        ph = (row - 2) / 6.0 * 2.0 * math.pi
        s = math.sin(ph); so = math.sin(ph + math.pi)
        fwd("anR", 0.20 * s, max(0.0, -s) * 0.11); fwd("knR", 0.12 * s, max(0.0, -s) * 0.05)
        fwd("anL", 0.20 * so, max(0.0, -so) * 0.11); fwd("knL", 0.12 * so, max(0.0, -so) * 0.05)
        fwd("wrR", -0.13 * s); fwd("wrL", -0.13 * so)
        bob = abs(math.sin(ph * 2.0)) * 0.018
        for j in ("hipC","chest","neck","head","shL","shR"): p[j].z += bob
        p["chest"].y += 0.03                        # forward lean while walking
        p["head"].y += 0.03
    elif row == 8:                                 # attack anticipate (wind up)
        fwd("wrR", -0.22, 0.06); fwd("elR", -0.10, 0.03)
        p["chest"].y -= 0.05; p["hipC"].z -= 0.03; p["head"].y -= 0.02
    elif row == 9:                                 # attack strike (reach)
        fwd("wrR", 0.34, 0.07); fwd("elR", 0.18, 0.03)
        p["chest"].y += 0.09; p["head"].y += 0.08; p["knR"].y += 0.06
        fwd("wrL", 0.10)
    elif row == 10:                                # follow-through
        fwd("wrR", 0.22); p["wrR"].x -= 0.14; p["chest"].y += 0.04
    elif row == 11:                                # recover
        fwd("wrR", 0.05); p["chest"].y += 0.01
    elif row == 12:                                # hit reaction
        p["chest"].y -= 0.11; p["head"].y -= 0.13; p["head"].z -= 0.02
        p["wrL"].x -= 0.09; p["wrR"].x += 0.09; p["wrL"].z -= 0.05; p["wrR"].z -= 0.05
    elif row == 13:                                # feed (commit head + arms)
        p["hipC"].z -= 0.09; p["chest"].z -= 0.10; p["neck"].z -= 0.11
        p["chest"].y += 0.10; p["head"].y += 0.17; p["head"].z -= 0.12
        p["wrL"] = V((-0.10, 0.20, 1.02)); p["wrR"] = V((0.10, 0.20, 1.00))
        p["elL"] = V((-0.20, 0.12, 1.12)); p["elR"] = V((0.20, 0.12, 1.12))
    elif row == 14:                                # downed: collapsed to knees, still alive
        p["hipC"] = V((0.0, 0.02, 0.42)); p["chest"] = V((0.0, 0.20, 0.62))
        p["neck"] = V((0.0, 0.30, 0.66)); p["head"] = V((0.04, 0.40, 0.62))
        p["shL"] = V((-0.17, 0.18, 0.64)); p["shR"] = V((0.17, 0.18, 0.64))
        p["elL"] = V((-0.24, 0.26, 0.34)); p["elR"] = V((0.24, 0.26, 0.34))
        p["wrL"] = V((-0.20, 0.34, 0.10)); p["wrR"] = V((0.20, 0.34, 0.10))   # hands catching ground
        p["hipL"] = V((-0.10, 0.0, 0.40)); p["hipR"] = V((0.10, 0.0, 0.40))
        p["knL"] = V((-0.14, 0.20, 0.12)); p["knR"] = V((0.14, 0.20, 0.12))   # knees on ground
        p["anL"] = V((-0.14, -0.14, 0.05)); p["anR"] = V((0.14, -0.14, 0.05)) # feet tucked behind
    elif row == 15:                                # corpse: flat sprawl (raised to stay in frame)
        z = 0.52
        p["hipC"] = V((0.0, 0.0, z)); p["chest"] = V((0.0, 0.22, z+0.02))
        p["neck"] = V((0.0, 0.40, z)); p["head"] = V((0.06, 0.54, z-0.02))
        p["shL"] = V((-0.18, 0.20, z)); p["shR"] = V((0.18, 0.22, z))
        p["elL"] = V((-0.30, 0.18, z)); p["elR"] = V((0.28, 0.34, z))
        p["wrL"] = V((-0.42, 0.12, z-0.02)); p["wrR"] = V((0.34, 0.46, z-0.02))  # arms splayed
        p["hipL"] = V((-0.12, -0.04, z)); p["hipR"] = V((0.12, -0.04, z))
        p["knL"] = V((-0.20, -0.32, z-0.02)); p["knR"] = V((0.15, -0.34, z-0.02))
        p["anL"] = V((-0.24, -0.60, z-0.03)); p["anR"] = V((0.19, -0.62, z-0.03))  # legs sprawled
    # broaden the frame slightly for heavier builds
    if build != 1.0:
        for k in ("shL","shR","chest","hipL","hipR","hipC"):
            p[k].x *= build
    return p


# ==========================================================================
# Build helpers
def _v(t):  # tuple -> Vector
    return Vector(t)


def new_material(name, base, rough=0.8, metal=0.0, emis=None, emis_str=0.0, sss=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")

    def s(i, v):
        if i in b.inputs:
            b.inputs[i].default_value = v
    s("Base Color", (*base, 1.0)); s("Roughness", rough); s("Metallic", metal)
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.5
    if sss > 0:
        s("Subsurface Weight", sss)
        if "Subsurface Radius" in b.inputs:
            b.inputs["Subsurface Radius"].default_value = (0.12, 0.05, 0.03)
    if emis is not None:
        s("Emission Color", (*emis, 1.0)); s("Emission Strength", emis_str)
    return m


def loft_coat(profiles, M, front_gap, name):
    verts, faces = [], []
    for (z, rx, ry) in profiles:
        for j in range(M):
            a = 2 * math.pi * j / M
            verts.append((rx * math.cos(a), ry * math.sin(a), z))
    for i in range(len(profiles) - 1):
        z = profiles[i][0]
        for j in range(M):
            if i >= 3 and j in front_gap:
                continue
            j2 = (j + 1) % M
            faces.append((i * M + j, i * M + j2, (i + 1) * M + j2, (i + 1) * M + j))
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    return me


def make_sphere(name, radius, loc, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc)
    o = bpy.context.active_object; o.name = name; o.scale = scale
    o.data.materials.append(mat); bpy.ops.object.shade_smooth()
    return o


def build_scene(profile: dict):
    # fresh scene
    scn = bpy.data.scenes.get("VampRender")
    if scn:
        bpy.data.scenes.remove(scn, do_unlink=True)
    scn = bpy.data.scenes.new("VampRender")
    bpy.context.window.scene = scn
    coll = scn.collection

    # Layered PBR + grit + AO + blood (vc_materials) replaces flat Principled colors.
    mats = vc_materials.build_pbr_materials(profile, SPEC)

    root = bpy.data.objects.new("vc_root", None); coll.objects.link(root)

    parts = {}
    # body skin mesh
    bm = bpy.data.meshes.new("vc_body")
    bm.from_pydata([BASE[k].copy() for k in ORDER], EDGES, []); bm.update()
    body = bpy.data.objects.new("vc_body", bm); coll.objects.link(body)
    body.modifiers.new("Skin", "SKIN")
    sv = bm.skin_vertices[0].data
    for i, r in RADII.items():
        rr = r * (profile["build"] ** 0.5)
        sv[i].radius = (rr, rr)
    sv[0].use_root = True
    body.modifiers.new("Subsurf", "SUBSURF").levels = 2
    body.data.materials.append(mats["under"]); body["spec"] = SPEC["under"]
    parts["body"] = body

    # head + hair + optional hood/helmet/mask
    head = make_sphere("vc_head", 0.103 * profile["build"], (0, 0.045, 1.65),
                       (0.94, 1.06, 1.20), mats["skin"]); head["spec"] = SPEC["skin"]
    parts["head"] = head
    if profile.get("helmeted"):
        hel = make_sphere("vc_helmet", 0.118 * profile["build"], (0, 0.01, 1.69),
                          (1.0, 1.05, 1.05), mats["metal"]); hel["spec"] = SPEC["metal"]
        parts["helmet"] = hel
    elif profile.get("hooded"):
        hood = make_sphere("vc_hood", 0.135 * profile["build"], (0, -0.02, 1.66),
                           (1.0, 1.12, 1.05), mats["cloth"]); hood["spec"] = SPEC["hood"]
        parts["hood"] = hood
    else:
        hair = make_sphere("vc_hair", 0.112 * profile["build"], (0, -0.01, 1.70),
                           (0.98, 1.04, 0.95), mats["hair"]); hair["spec"] = SPEC["hair"]
        parts["hair"] = hair
    if profile.get("masked"):
        mask = make_sphere("vc_mask", 0.107 * profile["build"], (0, 0.085, 1.575),
                           (0.92, 0.80, 0.55), mats["under"]); mask["spec"] = SPEC["mask"]
        parts["mask"] = mask

    # coat
    if profile.get("long_coat"):
        # FITTED urban longcoat: hangs STRAIGHT to mid-calf, hem radius <= waist
        # (never flared — a flared hem reads as a Dracula cape, which is banned).
        prof = [(1.50,0.150,0.120),(1.43,0.205,0.158),(1.20,0.195,0.150),
                (0.98,0.180,0.140),(0.78,0.190,0.146),(0.55,0.188,0.144),(0.34,0.182,0.140)]
    else:
        # waist-length fitted jacket: full legs visible, tall adult read.
        prof = [(1.49,0.138,0.108),(1.40,0.222,0.158),(1.16,0.200,0.155),(0.92,0.178,0.146)]
    bb = profile["build"]
    prof = [(z, rx * bb, ry * bb) for (z, rx, ry) in prof]
    cm = loft_coat(prof, 28, {19,20,21,22}, "vc_coat")
    coat = bpy.data.objects.new("vc_coat", cm); coll.objects.link(coat)
    coat.data.materials.append(mats["cloth"]); coat.data.materials.append(mats["accent"])
    # crimson/faction collar only on the long-coat predators; a jacket collar in
    # the accent hue looked like a stray scarf on cops and thugs.
    if profile.get("long_coat"):
        for poly in cm.polygons:
            if poly.center.z > 1.42:
                poly.material_index = 1
    coat.modifiers.new("Sol", "SOLIDIFY").thickness = 0.022
    coat.modifiers.new("Subsurf", "SUBSURF").levels = 1
    coat["spec"] = SPEC["cloth"]
    bpy.ops.object.select_all(action="DESELECT"); coat.select_set(True)
    bpy.context.view_layer.objects.active = coat; bpy.ops.object.shade_smooth()
    parts["coat"] = coat

    if profile.get("armored"):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.135, 1.18))
        pl = bpy.context.active_object; pl.name = "vc_armor"
        pl.scale = (0.20 * bb, 0.06, 0.22)
        pl.data.materials.append(mats["metal"]); pl["spec"] = SPEC["metal"]
        parts["armor"] = pl

    # weapon prop + claws
    weapon = profile.get("weapon", "")
    if weapon == "claws":
        parts["claws"] = []
        for sgn in (-1, 1):
            for k in (-1, 0, 1):
                bpy.ops.mesh.primitive_cone_add(radius1=0.013, radius2=0.0, depth=0.09,
                    location=(sgn * 0.335 + k * 0.019, 0.19, 0.80))
                c = bpy.context.active_object; c.name = "vc_claw"
                c.rotation_euler = (math.radians(118), 0, 0)
                c.data.materials.append(mats["metal"]); c["spec"] = SPEC["metal"]
                parts["claws"].append((c, sgn, k))
    elif weapon in ("bat", "pistol", "rifle"):
        length = dict(bat=0.42, pistol=0.16, rifle=0.55)[weapon]
        rad = dict(bat=0.022, pistol=0.018, rifle=0.020)[weapon]
        bpy.ops.mesh.primitive_cylinder_add(radius=rad, depth=length,
            location=(0.335, 0.30, 0.86))
        w = bpy.context.active_object; w.name = "vc_weapon"
        w.rotation_euler = (math.radians(90), 0, 0)
        wmat = mats["hair"] if weapon == "bat" else mats["metal"]
        w.data.materials.append(wmat)
        w["spec"] = SPEC["hair"] if weapon == "bat" else SPEC["metal"]
        parts["weapon"] = w

    # VtM blood cue: the vc_materials blood overlay smears wet crimson where the
    # per-object "grime" attribute is high (blotchy, noise-masked — not uniform).
    # Vampires wear their feeding: blood on the coat front, hands, and chin.
    if profile.get("vampire"):
        coat["grime"] = 0.45
        body["grime"] = 0.38
        if "head" in parts:
            parts["head"]["grime"] = 0.28

    # parent everything to root
    for o in coll.objects:
        if o is root or o.type in ("LIGHT", "CAMERA"):
            continue
        if o.parent is None:
            o.parent = root

    # NB: no ground plane.  A baked cast shadow would smear across the cell and
    # contaminate the normal/spec passes; the contact shadow is drawn in-engine
    # by CharacterAtlas2D instead, keeping the figure alpha clean.

    # world + lights
    w = bpy.data.worlds.new("VampWorld"); scn.world = w; w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.006, 0.010, 0.022, 1.0); bg.inputs[1].default_value = 0.14

    def area(name, loc, color, energy, size, target=(0,0,1.05)):
        ld = bpy.data.lights.new(name, "AREA"); ld.energy = energy; ld.color = color; ld.size = size
        ob = bpy.data.objects.new(name, ld); coll.objects.link(ob); ob.location = loc
        ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    area("KeyMoon", (-2.4,-1.0,3.2), (0.45,0.60,1.0), 1050, 1.4)
    area("RimLamp", (2.4,2.0,1.1), (1.0,0.46,0.16), 620, 0.6, target=(0,0,1.2))
    area("FillCool", (0.1,-2.9,0.8), (0.35,0.45,0.78), 50, 2.2, target=(0,0,1.0))

    # camera ortho three-quarter
    cd = bpy.data.cameras.new("VampCam"); cam = bpy.data.objects.new("VampCam", cd)
    coll.objects.link(cam); scn.camera = cam; cd.type = "ORTHO"; cd.ortho_scale = 2.50
    # framed so feet land on baseline Y=224 of the 256px cell with headroom
    az = math.radians(-52); el = math.radians(36); R = 6.0
    tgt = Vector((0, 0, 1.14))
    cam.location = (R*math.cos(el)*math.cos(az), R*math.cos(el)*math.sin(az), tgt.z+R*math.sin(el))
    cam.rotation_euler = (tgt - Vector(cam.location)).to_track_quat("-Z","Y").to_euler()

    return scn, root, parts, mats


# ==========================================================================
# Pose application
def apply_pose(root, parts, profile, row):
    j = pose_joints(row, profile["build"])
    body = parts["body"]
    me = body.data
    for i, k in enumerate(ORDER):
        me.vertices[i].co = j[k]
    me.update()

    head_c = j["head"] + Vector((0.0, 0.045, 0.078))
    parts["head"].location = head_c
    for key, off in (("hood", Vector((0,-0.02,0.075))), ("helmet", Vector((0,0.01,0.105))),
                     ("hair", Vector((0,-0.01,0.115))), ("mask", Vector((0,0.085,-0.01)))):
        if key in parts:
            parts[key].location = j["head"] + off

    # coat follows torso vertically + leans with chest
    coat = parts["coat"]
    coat.location = Vector((0.0, j["chest"].y * 0.5, (j["hipC"].z - BASE["hipC"].z)))
    coat.rotation_euler = (math.radians(j["chest"].y * 22.0), 0, 0)

    if "armor" in parts:
        parts["armor"].location = j["chest"] + Vector((0, 0.135, -0.15))

    if "claws" in parts:
        for (c, sgn, k) in parts["claws"]:
            wr = j["wrR"] if sgn > 0 else j["wrL"]
            c.location = wr + Vector((k * 0.019, 0.055, -0.03))
    if "weapon" in parts:
        parts["weapon"].location = j["wrR"] + Vector((0.0, 0.16, 0.03))

    # downed/corpse are authored in joint space (slumped/sprawled), so the rigid
    # vertical coat would float over a flat body — hide cloth/weapon for those rows.
    prone = row in (14, 15)
    if "coat" in parts:
        parts["coat"].hide_render = prone
    if "weapon" in parts:
        parts["weapon"].hide_render = prone
    if "claws" in parts:
        for (c, _s, _k) in parts["claws"]:
            c.hide_render = prone

    # The pose carries the collapse; the root only spins per direction (set_direction).
    root.rotation_euler = (0, 0, 0)
    root.location = (0, 0, 0)


def set_direction(root, col, base_tilt):
    ang = math.radians(DIR_OFFSET_DEG + col * 45.0)
    root.rotation_euler = (base_tilt[0], base_tilt[1], ang + base_tilt[2])


# ==========================================================================
# Passes
def make_normal_material():
    m = bpy.data.materials.new("vc_NORMAL"); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    vt = nt.nodes.new("ShaderNodeVectorTransform")
    vt.vector_type = "VECTOR"; vt.convert_from = "WORLD"; vt.convert_to = "CAMERA"
    mul = nt.nodes.new("ShaderNodeVectorMath"); mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = (0.5, 0.5, 0.5)
    add = nt.nodes.new("ShaderNodeVectorMath"); add.operation = "ADD"
    add.inputs[1].default_value = (0.5, 0.5, 0.5)
    emi = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(geo.outputs["Normal"], vt.inputs[0])
    nt.links.new(vt.outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], add.inputs[0])
    nt.links.new(add.outputs[0], emi.inputs[0])
    nt.links.new(emi.outputs[0], out.inputs[0])
    return m


def make_spec_material():
    m = bpy.data.materials.new("vc_SPEC"); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_type = "OBJECT"; attr.attribute_name = "spec"
    emi = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(attr.outputs["Fac"], emi.inputs[0])
    nt.links.new(emi.outputs[0], out.inputs[0])
    return m


def configure_render(scn, w, h, samples, beauty):
    r = scn.render
    r.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = samples if beauty else 1
    scn.cycles.use_denoising = bool(beauty)
    if not beauty:
        scn.cycles.max_bounces = 0
    r.resolution_x = w; r.resolution_y = h; r.resolution_percentage = 100
    r.film_transparent = True
    r.image_settings.file_format = "PNG"; r.image_settings.color_mode = "RGBA"
    vt = scn.view_settings
    if beauty:
        try:
            vt.view_transform = "AgX"; vt.look = "AgX - Base Contrast"; vt.exposure = 0.55
        except Exception:
            try:
                vt.view_transform = "Filmic"; vt.look = "Medium High Contrast"; vt.exposure = 0.3
            except Exception:
                pass
    else:
        try:
            vt.view_transform = "Standard"; vt.look = "None"; vt.exposure = 0.0
        except Exception:
            pass


def render_cell(scn, path):
    scn.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


# ==========================================================================
def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--archetype", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--cell", default="192x256")
    ap.add_argument("--samples", type=int, default=28)
    ap.add_argument("--supersample", type=float, default=1.0)
    ap.add_argument("--rows", default="")   # optional CSV subset for debugging
    ap.add_argument("--cols", default="")   # optional CSV subset for debugging
    args = ap.parse_args(argv)

    cw, ch = (int(x) for x in args.cell.lower().split("x"))
    rw, rh = int(cw * args.supersample), int(ch * args.supersample)
    prof = PROFILES[args.archetype]
    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)

    rows = [int(x) for x in args.rows.split(",")] if args.rows else list(range(ROWS))
    cols = [int(x) for x in args.cols.split(",")] if args.cols else list(range(COLS))

    scn, root, parts, mats = build_scene(prof)
    nrm_mat = make_normal_material()
    spc_mat = make_spec_material()
    vl = scn.view_layers[0]

    arche = args.archetype
    n = 0
    for row in rows:
        apply_pose(root, parts, prof, row)
        base_tilt = tuple(root.rotation_euler)
        base_loc = tuple(root.location)
        for col in cols:
            set_direction(root, col, base_tilt)
            root.location = base_loc
            tag = f"r{row:02d}_c{col}"
            # diffuse
            vl.material_override = None
            configure_render(scn, rw, rh, args.samples, beauty=True)
            render_cell(scn, out / f"{arche}_diffuse_{tag}.png")
            # normal
            vl.material_override = nrm_mat
            configure_render(scn, rw, rh, args.samples, beauty=False)
            render_cell(scn, out / f"{arche}_normal_{tag}.png")
            # spec
            vl.material_override = spc_mat
            configure_render(scn, rw, rh, args.samples, beauty=False)
            render_cell(scn, out / f"{arche}_spec_{tag}.png")
            n += 1
            print(f"[atlas] {arche} {tag} ({n}/{len(rows)*len(cols)})", flush=True)

    meta = dict(archetype=arche, cols=COLS, rows=ROWS, cell=[cw, ch],
                render=[rw, rh], dir_labels=DIR_LABELS, dir_offset_deg=DIR_OFFSET_DEG,
                normal_flip_g=NORMAL_FLIP_G, profile=arche)
    (out / f"{arche}_render_meta.json").write_text(json.dumps(meta, indent=2))
    print(f"[atlas] done {arche}: {n} cells -> {out}", flush=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    main(argv)
