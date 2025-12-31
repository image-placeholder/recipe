/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './_site/**/*.{html,md}',       // all generated HTML
    './assets/**/*.js',           // all JS files with dynamic classes
    './assets/**/*.css',           // all CSS files with TW classes
    './_includes/**/*.{html,md}',   // if using Jekyll includes
    './_layouts/**/*.{html,md}',    // if using Jekyll layouts
    './_pages/**/*.{html,md}',    // if using Jekyll layouts
    './*.html',                // any top-level HTML
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('tailwindcss'),
    require('autoprefixer'),
  ],
};
