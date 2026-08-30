return {
  "sphamba/smear-cursor.nvim",
  event = "VeryLazy",
  opts = {
    stiffness = 0.8,
    trailing_stiffness = 0.5,
    distance_stop_animating = 0.3,
    -- tokyonight runs with transparent = true and Ghostty at 0.65 opacity, so
    -- smear has no real background colour to blend against without this.
    transparent_bg_fallback_color = "#1e1e2e",
  },
}
