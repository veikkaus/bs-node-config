exception MissingKey(string);
exception TypeMismatch(string);

type r('a) = Belt.Result.t('a, exn);
type t = {
  name: string,
  value: r(Js.Json.t)
};

module Util {

  module JsYamlBind {
    type schema;

    [@bs.deriving abstract]
    type safeLoadOptions = {
      schema: schema,
      json: bool,
    };
    [@bs.val] [@bs.module "js-yaml"] external jsonSchema: schema = "JSON_SCHEMA";
    [@bs.val] [@bs.module "js-yaml"] external safeLoad: (string, safeLoadOptions) => Js.Json.t = "safeLoad";
  };

  let parseYaml: string => r(Js.Json.t) =
    rawStr =>
      try (Belt.Result.Ok(JsYamlBind.safeLoad(rawStr, JsYamlBind.safeLoadOptions(~schema=JsYamlBind.jsonSchema, ~json=false)))) {
        | error => Error(error)
      };

  let parseJson: string => r(Js.Json.t) =
    rawStr =>
      try (Ok(Js.Json.parseExn(rawStr))) {
        | error => Error(error)
      };

  let rec mergeJson: Js.Json.t => Js.Json.t => Js.Json.t =
    (a, b) => switch (Js.Json.classify(a), Js.Json.classify(b)) {
      | (JSONObject(x), JSONObject(y)) => {
        let keys = Belt.Array.concat(Js.Dict.keys(x), Js.Dict.keys(y)) -> Belt.Set.String.fromArray -> Belt.Set.String.toArray;
        Belt.Array.map(keys, key => switch (Js.Dict.get(x, key), Js.Dict.get(y, key)) {
          | (Some(v1), Some(v2)) => (key, mergeJson(v1, v2))
          | (Some(v1), None) => (key, v1)
          | (None, Some(v2)) => (key, v2)
          | (None, None) => (key, Js.Json.null)
        })
        |> Js.Dict.fromArray
        |> Js.Json.object_
      }
      | (_, _) => b
    };

  module OptionList {
    let getSome: list(option('a)) => option('a) =
      list => list -> Belt.List.keep(Belt.Option.isSome) -> Belt.List.map(Belt.Option.getExn) -> Belt.List.head;
  };
};
  
module Loaders {
  [@bs.val] external environment: Js.Dict.t(string) = "process.env";
  [@bs.val] external processCwd: unit => string = "process.cwd";

  type loader = unit => r(Js.Json.t);
  type parser = string => r(Js.Json.t);

  let emptyConfig = Belt.Result.Ok(Js.Json.object_(Js.Dict.empty()));

  let envParameterLoader: string => loader =
    (envParameterName, ()) =>
      switch (Js.Dict.get(environment, envParameterName)) {
        | Some(value) => Util.parseJson(value)
        | None => emptyConfig
      };
  
  let envConfigJsonLoader: loader = envParameterLoader("CONFIG_JSON");

  let getConfigFilePath: unit => string =
    () =>
      Js.Dict.get(environment, "NODE_CONFIG_DIR")
      -> Belt.Option.getWithDefault(Node.Path.join2(processCwd(), "config"));

  let getConfigProfile: unit => option(string) =
    () =>
      Util.OptionList.getSome([
        Js.Dict.get(environment, "NODE_CONFIG_ENV"),
        Js.Dict.get(environment, "NODE_ENV"),
      ]);

  let loadFileIfExists: parser => string => r(Js.Json.t) =
    (parser, filename) => if (Node.Fs.existsSync(filename)) {
      Node.Fs.readFileAsUtf8Sync(filename) -> parser
    } else {
      emptyConfig
    };

  let fileLoader: parser => string => loader =
    (parser, filename, ()) =>
      Node.Path.join2(getConfigFilePath(), filename) |> loadFileIfExists(parser);

  let profileFileLoader: parser => string => loader =
    (parser, ext, ()) => switch (getConfigProfile()) {
      | Some(profile) => Node.Path.join2(getConfigFilePath(), profile ++ ext) |> loadFileIfExists(parser)
      | None => emptyConfig
    };

  let rec substitute: Js.Json.t => Js.Json.t =
    json => switch(Js.Json.classify(json)) {
      | JSONObject(obj) => Js.Dict.entries(obj)
        -> Belt.Array.map(((key, value)) => switch (Js.Json.classify(value)) {
          | JSONString(envParameterName) => switch (Js.Dict.get(environment, envParameterName)) {
            | Some(value) => try (Some((key, Js.Json.parseExn(value)))) {
              | _ => Some((key, Js.Json.string(value)))
            }
            | None => None
          }
          | _ => Some((key, substitute(value)))
        })
        -> Belt.Array.keep(Belt.Option.isSome)
        -> Belt.Array.map(Belt.Option.getExn)
        -> Js.Dict.fromArray -> Js.Json.object_
      | _ => json
    };

