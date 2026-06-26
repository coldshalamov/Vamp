# Vamp Local Safety

- Do not run a raw recursive GUT suite on Windows. It has caused Godot to consume tens of GB of RAM and lock the machine.
- Use `powershell -ExecutionPolicy Bypass -File .\scripts\RunGutSafe.ps1` for local test checks.
- Full local GUT is blocked unless `VAMP_ALLOW_FULL_GUT=1` is deliberately set. Prefer CI for the full suite.
- Do not launch the game locally unless the user explicitly asks. `PlayGame.bat` is the normal full-presentation game launcher; `PlayGame.bat --safe` is only an emergency reduced-visual fallback.
- Before any Godot launch, check Task Manager/process state and keep the run bounded.

# Visual / Character Asset Pipeline (how to run it)

Full spec: `docs/CHARACTER_PIPELINE_SPEC.md`. The method is **3D-render-to-sprite + image-gen paint**
(image-gen CANNOT do frame-coherent animation — use it for design + repainting, NOT animation frames).

## Image generation (CLI tools on this machine)
- **agy** — the ONLY scriptable img2img/repaint tool. Headless: `agy --dangerously-skip-permissions -p "<prompt, save PNG to absolute path>"`. Supports input/reference images (repaint a render). **Has a DAILY rate limit** — heavy use exhausts it (then it returns instantly with no file / empty log). One reliable image per separate invocation; rapid repeats and parallel calls FAIL — space them out + retry.
- **grok** — headless is **`grok -p "<prompt>"`** (NOT `--always-approve`, which opens the TUI). Its image tool is **text-to-image only** (no reference/img2img — "reference_image_paths not supported"). Use for generating designs, not repainting renders.
- **codex** = coding agent (gpt-5.5), NO image generation. **gemini** CLI = dead (tier error).

## Blender (5.1.2, CPU-only Cycles — slow; keep samples low)
- Binary: `C:\Program Files\Blender Foundation\Blender 5.1\blender.exe`.
- Headless render: `blender --background --python <script> -- <args>`.
- The interactive Blender MCP `render_viewport_to_path` TIMES OUT (~60s) — use headless for batches.
- Use the **Rigify human meta-rig** for correct proportions (NOT primitives-from-scratch → dolls):
  `bpy.ops.object.armature_human_metarig_add()` (legs ~50% height, head ~1/6, broad shoulders).

## Character production scripts (`tools/visual/`)
- `render_hero_clay.py` — proportioned hero, idle/walk/attack × directions → rough clay frames (`--out <dir> --dirs N`).
- `paint_grind.sh <clay> <painted> assets/visual/reference/hero_bible.png 70` — repaint each clay frame via agy (idempotent, retry, cooldown). Runs hours; gated on agy quota.
- `assemble_painted_hero.py` — cutout (scipy flood-fill) + baseline-align + 8-col atlas.
- In-engine: the painted (pre-lit) atlas needs the character material **`render_mode unshaded`** (else the dark night 2D-lights + grade crush it to a silhouette). See `art/shaders/hero_rim.gdshader`.
