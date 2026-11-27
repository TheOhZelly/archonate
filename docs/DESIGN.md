# Archonate's design language

Every app Archonate dresses (the Claude app, Discord, Spotify, Luciole, the
Modrinth app, OBS, and the rest) follows one design language, the one the
Claude app's Code tab has: **one calm background, panels split by hairlines,
neutral fills for hover and selection, the text colour for the main action,
and the accent only for what is live.** The rice supplies the colours and the
shape (font, corners, borders, casing). This page gives the exact values and
rules. When you theme a new app, follow it to the number.

## 1. Where the values come from

Never hard-code a colour or a size. Every value is derived from two sources:

**The palette**: `palette` in the rice's `desktop.json`, written by the
active style. Keys:

| Key | Role |
| --- | --- |
| `bg` | the background, the only one |
| `text` | body text, and the base of every neutral (lines, fills) |
| `text_dim` | secondary text (style-defined) |
| `accent` | what is live: focus, progress, now playing, links, unread |
| `secondary`, `tertiary` | second and third hues: gradients that move (loading bars, the music line), never surfaces |
| `error` | errors and destructive actions only |
| `surface`, `surface_hi`, `muted`, `selection`, `dark_bg` | the style's own; app themes derive from `bg`/`text` instead (section 2) |

**The look**: the rice's `shell/Theme.qml`, read by `lib/desktop.py`
`rice_look(rice)`. For the shipped `archonate` rice:

| Key | Value | Meaning |
| --- | --- | --- |
| `font` | `JetBrainsMono Nerd Font` | the one family for all interface text |
| `radius` (R) | `10` | the corner scale (section 4) |
| `borderWidth` (bw) | `1` | every line and frame, in px |
| `border` | accent at 0.40 alpha | the frame colour of the rice's own panels |
| `caps` | `none` | casing of labels (`none`, `upper`, `lower`, `first`) |
| `tracking` | `0` | letter spacing of labels, in em |
| `panelAlpha` | `0.92` | glass opacity of the shell's own panels |

For Sass themes (Discord, Spotify), `scss_libs()` writes both as
`_colours.scss` and `_look.scss`. For Python-built ones (Luciole, Modrinth,
the Claude app), use `desk["palette"]` and `rice_look(rice)` directly.

## 2. Colour tokens

Every app theme derives the same tokens from `bg` and `text`. Below, `mix(a, b, t)`
blends from a to b by t, so `mix(bg, text, 0.06)` is 6% text over the background.
The Sass equivalent is `color.mix(text, bg, 6%)`.

| Token | Value | Used for |
| --- | --- | --- |
| **bg** | `bg` | every surface: sidebars, main view, players, headers, title bars |
| **raised** | `mix(bg, text, 0.06)` | things that float above: menus, popovers, dialogs, tooltips, embeds |
| **high** | `mix(bg, text, 0.10)` | a raised thing's hover; an input's well, if it needs one |
| **line** | `text` at **0.13** alpha | dividers between panels; frames of inputs, menus, chips, dialogs |
| **hair** | `text` at **0.07** alpha | quieter rules inside a panel: header underlines, list separators |
| **hov** | `text` at **0.05** alpha | hover fill on rows, list items, cards, icon buttons |
| **sel** | `text` at **0.09** alpha | selected or pressed: the current row, nav item, tab |
| **dim** | `mix(bg, text, 0.82)` | secondary text that must still read well (labels, metadata) |
| **faint** | `mix(bg, text, 0.55)` | tertiary text: timestamps, counts, placeholders, disabled |
| **scroll** | `text` at **0.16** alpha, **0.28** on hover | scrollbar thumbs (thin, fully rounded, no track) |
| **focus** | border `accent` + `0 0 0 3px` accent at **0.18** | focused inputs and composers (the "accent glow") |
| **selection** | `accent` at **0.35** alpha | text selection (`::selection`) |
| **shadow** | `0 12px 32px rgba(0, 0, 0, 0.35)` | menus and dialogs only; nothing else casts a shadow |

When an app has fixed slots instead of free CSS, map them like this:

