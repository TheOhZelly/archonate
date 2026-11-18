# Wallpapers

Archonate's wallpapers come with its styles:

- **The built-in `archonate` style** (`lib/styles/archonate/`): the ARCHONATE
  logo on its own colours, drawn in code by Archonate, under the repo's GPL-3.0.
- **Downloaded themes**: fetched at install time (`archonate style import`),
  wallpapers included, from [github.com/omacom/omarchy](https://github.com/omacom/omarchy)
  and used under their own terms. They are not redistributed here.
- **Your own**: `archonate style from ~/Pictures/x.jpg` makes a style from any
  image, wallpaper included. It stays on your machine.

## Adding your own

`archonate style from <image>` is the easy way. To add wallpapers to a style
you already have, drop images into its `backgrounds/` folder under
`~/.local/share/archonate/styles/<style>/`; the wallpaper switcher
(Super + Ctrl + W) picks them up. If you send any upstream, they need a licence
that allows sharing; most wallpaper sites don't grant one.
