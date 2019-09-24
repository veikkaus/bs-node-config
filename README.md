# bs-node-config
Node dependent reasonml config library



# Usage Examples


Assuming You Write file Config.re:
```ocaml
module C = BsNodeConfig.Config;

/*
 * loadConfig with default options searches for .json and .yaml files from ./config/
 * (loading may produce an error, therefore get or throw)
 */
let config: C.t = C.loadConfig() |> C.getExn;
```

Usage in other files/modules:
```ocaml
module C = BsNodeConfig.Config;

let myServerHost = Config.config |> C.key("server.host") |> C.parseString |> C.getExn;

/* This alternative style works too: */

let myServerPort = C.(fetchExn("server.port", parseInt, Config.config));

let myWords = C.(fetchExn("listOfWords", parseList(parseString), Config.config));
```