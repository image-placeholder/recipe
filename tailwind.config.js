/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './_site/**/*.{html,md}',       // all generated HTML
    './src/**/*.js',           // all JS files with dynamic classes
    './_includes/**/*.{html,md}',   // if using Jekyll includes
    './_layouts/**/*.{html,md}',    // if using Jekyll layouts
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