  let customEnvParamsLoader: parser => string => loader =
    (parser, ext, ()) =>
      (Node.Path.join2(getConfigFilePath(), "custom-environment-variables" ++ ext)
       |> loadFileIfExists(parser))
      -> Belt.Result.map(substitute);
};

let loadConfig: unit => r(t) =
  () => {
    let results = [
      Loaders.fileLoader(Util.parseJson, "default.json")(),
      Loaders.fileLoader(Util.parseYaml, "default.yaml")(),
      Loaders.profileFileLoader(Util.parseJson, ".json")(),
      Loaders.profileFileLoader(Util.parseYaml, ".yaml")(),
      Loaders.fileLoader(Util.parseJson, "local.json")(),
      Loaders.fileLoader(Util.parseYaml, "local.yaml")(),
      Loaders.envConfigJsonLoader(),
      Loaders.customEnvParamsLoader(Util.parseJson, ".json")(),
      Loaders.customEnvParamsLoader(Util.parseYaml, ".yaml")(),
      ];
    let mergedResult = results -> Belt.List.reduce(
      Loaders.emptyConfig,
      (acc, item) => acc -> Belt.Result.flatMap(
        accJson => item -> Belt.Result.map(itemJson => Util.mergeJson(accJson, itemJson))));
    mergedResult -> Belt.Result.map(result => {
        name: "",
        value: Ok(result),
    });
  };

let rec pickPath: r(Js.Json.t) => string => list(string) => r(Js.Json.t) =
  (item, resolved, keyPath) =>
    if (Belt.List.length(keyPath) == 0) {
      item
    } else {
      let key = Belt.List.headExn(keyPath);
      let resolving = resolved ++ "." ++ key;
      Belt.Result.flatMap(item, json =>
        switch (Js.Json.decodeObject(json)) {
          | Some(dict) => switch(Js.Dict.get(dict, key)) {
            | Some(obj) => pickPath(Belt.Result.Ok(obj), resolving, Belt.List.tailExn(keyPath))
            | None => Error(MissingKey(resolving))
          }
          | None => Error(MissingKey(resolving))
        }
      );
    };

let key: string => t => t =
  (keyPath, config) => switch (config.value) {
    | Ok(json) => ({
      name: (Js.String.length(config.name) > 0 ? config.name ++ "." ++ keyPath : keyPath),
      value: (Js.String.split(".", keyPath) -> Belt.Array.keep(s => Js.String.length(s) > 0) -> Belt.List.fromArray)
             |> pickPath(Ok(json), "")
    })
    | Error(_) => config
  };

type parser('a) = t => r('a);

let typeMatch: string => option('a) => r('a) =
  (name, param) => switch (param) {
    | Some(x) => Ok(x)
    | None => Error(TypeMismatch(name))
  };

let parseBool: parser(bool) =
  param =>
    param.value
    -> Belt.Result.flatMap(json => Js.Json.decodeBoolean(json) |> typeMatch(param.name));

let parseString: parser(string) =
  param =>
    param.value
    -> Belt.Result.flatMap(json => Js.Json.decodeString(json) |> typeMatch(param.name));

let parseFloat: parser(float) =
  param =>
    param.value
    -> Belt.Result.flatMap(json => Js.Json.decodeNumber(json) |> typeMatch(param.name));

let parseInt: parser(int) =
  param =>
    param.value
    -> Belt.Result.flatMap(
      json =>
        Js.Json.decodeNumber(json)
        -> Belt.Option.flatMap(number => if (Js.Math.floor_float(number) == number) Some(Js.Math.floor_int(number)) else None)
        |> typeMatch(param.name));

let parseList: parser('a) => parser(list('a)) =
  (itemParser, param) =>
    param.value
    -> Belt.Result.flatMap(
      json =>
        (Js.Json.decodeArray(json) |> typeMatch(param.name))
        -> Belt.Result.map(Array.mapi((idx, item) => itemParser({ name: param.name ++ "[" ++ string_of_int(idx) ++ "]", value: Ok(item) })))
        -> Belt.Result.flatMap(array => try (Ok(Array.map(Belt.Result.getExn, array))) {
          | error => Error(error)
        })
        -> Belt.Result.map(Array.to_list));

let parseDict: parser('a) => parser(Js.Dict.t('a)) =
  (itemParser, param) =>
    param.value
    -> Belt.Result.flatMap(
      json =>
        (Js.Json.decodeObject(json) |> typeMatch(param.name))
        -> Belt.Result.map(Js.Dict.entries)
        -> Belt.Result.map(Array.mapi((idx, (key, item)) => (key, itemParser({ name: param.name ++ "[" ++ string_of_int(idx) ++ "]", value: Ok(item) }))))
        -> Belt.Result.flatMap(array => try (Ok(Array.map(((key, value)) => (key, Belt.Result.getExn(value)), array))) {
          | error => Error(error)
        })
        -> Belt.Result.map(Js.Dict.fromArray));

let parseCustom: (Js.Json.t => 'a) => parser('a) =
  (parser, param) =>
    param.value
    -> Belt.Result.flatMap(
      json => try (Ok(parser(json))) {
        | _ => Error(TypeMismatch(param.name))
      });

let get: r('a) => option('a) = value => switch (value) {
  | Ok(value) => Some(value)
  | Error(_) => None
};

let getExn: r('a) => 'a = Belt.Result.getExn;

let result: r('a) => Belt.Result.t('a, exn) = x => x;


let getBool: string => t => bool = (keyPath, param) => key(keyPath, param) |> parseBool |> getExn;
let getString: string => t => string = (keyPath, param) => key(keyPath, param) |> parseString |> getExn;
let getFloat: string => t => float = (keyPath, param) => key(keyPath, param) |> parseFloat |> getExn;
let getInt: string => t => int = (keyPath, param) => key(keyPath, param) |> parseInt |> getExn;