- Luciole uses the `apply_luciole` mapping: `surface*` slots take bg, then 0.06 and 0.09 lifts; `hover` is 0.05; `outline_variant` is 0.13; the `primary` selection slot is a neutral 0.13 lift.
- Spotify's `color.ini` sets `main`, `sidebar` and `player` to bg, `card` to raised, `selected-row` to text (Spotify adds its own low alpha), and `subtext` to `mix(text, bg, 0.45)`.

## 3. Layout and surfaces

1. **One background.** Sidebars, main view, side panels, player bars, title
   bars and headers are all `bg`. No second shade for "the sidebar".
2. **Flush panels, hairline seams.** Panels touch, with no gaps and no rounded
   panel corners, and are divided by a `bw solid line` border on the shared
   edge: `border-right` on a left sidebar, `border-left` on a right one,
   `border-top` on a bottom player, `border-bottom` on a top bar. Never float
   panels as separate cards.
3. **No colour washes.** No gradients from album art, banners, artist colours
   or brand colours behind headers or action bars. Art is shown as art (cover
   images), never smeared into the background.
4. **Elevation only for what floats.** Menus, popovers, dialogs and tooltips
   are `raised`, framed with `bw solid line`, use radius `0.8R`, and cast the
   one **shadow**. Nothing else is raised or shadowed.
5. **Cards are flat.** Background transparent, no shadow, radius `0.8R`;
   hover gives `hov`. Their images take radius `0.6R`.
6. **Lists.** Rows have radius `0.6R`, `hov` on hover, `sel` when selected.
   Column headers sit on bg with a `hair` rule under them.

## 4. Shape

Corners scale from the rice's radius R (10 on `archonate`), rounded to whole pixels:

| Factor | Used for |
| --- | --- |
| `0.3R` | checkboxes, keycaps |
| `0.4R` | small controls, badges |
| `0.5R` | small thumbnails (now-playing cover) |
| `0.6R` | rows, list items, chips, menu items, tags |
| `0.8R` | cards, inputs, search boxes, menus, popovers, card images, large art |
| `1.0R` | dialogs, framed panels |
| `1.2R` | the message composer and other large inputs |
| `9999px` | pills (only when R > 6), avatars, scrollbar thumbs |

**Sharp rices** (R ≤ 6) square everything to R, pills included; only avatars stay round.
**Borders** are always `bw` px (never thinner than 1).

## 5. Colour roles

**The accent is for what is live**, and nothing else:

- focus (input borders, focus rings `bw solid accent`, the focus glow)
- progress and playback (progress fill, loading bars, the playing track's title)
- links, unread markers, mentions, notification dots
- the current item's *text or icon* where an app needs a "you are here" cue

**Never use the accent** for large fills, selected rows or nav items (use
`sel`), side "selected" bars or strips, card or panel backgrounds, or primary
buttons.

**Buttons**:

| Kind | Look |
| --- | --- |
| primary (play, send, save, follow, create) | background `text`, label/icon `bg`; pressed `dim` |
| secondary | transparent, `bw solid line` frame, label `text`; hover `hov` |
| icon / ghost | transparent, icon `dim`; hover `hov` and icon `text` |
| destructive | label `error`; filled `error` only in a confirmation dialog |
| chips / filters | transparent with a `line` frame and `dim` label; selected: filled `text`, label `bg` |

**States**: hover `hov`; selected or pressed `sel`; disabled is the `faint` label
with no fill. No state is shown by colour alone when a fill can show it.

## 6. Type

- **One family**, the rice's `font`, for everything: body, buttons, inputs,
  titles and big display headings (album titles included).
- **Code** stays monospace: `JetBrainsMono Nerd Font`, then `JetBrains Mono`,
  then `monospace`.
- **Labels** take the rice's casing and tracking: tabs, section and column
  headers, badges, segmented controls, filter chips. Never apply them to
  content: names, titles, messages, track names, anything the user or
  someone else wrote. With `caps: upper`, tracking is at least `0.6/13 em`
  and at most `1.6/13 em`.
- Display headings may tighten to `-0.02em`; nothing else changes letter spacing.

## 7. Motion and life

- Colour and border transitions: `0.15s ease`. Movement: `200ms`, ease-out
  cubic. No bounce, no overshoot, no fade-ins on content that is ready.
- **Live restyling.** A style switch must reach every open app without the
  user doing anything. In order of preference:
  1. The app watches a file Archonate writes (Luciole `colors.toml`, the
     Modrinth `modrinth.css` via its shim, OBS with `AutoReload`, Vencord's
     theme folder).
  2. Archonate signals it (`killall -USR2` for btop and cava, `hyprctl reload`
     for Hyprland, an IPC call for the shell).
  3. Archonate restarts it in the background and puts it back as it was
     (Spotify resumes the same track at the same position).
- Restyles run on-screen first, the rest in a background queue; a newer
  switch cancels an older one (`swap_rest`).

## 8. How an app theme is built

- **Anchor on what lasts.** In order: the app's own design tokens (CSS
  custom properties such as `--background-base` or `--color-bg`), `data-*`
  attributes (`data-cds`, `data-testid`, `data-list-item-id`), then the
  readable start of class names (`[class^="name_"]`, `.Root__*`,
  `.main-*-*`). Never a hashed class name: it changes with every app update.
