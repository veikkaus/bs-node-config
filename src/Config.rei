exception MissingKey(string);
exception TypeMismatch(string);

type t;
type r('a);

let loadConfig: unit => r(t);

let key: string => t => t;

type parser('a) = t => r('a);

let parseBool: parser(bool);
let parseString: parser(string);
let parseFloat: parser(float);
let parseInt: parser(int);
let parseList: parser('a) => parser(list('a));
let parseDict: parser('a) => parser(Js.Dict.t('a))
let parseCustom: (Js.Json.t => 'a) => parser('a);

let get: r('a) => option('a);
let getExn: r('a) => 'a;
let result: r('a) => Belt.Result.t('a, exn);

let raw: t => Belt.Result.t(Js.Json.t, exn);

let fetch: string => parser('a) => t => option('a);
let fetchExn: string => parser('a) => t => 'a;
