# KiyArch visual identity — Midnight Forge

Midnight Forge is KiyArch's original visual system. It takes inspiration from
well-crafted, keyboard-first Linux desktops without reusing another project's
name, symbols, artwork, layouts, or cultural motifs.

## Idea

**Quiet machinery, ready for work.** KiyArch should feel like a precise tool
built in a dark workshop: calm at rest, warm where attention is required, and
clear when an action is dangerous.

The interface avoids decorative noise. Thin rules and compact labels provide
structure; warm highlights identify the next action; generous dark space keeps
information readable.

## Palette

| Token | Hex | Use |
| --- | ---: | --- |
| Forge | `#0B0D0F` | Primary background |
| Iron | `#15191D` | Raised surfaces |
| Steel | `#2A3036` | Borders and inactive controls |
| Ash | `#A7ADB2` | Secondary text |
| Chalk | `#F1EEE8` | Primary text |
| Ember | `#E87832` | Focus, selection, progress, links |
| Heat | `#FFB15C` | Hover and high-emphasis accents |
| Temper | `#58A6A6` | Informational and verified states |
| Warning | `#E0A84B` | Warnings requiring attention |
| Failure | `#D65D5D` | Errors and destructive actions |

Ember is an accent, not a background. Large orange areas undermine the quiet,
technical character and reduce the meaning of highlighted controls.

## Typography

- Interface: a neutral sans serif such as **Inter**, **Rubik**, or Noto Sans.
- Terminal and technical labels: **Cascadia Code**, **JetBrains Mono**, or an
  available monospace fallback.
- Use uppercase sparingly for short structural labels such as `INSTALL`,
  `NETWORK`, and `TARGET DISK`.
- Prefer tabular numerals for sizes, temperatures, times, and progress.

## Shape and composition

- Corners are modest: 6–10 px on panels and 3–6 px on controls.
- Borders are one pixel and low contrast until focused.
- Shadows are broad and subtle; focused windows use an Ember border rather
  than a bright glow.
- Spacing follows an 8 px rhythm.
- Motion is quick and deliberate. Avoid elastic or playful movement for core
  system surfaces.

## Mark

The KiyArch mark combines a terminal chevron with an angular arch/anvil form.
It may appear alone in compact spaces. Do not combine it with Japanese text,
Ryoku's `力` symbol, or third-party artwork.

## Voice

Copy is short, direct, and calm:

- `Choose a target disk`
- `Plan verified`
- `Installation stopped safely`

Avoid pretending that risky operations are effortless. Destructive actions
must remain explicit even when the surrounding interface is polished.

## Surfaces

The same hierarchy applies from boot to desktop:

1. **Forge** background
2. **Iron** surface
3. **Steel** structure
4. **Chalk** content
5. **Ember** current action
6. semantic warning/failure colors only when required

The live ISO uses ANSI approximations of these colors so it remains legible on
the Linux console and over SSH. Graphical surfaces use the exact palette.
