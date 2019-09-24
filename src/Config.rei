exception MissingKey(string);
exception TypeMismatch(string);

type t;
type r('a);
type parser('a) = t => r('a);

/* 
 * Usage example:
 * let config: Config.t = Config.loadConfig() |> Config.getExn;
 */

let loadConfig: unit => r(t);

let get: r('a) => option('a);
let getExn: r('a) => 'a;
let result: r('a) => Belt.Result.t('a, exn);

/*
 * Usage example:
 * let myServerHost = config |> Config.key("server.host") |> Config.parseStringExn;
 */

let key: string => t => t;

/* Convenient extractors for simple types */
let parseBoolExn: t => bool;
let parseStringExn: t => string;
let parseFloatExn: t => float;
let parseIntExn: t => int;

/*
 * Usage example:
 * let nameList: list(string) =
 *   config |> Config.key("example") |> Config.parseList(Config.parseString) |> Config.getExn;
 */
let parseBool: parser(bool);
let parseString: parser(string);
let parseFloat: parser(float);
let parseInt: parser(int);

let parseList: parser('a) => parser(list('a));
let parseDict: parser('a) => parser(Js.Dict.t('a))
let parseCustom: (Js.Json.t => 'a) => parser('a);

let fetch: string => parser('a) => t => option('a);
let fetchExn: string => parser('a) => t => 'a;
