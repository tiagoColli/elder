const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/elder_web.ex",
    "../lib/elder_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
        page: "rgb(var(--color-page) / <alpha-value>)",
        surface: "rgb(var(--color-surface) / <alpha-value>)",
        "surface-raised": "rgb(var(--color-surface-raised) / <alpha-value>)",
        field: "rgb(var(--color-field) / <alpha-value>)",
        primary: "rgb(var(--color-primary) / <alpha-value>)",
        secondary: "rgb(var(--color-secondary) / <alpha-value>)",
        muted: "rgb(var(--color-muted) / <alpha-value>)",
        "base-border": "rgb(var(--color-base-border) / <alpha-value>)",
        "raised-border": "rgb(var(--color-raised-border) / <alpha-value>)",
        accent: "rgb(var(--color-accent) / <alpha-value>)",
        "accent-text": "rgb(var(--color-accent-text) / <alpha-value>)",
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    plugin(({addBase}) => {
      let heroiconsPath = path.join(__dirname, "../deps/heroicons/optimized")
      let iconsDir = fs.existsSync(heroiconsPath) ? heroiconsPath : null

      if (!iconsDir) return

      let icons = [
        ["", "outline"],
        ["-solid", "solid"],
        ["-mini", "mini"]
      ]

      addBase({
        "[class^='hero-']": {
          display: "inline-block",
          width: "1.25rem",
          height: "1.25rem",
          "vertical-align": "middle",
          "background-size": "100% 100%"
        }
      })

      icons.forEach(([suffix, dir]) => {
        let dirPath = path.join(heroiconsPath, dir)
        if (!fs.existsSync(dirPath)) return

        fs.readdirSync(dirPath).forEach(file => {
          let name = path.basename(file, ".svg") + suffix
          let fullPath = path.join(dirPath, file)
          let svg = fs.readFileSync(fullPath, "utf8").replace(/\r?\n/g, "")

          addBase({
            [`.hero-${name}`]: {
              "background-image": `url('data:image/svg+xml;utf8,${svg}')`
            }
          })
        })
      })
    })
  ]
}
