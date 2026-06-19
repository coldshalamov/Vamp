# Nocturne visual laboratory

The lab is an executable reference implementation for Vampire City’s visual direction. It is not a replacement game client and contains no gameplay systems.

Run from the repository root:

```bash
python3 -m http.server 4173
```

Then open:

```text
http://localhost:4173/visual-lab/
```

Keyboard shortcuts select screens 1–6. The on-screen controls select pass and reduced-motion behavior.

## Deterministic capture

A Playwright Python installation and Chromium can use:

```bash
python3 scripts/capture_lab.py \
  --screen gameplay \
  --pass-no 3 \
  --out /tmp/pass-3-gameplay.png
```

The capture path pins viewport, DPR, animation time, and pass. Golden images should be regenerated only after deliberate visual review.

## Purpose

Agents should use the lab to answer concrete questions before changing production code:

- What is the selected, disabled, cooldown, and hover state of a slot?
- How much ornament is appropriate for a prompt versus a major panel?
- How do blood, cyan, violet, brass, and sodium divide semantic work?
- How does the player remain readable against a dark wet street?
- What changes between pass 1, 2, and 3, and why?

The examples are instructions in executable form. They should be evolved when the production art direction improves.
