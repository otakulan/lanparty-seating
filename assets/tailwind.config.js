module.exports = {
  content: ["../lib/*_web/**/*.*ex", "js/**/*.js"],
  theme: {
    container: {
      center: true,
    },
    extend: {},
  },
  plugins: [
    require("@tailwindcss/typography"),
    require("daisyui"),
  ],
}
