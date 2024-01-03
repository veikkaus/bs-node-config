exception MissingKey(string);
exception TypeMismatch(string);

type t;
type r<'a>;
type parser<'a> = t => r<'a>;

/* 
 * Loading config
 * 
 * Usage example:
 * let config: Config.t = Config.loadConfig() |> Config.getExn;
 */

let loadConfig: unit => r<t>;

let get: r<'a> => option<'a>;
let getExn: r<'a> => 'a;
let result: r<'a> => Belt.Result.t<'a, exn>;

/*
 * Core operations: traversing configuration with key() function and extracting values
 * 
 * Usage example:
 * let nameList: list(string) =
 *   config |> Config.key("example.hosts") |> Config.parseList(Config.parseString) |> Config.getExn;
 * 
 * let myStruct: myStruct = config |> Config.key("deep") |> Config.parseCustom(jsonToMyStructParser) |> Config.getExn;
 */

let key: string => t => t;
let keyHasValue: string => t => bool;  /* key exists and value is other than json null */

let parseBool: parser<bool>;
let parseString: parser<string>;
let parseFloat: parser<float>;
let parseInt: parser<int>;

let parseList: parser<'a> => parser<list<'a>>;
let parseDict: parser<'a> => parser<Js.Dict.t<'a>>;
let parseCustom: (Js.Json.t => 'a) => parser<'a>;

/*
 * Simplified API for common cases.
 * 
 * Usage example:
 * let hostName: string = Config.getString("server.host", config);
 * let hostPort: int = Config.getInt("server.port", config);
 */
let getBool: string => t => bool;
let getString: string => t => string;
let getFloat: string => t => float;
let getInt: string => t => int;
