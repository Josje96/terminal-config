-- Match the Ghostty theme: theme = light:Ayu Light,dark:Ayu
-- Nvim auto-detects the terminal background, so "background" follows
-- Ghostty's light/dark switching (light: Ayu Light, dark: Ayu).
return {
  { "Shatur/neovim-ayu", opts = { mirage = false } },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "ayu",
    },
  },
}
