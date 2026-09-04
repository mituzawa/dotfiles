local wezterm = require 'wezterm'

local config = wezterm.config_builder()
config.automatically_reload_config = true
config.font_size = 12.0
config.use_ime = true
config.window_background_opacity = 0.85
config.window_decorations = "TITLE"

config.window_frame = {
  inactive_titlebar_bg = "none",
  active_titlebar_bg = "none",
}
config.window_background_gradient = {
  colors = { "#000000" },
}

config.colors = {
  tab_bar = {
    inactive_tab_edge = "none",
  },
}

config.default_prog = { 'wsl.exe', '--distribution', 'Ubuntu', '--cd', '~' }

return config