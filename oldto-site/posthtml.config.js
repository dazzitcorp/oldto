/* global module, process, require */

// See https://github.com/parcel-bundler/parcel/issues/1209#issuecomment-942927265

let dotenv = require('dotenv');

function loadDotEnv() {
  let env = {};
  
  let NODE_ENV = process.env.NODE_ENV;

  let dotenvFiles = [
    '.env',
    // Don't include `.env.local` for the `test` environment since
    // tests should produce the same results for everyone.
    NODE_ENV === 'test' ? null : '.env.local',
    `.env.${NODE_ENV}`,
    `.env.${NODE_ENV}.local`
  ].filter(Boolean);
  
  for (let dotenvFile of dotenvFiles) {
    let config = dotenv.config({ path: dotenvFile });
    if (config.parsed) {
      Object.assign(env, config.parsed);
    }
  }

  return env;
}

module.exports = {
  plugins: {
    "posthtml-expressions": {
      locals: loadDotEnv()
    }
  }
};