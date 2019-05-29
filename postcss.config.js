const url = require("postcss-url");
const imports = require("postcss-import");
const nested = require("postcss-nested");
const postCSSPresetEnv = require("postcss-preset-env");
const browsers = require("browserslist");
const cssnano = require("cssnano");
const color = require("postcss-color-mod-function");
const mixins = require("postcss-mixins");

const path = require('path');

module.exports = (asd) => ({
    plugins: [
        url,
        imports({
            path: path.join(__dirname, 'assets/css'),
        }),
        mixins,
        nested,
        postCSSPresetEnv({
            stage: 0,
            // preserve: true,
            features: {
                "custom-properties": true,
            },
        }),
        cssnano({
            preset: "default",
        }),
        color,
    ],
});
