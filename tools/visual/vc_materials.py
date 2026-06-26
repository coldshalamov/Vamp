#!/usr/bin/env python3
"""vc_materials.py — layered PBR + grit materials for blender_render_atlas.py.

Drop-in Blender 5.1.2 (Cycles) node builders that REPLACE the flat Principled
colors produced by ``blender_render_atlas.new_material``.  Every surface gets:

  * procedural micro-normal  (TexNoise / TexVoronoi -> Bump into Principled.Normal)
  * roughness break-up        (noise -> MapRange -> Roughness)
  * subtle base-color variation (noise -> mix on Base Color)
  * edge-wear                 (NewGeometry.Pointiness -> ColorRamp -> mix toward worn)
  * a baked-AO contribution   (AmbientOcclusion.AO -> multiply into Base Color)
  * a blood/grime overlay     (object attribute "grime" -> mix toward dark crimson)

This is the "Dead Cells rotoscope + Bloodlines urban gothic" target: fitted
modern fabrics/leather with weave, grain, grime, edge-wear and BLOOD — never
clean clay.  The AO is folded into the diffuse (beauty) pass so folds and
occlusion read as baked grit even though no ground plane / shadow catcher is in
the scene (the renderer deliberately omits one to keep the alpha clean).

Integration (in blender_render_atlas.build_scene), replace the ``mats`` dict::

    import vc_materials                       # same dir; add it to sys.path if needed
    mats = vc_materials.build_pbr_materials(profile, SPEC)

The returned dict has the SAME keys build_scene already uses
(cloth / under / skin / accent / metal / hair), so the rest of build_scene is
unchanged.  Per-object ``["spec"]`` tagging and the SPEC table are untouched —
the spec pass still keys off the object attribute, not these node graphs.

View transform: leave configure_render() as-is.  The beauty pass already selects
a filmic look (it sets ``view_transform = "Filmic"`` / look "Medium High
Contrast", falling back silently).  If the integrator wants the more neutral,
less-clippy AgX response on 5.1, change that one line to
``vt.view_transform = "AgX"; vt.look = "AgX - Medium High Contrast"`` — both
exist in a stock 5.1 OCIO config.  These materials are authored against a
filmic/AgX response and will look milky under "Standard".

Blender API notes (all verified against a live 5.1.2):
  * ShaderNodeMix has DUPLICATE socket names per data_type (A/B/Factor exist for
    VALUE, VECTOR, RGBA, ROTATION).  Indexing inputs["A"] is AMBIGUOUS, so every
    Mix here is wired by INTEGER index: for data_type="RGBA" -> Factor=in[0],
    A=in[6], B=in[7], Result=out[2].  Helpers below hide this.
  * TexNoise outputs ["Factor","Color"]; Bump input is "Height", output "Normal".
  * NewGeometry exposes "Pointiness"; AmbientOcclusion exposes "Color" and "AO".
"""
from __future__ import annotations

import bpy  # type: ignore


# --------------------------------------------------------------------------
# Low-level node-graph helpers.
def _nt(mat):
    return mat.node_tree


def _new(nt, ident, x=0.0, y=0.0):
    n = nt.nodes.new(ident)
    n.location = (x, y)
    return n


def _link(nt, a_out, b_in):
    nt.links.new(a_out, b_in)


def _mix_rgba(nt, fac_source=None, fac=0.0, blend="MIX", x=0.0, y=0.0):
    """A ShaderNodeMix in RGBA mode, wired by integer index to dodge the
    duplicate-socket-name trap.  Returns (node, A_input, B_input, Result_output)."""
    m = _new(nt, "ShaderNodeMix", x, y)
    m.data_type = "RGBA"
    m.blend_type = blend
    m.clamp_result = False
    # in[0]=Factor(VALUE), in[6]=A(RGBA), in[7]=B(RGBA); out[2]=Result(RGBA)
    a_in, b_in, res = m.inputs[6], m.inputs[7], m.outputs[2]
    if fac_source is not None:
        _link(nt, fac_source, m.inputs[0])
    else:
        m.inputs[0].default_value = fac
    return m, a_in, b_in, res


