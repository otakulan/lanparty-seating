module.exports = {
  purge: ["../lib/*_web/**/*.*ex", "js/**/*.js"],
  content: [],
  theme: {
    container: {
      center: true,
    },
    extend: {},
  },
  plugins: [require("daisyui")],
}
