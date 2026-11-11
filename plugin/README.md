# hyprbars, forked for OS 99

Fork of [hyprbars](https://github.com/hyprwm/hyprland-plugins). BSD 3-Clause.

It still reports itself to Hyprland as `hyprbars`, so it cannot load alongside
upstream hyprbars.

## What the fork adds

- **Nine-patch frame** around the whole window, title bar as the top edge.
- **`frame_texture_unscaled`** — blit art 1:1 so a pinstripe does not moiré.
- **Per-button `side` and `image`.**
- **`clear_buttons()`** so Lua-added buttons survive a config reload.
- **`frame_force_square` / `frame_force_flat`** — rounding 0, no blur/dim.
- **Teardown guards** so unloading the plugin does not abort the compositor.

Built against Hyprland 0.56.2+. `./install` compiles it against your headers.