def _noise(nt, scale=12.0, detail=6.0, roughness=0.55, distortion=0.0,
           coord="Object", x=0.0, y=0.0):
    """3D noise driven by texture coordinates (Object space so the pattern is
    stable as the figure is re-posed/rotated per cell)."""
    tc = _new(nt, "ShaderNodeTexCoord", x - 360.0, y)
    n = _new(nt, "ShaderNodeTexNoise", x, y)
    n.noise_dimensions = "3D"
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = roughness
    n.inputs["Distortion"].default_value = distortion
    _link(nt, tc.outputs[coord], n.inputs["Vector"])
    return n  # outputs: "Factor" (VALUE), "Color" (RGBA)


def _voronoi(nt, scale=40.0, randomness=1.0, feature="F1", coord="Object",
             x=0.0, y=0.0):
    tc = _new(nt, "ShaderNodeTexCoord", x - 360.0, y)
    v = _new(nt, "ShaderNodeTexVoronoi", x, y)
    v.feature = feature
    v.inputs["Scale"].default_value = scale
    v.inputs["Randomness"].default_value = randomness
    _link(nt, tc.outputs[coord], v.inputs["Vector"])
    return v  # "Distance" output gives cell-edge breakup


def _map_range(nt, src, to_min, to_max, from_min=0.0, from_max=1.0,
               x=0.0, y=0.0):
    mr = _new(nt, "ShaderNodeMapRange", x, y)
    mr.clamp = True
    mr.inputs["From Min"].default_value = from_min
    mr.inputs["From Max"].default_value = from_max
    mr.inputs["To Min"].default_value = to_min
    mr.inputs["To Max"].default_value = to_max
    _link(nt, src, mr.inputs["Value"])
    return mr.outputs["Result"]


def _ramp(nt, src, stops, x=0.0, y=0.0):
    """ColorRamp (ValToRGB).  stops = [(pos, (r,g,b,a)), ...] applied onto the
    two default elements + extras.  Returns the Color output."""
    r = _new(nt, "ShaderNodeValToRGB", x, y)
    el = r.color_ramp.elements
    # element 0 + 1 already exist; add more as needed
    while len(el) < len(stops):
        el.new(1.0)
    for i, (pos, col) in enumerate(stops):
        el[i].position = pos
        el[i].color = col
    _link(nt, src, r.inputs["Factor"])
    return r.outputs["Color"]


# --------------------------------------------------------------------------
# The grit stack.  Each builder wires a Principled BSDF and returns the material.
def _grime_attr(nt, x=0.0, y=0.0):
    """Per-object grime/blood amount.  Reads object custom attribute "grime"
    (0..1); absent -> 0, so untouched objects render clean.  Set on an object
    with ``obj["grime"] = 0.6`` to splatter blood/dirt where it makes sense
    (e.g. a feeding hero, a downed corpse)."""
    a = _new(nt, "ShaderNodeAttribute", x, y)
    a.attribute_type = "OBJECT"
    a.attribute_name = "grime"
    return a.outputs["Fac"]  # VALUE in [0,1]


