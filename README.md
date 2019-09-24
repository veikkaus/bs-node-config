[![npm](https://img.shields.io/npm/v/bs-node-config.svg)](https://www.npmjs.com/package/bs-node-config)

# BsNodeConfig

Config library for nodejs, similar to [node-config](https://github.com/lorenwest/node-config) but strongly typed with validated type parsing. No need for Js.Nullable.t shims typical when just binding to js-libs.



# Usage Examples


Assuming You Write file MyConfig.re:
```ocaml
module C = BsNodeConfig.Config;

/*
 * loadConfig with default options searches for .json and .yaml files from ./config/
 * (loading may produce an error, therefore using getExn, which will throw if loading had errors)
 */
let config: C.t = C.loadConfig() |> C.getExn;
```

Usage in other files/modules:
```ocaml
module C = BsNodeConfig.Config;
let config = MyConfig.config;

let myServerHost: string = config |> C.key("server.host") |> C.parseStringExn;
let myList: list(string) = config |> C.key("listOfWords") |> C.parseList(C.parseString) |> C.getExn;

/* This alternative style works too: */
let myServerPort: int = C.(fetchExn("server.port", parseInt, Config.config));
```

# Config loading

Function `C.loadConfig()` searches config values from following sources in following order:
1. Loads config files:
   1. From directory `process.cwd() + "/config/"`  OR if env variable `NODE_CONFIG_DIR` is defined, that is used instead:
   2. `default.{json,yaml}` is load if exists
   3. Profile name defined by `NODE_CONFIG_ENV` if exists or `NODE_ENV` if exists -> loads file `${profileName}.{json,yaml}` if exists
   4. `local.{json,yaml}` is load if exists
2. Loads Environment Variables
   1. Loads `CONFIG_JSON` contents
   2. Reads file `custom-environment-variables.{json,yaml}`, which contains ENV variable name override definitions for various config keys (this is identical to: [node-config](https://github.com/lorenwest/node-config/wiki/Environment-Variables#custom-environment-variables)), -> loads overrides from the defined env variables that are found.
3. Fallback to empty config if nothing from the above exists.
