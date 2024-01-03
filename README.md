# ReNodeConfig
[![npm version][npmimg]][npm]
![ci tests](https://github.com/veikkaus/re-node-config/actions/workflows/tests.yml/badge.svg)

Config library for nodejs, similar to [node-config](https://github.com/lorenwest/node-config) but strongly typed with validated type parsing. No need for Js.Nullable.t shims typical when just binding to js-libs. Configuration data is a JSON Object loaded by a loader function (see below).


# Install
```
npm install @veikkaus/rescript-node-config
```
And to `bsconfig.json`: `"bs-dependencies": [..., "@veikkaus/rescript-node-config", ...],`


# Usage Examples

Assuming You Write file MyConfig.res:
```rescript
module C = VeikkausRescriptNodeConfig.Config;

/*
 * loadConfig with default options searches for .json and .yaml files from ./config/
 * (loading may produce an error, therefore using getExn, which will throw if loading had errors)
 */
let config: C.t = C.loadConfig() |> C.getExn;
```

Usage in other files/modules:
```rescript
module C = VeikkausRescriptNodeConfig.Config;
let config = MyConfig.config;

let host: string = C.getString("server.host", config);
let port: int = C.getInt("server.port", config);

/* getString is actually a convenience function which combines the following detailed functionality:
 *   getString = (path, config) => config |> C.key("server.host") |> C.parseString |> C.getExn;
 *   meaning ~ get a string value from the defined configuration path or throw exception MissingKey or
 *             TypeMismatch
 */

/* Parsing lists of values is fairly simple too: */
let myList: list<string> = config |> C.key("listOfWords") |> C.parseList(C.parseString) |> C.getExn;


/* Finally providing that you implement a parser from json to your own type: */
type foo;
let myJsonToFoo: Js.Json.t => foo;     /* May throw on parsing errors */
/* then that can be used to turn complicated object on your config into your custom type: */
let myFoo: foo = config |> C.key("foo") |> C.parseCustom(myJsonToFoo) |> C.getExn;
```

# Config loading

Function `C.loadConfig()` searches config values from following sources in following order:
1. Loads config files from directory defined by `NODE_CONFIG_DIR` env variable if it exists, or otherwise from directory `process.cwd() + "/config/"`:
   1. File `default.{json,yaml}` is loaded if it exists
   2. File `${NODE_CONFIG_ENV}.{json,yaml}` is loaded if it exists, and if not, then and only then `${NODE_ENV}.{json,yaml}` is loaded if that exists.
   3. File `local.{json,yaml}` is loaded if exists.
2. Loads Environment Variables
   1. Loads `CONFIG_JSON` contents
   2. Reads file `custom-environment-variables.{json,yaml}`, which contains ENV variable name override definitions for various config keys (this is identical to: [node-config](https://github.com/lorenwest/node-config/wiki/Environment-Variables#custom-environment-variables)), -> loads overrides from the defined env variables that are found.
   JSON parsing is attempted to the values of the env variables, enabling e.g. passing lists inside one env variable: `MYVAR='["first","second"]'`. If the attempted JSON parsing fails, the value is treated as a simple string e.g. `MYVAR2="value2"` (= simple string. note that json would need extra quotations: `"\"value2\""`)
3. Fallback to empty config if nothing from the above exists.


[npmimg]: https://img.shields.io/npm/v/@veikkaus/rescript-node-config.svg
[npm]: https://www.npmjs.com/package/@veikkaus/rescript-node-config