- **Override tokens before elements.** Set the app's variables with
  `!important` on the elements that define them. If the app sets a variable
  inline (a page colour), pin it with `[style*="--var"]` or a scoped
  descendant rule.
- **Never modify an app's files.** Use the app's theme mechanism (Vencord,
  Spicetify, OBS themes, GTK CSS, a palette file). Where there is none, inject
  a stylesheet at runtime without touching the install (Modrinth's preload
  shim). Don't patch the Claude app, and don't open debug ports.
- **Generated files** start with a "Generated by Archonate" comment, are
  rewritten on every style switch, and live under the user's config, never
  in the repo.
- **Fail soft.** Each app's theming runs in its own `safely(...)`. A broken
  or missing app logs one line and the rest still restyle. An app that isn't
  installed is skipped silently.
- **Per-rice additions.** A rice can add to a shared theme
  (`rices/<rice>/discord.scss`) or replace it (`discord.theme.scss`); the
  shared one is the fallback.

## 9. The apps

| App | Mechanism | Source | Written to |
| --- | --- | --- | --- |
| Claude app | its theme tokens + `claude_css()` | `lib/desktop.py` `apply_claude` | the app's theme file |
| Discord | Vencord/Equicord theme, Sass | `lib/templates/discord.scss` | `~/.config/<client>/themes/archonate.theme.css` |
| Spotify | Spicetify colour scheme + `user.css`, Sass | `lib/templates/spotify.scss`, `apply_spotify` | `~/.config/spicetify/Themes/hypr-rice/` |
| Luciole | palette file + corner scale | `apply_luciole` | `~/.config/luciole/colors.toml`, `config.toml` |
| Modrinth app | preloaded stylesheet shim | `lib/modrinth/inject.c`, `apply_modrinth` | `~/.config/archonate/modrinth.css` |
| OBS | Qt theme, auto-reloaded | `apply_obs` | OBS's themes folder |
| Thunar / GTK | GTK CSS | `lib/templates/thunar.css`, `apply_gtk` | `~/.config/gtk-{3,4}.0/` |
| btop, cava, htop, nvtop, Zed, Qt | colour templates | `lib/templates/*` | each app's config |

## 10. Checklist for a new app

1. Find the app's theme mechanism. If it has none, find a runtime injection
   point that leaves its files alone.
2. Set every surface to **bg**, and remove gaps, panel rounding and washes.
3. Put **line** seams on the shared edges and **hair** under headers.
4. Make **hov** and **sel** the only hover and selection fills; remove accent
   fills and side bars.
5. Make primary buttons **text on bg**; keep the accent for focus, progress,
   playing, links and unread.
6. Give menus, popovers and dialogs **raised**, a **line** frame, `0.8R` and
   the one **shadow**.
7. Apply the rice's **font** everywhere, mono for code, and **casing and
   tracking** on labels only.
8. Scale every corner from **R** (section 4), and use **bw** for every line.
9. Make it restyle **live** (section 7), and wire it into `apply_apps` inside
   `safely(...)`.
10. Check it with two very different styles (a light-text one and a
    saturated one), on a real screen. Never check while the user is gaming
    or watching something.