def make_pbr_material(
    name,
    base,
    *,
    rough=0.8,
    metal=0.0,
    spec_level=0.5,
    sss=0.0,
    # micro-normal
    bump_scale=18.0,
    bump_strength=0.18,
    bump_detail=6.0,
    voronoi_scale=0.0,        # >0 adds a voronoi (leather grain / weave cell) term
    voronoi_strength=0.10,
    # roughness break-up
    rough_var=0.16,
    rough_scale=9.0,
    # base-color variation
    color_var=0.06,
    color_scale=7.0,
    # edge wear
    wear_color=None,          # None -> derive a lighter, desaturated worn tone
    wear_amount=0.55,
    wear_low=0.30,            # pointiness ramp window (convex edges)
    wear_high=0.62,
    # baked AO into diffuse
    ao_distance=0.25,
    ao_strength=0.85,
    # blood / grime overlay
    grime_color=(0.34, 0.020, 0.028),   # wet venous crimson (reads under filmic)
    grime_rough=0.62,
    grime_scale=5.0,
):
    """Build one layered-PBR material and return it.

    The graph (left -> right):
        base_color
          x AO            (folds read darker)
          -> color_var    (subtle blotchy tone)
          -> edge_wear    (convex edges lift toward worn_color)
          -> grime mask   (blood/dirt where object attr "grime" > 0)
        roughness  = rough +- noise, plus grime gloss-knockdown
        normal     = noise(+voronoi) -> bump
    """
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    out = nt.nodes.get("Material Output")
    if bsdf is None:
        bsdf = _new(nt, "ShaderNodeBsdfPrincipled", 200.0, 0.0)
    if out is None:
        out = _new(nt, "ShaderNodeOutputMaterial", 600.0, 0.0)
        _link(nt, bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.location = (300.0, 0.0)
    out.location = (700.0, 0.0)

    base4 = (base[0], base[1], base[2], 1.0)

    # ---- Base color chain --------------------------------------------------
    # 1) AmbientOcclusion: feed base color in, multiply AO back over it so
    #    occluded folds darken in the BEAUTY pass (baked grit, no ground plane).
    ao = _new(nt, "ShaderNodeAmbientOcclusion", -900.0, 200.0)
    ao.samples = 16
    ao.inside = False
    # only_local=False so AO sees INTER-object occlusion: the figure is built
    # from separate meshes (body / head / hood / mask / coat / armor), and the
    # grit we want — chin-shadow under the jaw, darkening inside the hood, arm
    # against torso, body beneath the coat hem — is occlusion BETWEEN those
    # objects.  only_local=True would throw all of that away and leave only weak
    # self-occlusion on smooth Subsurf tubes.  There is no ground plane to
    # contaminate it (the renderer omits one on purpose).
    ao.only_local = False
    ao.inputs["Color"].default_value = base4
    ao.inputs["Distance"].default_value = ao_distance
    # mix base*AO over base by ao_strength (AO scalar drives a MULTIPLY)
    ao_pow = _map_range(nt, ao.outputs["AO"], 1.0 - ao_strength, 1.0,
                        x=-700.0, y=120.0)
    ao_mix, ao_a, ao_b, ao_res = _mix_rgba(nt, fac=1.0, blend="MULTIPLY",
                                           x=-520.0, y=200.0)
    ao_a.default_value = base4
    # B = solid white scaled by AO factor via a second ramp-free multiply:
    # simplest: feed AO scalar as grayscale into B through a MapRange->combine.
    ao_gray = _ramp(nt, ao_pow, [(0.0, (0, 0, 0, 1)), (1.0, (1, 1, 1, 1))],
                    x=-700.0, y=-40.0)
    _link(nt, ao_gray, ao_b)
    cur = ao_res  # current base-color RGBA output

    # 2) Subtle base-color variation (blotchy tonal drift).
    if color_var > 0.0:
        cn = _noise(nt, scale=color_scale, detail=4.0, x=-520.0, y=-260.0)
        cvar = _ramp(nt, cn.outputs["Factor"],
                     [(0.0, (1.0 - color_var, 1.0 - color_var, 1.0 - color_var, 1)),
                      (1.0, (1.0 + color_var, 1.0 + color_var, 1.0 + color_var, 1))],
                     x=-340.0, y=-260.0)
        vm, va, vb, vres = _mix_rgba(nt, fac=1.0, blend="MULTIPLY",
                                     x=-160.0, y=-120.0)
        _link(nt, cur, va)
        _link(nt, cvar, vb)
        cur = vres

    # 3) Edge wear: convex edges (high pointiness) lift toward a worn tone.
    if wear_amount > 0.0:
        if wear_color is None:
            # lighter + desaturated version of base = scuffed/abraded fabric
            lum = 0.3 * base[0] + 0.59 * base[1] + 0.11 * base[2]
            worn = (
                base[0] * 0.45 + (lum + 0.18) * 0.55,
                base[1] * 0.45 + (lum + 0.18) * 0.55,
                base[2] * 0.45 + (lum + 0.20) * 0.55,
                1.0,
            )
        else:
            worn = (wear_color[0], wear_color[1], wear_color[2], 1.0)
        geo = _new(nt, "ShaderNodeNewGeometry", -520.0, 420.0)
        # break the hard pointiness with a little noise so wear isn't a clean line
        wn = _noise(nt, scale=22.0, detail=3.0, x=-520.0, y=600.0)
        pmix = _map_range(nt, geo.outputs["Pointiness"], 0.0, 1.0,
                          from_min=wear_low, from_max=wear_high,
                          x=-340.0, y=420.0)
        wear_fac = _ramp(nt, pmix,
                         [(0.0, (0, 0, 0, 1)), (1.0, (wear_amount, wear_amount, wear_amount, 1))],
                         x=-160.0, y=420.0)
        # modulate wear by noise so it's grimy, not a uniform rim
        wfac_n, wn_a, wn_b, wn_res = _mix_rgba(nt, fac=0.5, blend="MULTIPLY",
                                               x=0.0, y=480.0)
        _link(nt, wear_fac, wn_a)
        _link(nt, _ramp(nt, wn.outputs["Factor"],
                        [(0.0, (0.5, 0.5, 0.5, 1)), (1.0, (1, 1, 1, 1))],
                        x=-160.0, y=620.0), wn_b)
        sep = _new(nt, "ShaderNodeSeparateColor", 120.0, 540.0)
        _link(nt, wn_res, sep.inputs["Color"])
        wm, wa, wb, wres = _mix_rgba(nt, fac_source=sep.outputs["Red"],
                                     blend="MIX", x=160.0, y=120.0)
        _link(nt, cur, wa)
        wb.default_value = worn
        cur = wres

    # 4) Blood / grime overlay, gated by the per-object "grime" attribute.
    #    The mask = attr-amount * coarse-noise-blotches.  Thresholds are LOOSE
    #    (from_min 0.30) and the noise is coarse (game-resolution-readable) so a
    #    fed/downed actor shows obvious wet-blood smears, not a few sub-pixel
    #    specks.  The attribute scales the whole effect, so grime=0 -> none.
    grime_fac = _grime_attr(nt, x=-160.0, y=-520.0)
    gn = _noise(nt, scale=max(2.5, grime_scale * 0.7), detail=4.0,
                distortion=1.8, x=-160.0, y=-680.0)
    gmask = _map_range(nt, gn.outputs["Factor"], 0.0, 1.0,
                       from_min=0.30, from_max=0.60, x=20.0, y=-680.0)
    gmul = _new(nt, "ShaderNodeMath", 200.0, -600.0)
    gmul.operation = "MULTIPLY"
    _link(nt, grime_fac, gmul.inputs[0])
    _link(nt, gmask, gmul.inputs[1])
    gm, ga, gb, gres = _mix_rgba(nt, fac_source=gmul.outputs["Value"],
                                 blend="MIX", x=240.0, y=40.0)
    _link(nt, cur, ga)
    gb.default_value = (grime_color[0], grime_color[1], grime_color[2], 1.0)
    cur = gres

    _link(nt, cur, bsdf.inputs["Base Color"])

    # ---- Roughness chain ---------------------------------------------------
    rn = _noise(nt, scale=rough_scale, detail=5.0, x=-340.0, y=-940.0)
    rough_out = _map_range(nt, rn.outputs["Factor"],
                           max(0.04, rough - rough_var),
                           min(1.0, rough + rough_var), x=-120.0, y=-940.0)
    # grime is wetter/glossier in spots: pull roughness down where grime is high
    rgrime = _new(nt, "ShaderNodeMath", 100.0, -1040.0)
    rgrime.operation = "MULTIPLY_ADD"
    _link(nt, gmul.outputs["Value"], rgrime.inputs[0])
    rgrime.inputs[1].default_value = -(rough - grime_rough)   # toward grime_rough
    _link(nt, rough_out, rgrime.inputs[2])
    rclamp = _new(nt, "ShaderNodeClamp", 240.0, -1040.0)
    rclamp.inputs["Min"].default_value = 0.04
    rclamp.inputs["Max"].default_value = 1.0
    _link(nt, rgrime.outputs["Value"], rclamp.inputs["Value"])
    _link(nt, rclamp.outputs["Result"], bsdf.inputs["Roughness"])

    # ---- Micro-normal chain ------------------------------------------------
    nn = _noise(nt, scale=bump_scale, detail=bump_detail, roughness=0.6,
                x=-340.0, y=-1240.0)
    bump_src = nn.outputs["Factor"]
    if voronoi_scale > 0.0:
        vor = _voronoi(nt, scale=voronoi_scale, feature="DISTANCE_TO_EDGE",
                       x=-340.0, y=-1420.0)
        # blend voronoi grain into the noise height
        bn, ba, bb, bres = _mix_rgba(nt, fac=voronoi_strength, blend="MIX",
                                     x=-120.0, y=-1320.0)
        _link(nt, _ramp(nt, nn.outputs["Factor"],
                        [(0.0, (0, 0, 0, 1)), (1.0, (1, 1, 1, 1))],
                        x=-200.0, y=-1240.0), ba)
        _link(nt, _ramp(nt, vor.outputs["Distance"],
                        [(0.0, (0, 0, 0, 1)), (1.0, (1, 1, 1, 1))],
                        x=-200.0, y=-1420.0), bb)
        sepb = _new(nt, "ShaderNodeSeparateColor", 40.0, -1320.0)
        _link(nt, bres, sepb.inputs["Color"])
        bump_src = sepb.outputs["Red"]
    bump = _new(nt, "ShaderNodeBump", 120.0, -1240.0)
    bump.inputs["Strength"].default_value = bump_strength
    bump.inputs["Distance"].default_value = 0.02
    _link(nt, bump_src, bump.inputs["Height"])
    _link(nt, bump.outputs["Normal"], bsdf.inputs["Normal"])

    # ---- Scalar Principled params -----------------------------------------
    bsdf.inputs["Metallic"].default_value = metal
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = spec_level
    if sss > 0.0:
        bsdf.inputs["Subsurface Weight"].default_value = sss
        if "Subsurface Radius" in bsdf.inputs:
            bsdf.inputs["Subsurface Radius"].default_value = (0.12, 0.05, 0.03)

    return m


# --------------------------------------------------------------------------
# Named surface presets.  Tunings chosen for the urban-gothic target:
# leather grain, fabric weave, denim twill, pale clammy skin, oxidized metal,
# blood.  ``base`` comes from the archetype PROFILE so faction palettes survive.
#
# IMPORTANT — scales are MACRO on purpose.  The figure is ~1.7 Blender units
# tall rendered into a 192x256 cell, so a noise Scale of N gives ~N cycles
# across the whole body.  Fine cloth-weave scales (100+) land sub-pixel at game
# resolution and wash out to flat clay (verified by eyeballing a hero cell).
# These presets therefore bias toward COARSE, high-contrast break-up that
# actually survives the ortho downsample, plus strong bump so folds catch the
# cold key.  If you ever super-sample hard (supersample >= 2) you can push the
# *_scale values up for finer grain.
def leather(name, base, spec=0.18):
    return make_pbr_material(
        name, base, rough=0.46, spec_level=0.55,
        bump_scale=9.0, bump_strength=0.55, bump_detail=8.0,
        voronoi_scale=24.0, voronoi_strength=0.5,    # pebbled grain (readable)
        rough_var=0.22, rough_scale=5.0,
        color_var=0.12, color_scale=3.5,
        wear_amount=0.7, wear_low=0.22, wear_high=0.54,
        ao_strength=1.0, ao_distance=0.45, grime_color=(0.32, 0.018, 0.026),
    )


def cloth(name, base, spec=0.14):
    return make_pbr_material(
        name, base, rough=0.86, spec_level=0.35,
        bump_scale=9.0, bump_strength=0.5, bump_detail=8.0,
        voronoi_scale=22.0, voronoi_strength=0.5,    # coarse weave that reads
        rough_var=0.22, rough_scale=5.0,
        color_var=0.16, color_scale=3.5,
        wear_amount=0.6, wear_low=0.22, wear_high=0.54,
        ao_strength=1.0, ao_distance=0.45, grime_color=(0.34, 0.020, 0.028),
    )


def denim(name, base, spec=0.16):
    return make_pbr_material(
        name, base, rough=0.78, spec_level=0.40,
        bump_scale=11.0, bump_strength=0.45, bump_detail=8.0,
        voronoi_scale=28.0, voronoi_strength=0.5,    # twill grain
        rough_var=0.20, rough_scale=6.0,
        color_var=0.16, color_scale=4.0,
        wear_amount=0.7, wear_low=0.20, wear_high=0.52,
        ao_strength=1.0, ao_distance=0.45, grime_color=(0.32, 0.018, 0.026),
    )


def pale_skin(name, base, spec=0.34):
    return make_pbr_material(
        name, base, rough=0.42, spec_level=0.6, sss=0.30,
        bump_scale=14.0, bump_strength=0.10, bump_detail=8.0,  # clammy, not pored
        voronoi_scale=0.0,
        rough_var=0.10, rough_scale=8.0,
        color_var=0.10, color_scale=4.0,              # mottled pallor / livor
        wear_amount=0.0,                              # skin doesn't "edge-wear"
        ao_strength=0.9, ao_distance=0.4,
        grime_color=(0.42, 0.030, 0.040),             # blood reads vivid on pale skin
    )


def metal(name, base, spec=0.92):
    return make_pbr_material(
        name, base, rough=0.34, metal=1.0, spec_level=0.5,
        bump_scale=12.0, bump_strength=0.18, bump_detail=6.0,
        voronoi_scale=26.0, voronoi_strength=0.35,
        rough_var=0.28, rough_scale=6.0,              # oxidized, uneven sheen
        color_var=0.06, wear_color=(0.66, 0.68, 0.70),
        wear_amount=0.65, wear_low=0.24, wear_high=0.54,  # bright scuffed edges
        ao_strength=0.9, ao_distance=0.4, grime_color=(0.30, 0.016, 0.022),
    )


def blood(name, base=(0.21, 0.012, 0.018), spec=0.40):
    """Dedicated wet-blood material (collar accents, stains, claw tips).
    Glossy, dark venous red, broken by clotted-darker noise."""
    return make_pbr_material(
        name, base, rough=0.28, spec_level=0.75,
        bump_scale=24.0, bump_strength=0.20, bump_detail=5.0,
        voronoi_scale=0.0,
        rough_var=0.18, rough_scale=10.0,
        color_var=0.12, color_scale=9.0,
        wear_amount=0.0, ao_strength=0.8,
        grime_color=(0.05, 0.004, 0.006),            # clotted/dry edges
        grime_rough=0.7,
    )


# --------------------------------------------------------------------------
# Drop-in replacement for the mats dict build_scene assembles.
#
#   mats = vc_materials.build_pbr_materials(profile, SPEC)
#
# Keys match what build_scene already references (cloth/under/skin/accent/
# metal/hair).  The accent retains its emission so faction collars still glow,
# but now over a blood-leather base instead of flat paint.
def build_pbr_materials(profile, spec_table):
    coat_is_leather = bool(profile.get("long_coat") or profile.get("armored"))
    cloth_fn = leather if coat_is_leather else cloth

    mats = {
        "cloth": cloth_fn("vc_cloth", profile["coat"], spec_table["cloth"]),
        "under": denim("vc_under", profile["under"], spec_table["under"]),
        "skin": pale_skin("vc_skin", profile["skin"], spec_table["skin"]),
        "accent": blood("vc_accent", profile["accent"], spec_table["accent"]),
        "metal": metal("vc_metal", profile["metal"], spec_table["metal"]),
        "hair": cloth("vc_hair", profile["hair"], spec_table["hair"]),
    }

    # Re-add the faction-accent emission the original new_material gave "accent"
    # so the crimson collar still reads as lit trim under the night ambient.
    acc = mats["accent"].node_tree
    bsdf = acc.nodes.get("Principled BSDF")
    if bsdf is not None and "Emission Color" in bsdf.inputs:
        a = profile["accent"]
        bsdf.inputs["Emission Color"].default_value = (a[0], a[1], a[2], 1.0)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = 0.8

    return mats
