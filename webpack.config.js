const path = require("path");
const webpack = require("webpack");

module.exports = {
  entry: {
    site: "./source/javascripts/site.js"
  },
  // resolve: {
  //   root: __dirname + "/source/javascripts",
  // },
  output: {
    path: path.join(__dirname, "dist"),
    filename: "javascripts/[name].js",
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader",
          options: {
            presets: ["@babel/preset-env"]
          }
        }
      }
    ]
  }
};
