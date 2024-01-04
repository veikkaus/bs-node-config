exception MissingKey(string);
exception TypeMismatch(string);

type t;
type r<'a>;
type parser<'a> = t => r<'a>;

/* 
 * Loading config
 * 
 * Usage example:
 * let config: Config.t = Config.loadConfig() ->Config.getExn;
 */

let loadConfig: unit => r<t>;

let get: r<'a> => option<'a>;
let getExn: r<'a> => 'a;
let result: r<'a> => Belt.Result.t<'a, exn>;

/*
 * Core operations: traversing configuration with key() function and extracting values
 * 
 * Usage example:
 * let nameList: list<string> =
 *   config ->Config.key("example.hosts") ->Config.parseList(Config.parseString) ->Config.getExn;
 * 
 * let myStruct: myStruct = config ->Config.key("deep") ->Config.parseCustom(jsonToMyStructParser) ->Config.getExn;
 */

let key: t => string => t;
let keyHasValue: t => string => bool;  /* key exists and value is other than json null */

let parseBool: parser<bool>;
let parseString: parser<string>;
let parseFloat: parser<float>;
let parseInt: parser<int>;

let parseList: t => parser<'a> => r<list<'a>>;
let parseDict: t => parser<'a> => r<Js.Dict.t<'a>>;
let parseCustom: t => (Js.Json.t => 'a) => r<'a>;

/*
 * Simplified API for common cases. On error throws.
 * 
 * Usage example:
 * let hostName: string = Config.getString(config, "server.host");
 * let hostPort: int = Config.getInt(config, "server.port");
 */
let getBool: t => string => bool;
let getString: t => string => string;
let getFloat: t => string => float;
let getInt: t => string => int;

let getList: t => string => parser<'a> => list<'a>
let getDict: t => string => parser<'a> => Js.Dict.t<'a>;
