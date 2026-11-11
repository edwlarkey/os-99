# OS 99

Mac OS 9 Platinum window frames for Hyprland. Square corners, a chiselled
bezel, a pinstriped title bar, a hard drop shadow.

Not a port, and not affiliated with Apple.

![OS 99 Platinum](preview.png)

## Install

```
git clone https://github.com/edwlarkey/os-99
cd os-99
./install
```

That builds the frame plugin against your Hyprland, draws the art at your
display’s scale, and hooks your Hyprland config. Re-run `./install` after
`git pull` or a Hyprland update.

Needs Hyprland 0.56.2+, its headers (`pkg-config hyprland`), a C++ compiler,
and Python 3.11+.

ChicagoFLF is a public-domain stand-in for Charcoal and looks right in the
title bar. Optional:

```
# Arch
yay -S ttf-chicagoflf
```

## Use

| command | |
|---|---|
| `os99` | status |
| `os99 reload` | redraw after editing `~/.config/hypr/os99-theme.toml` |
| `os99 buttons` | which boxes the title bar carries |
| `os99 buttons toggle shade` | add or remove a box |
| `os99 min` | park the active window |
| `os99 min list` / `os99 min restore` | bring it back |
| `os99 uninstall` | take the frames off |

Default boxes are OS 9: close on the left, zoom and collapse on the right.
Collapse parks the window on workspace `os99-minimized` (Hyprland has no
minimize). `os99 min restore` brings back the most recent; switching to that
workspace also works.

## Tuning

Edit `~/.config/hypr/os99-theme.toml` and run `os99 reload`. Ridge count,
bezel, shadow, colours, font.

The art is generated at your monitor’s scale and blitted 1:1, so a 1px
pinstripe stays 1px. Change scale and the next reload redraws.

## Licence

MIT. The hyprbars fork in `plugin/` keeps its BSD 3-Clause licence.
