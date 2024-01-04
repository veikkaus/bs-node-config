exception MissingKey(string);
exception TypeMismatch(string);

type r<'a> = Belt.Result.t<'a, exn>;
type t = {
  name: string,
  value: r<Js.Json.t>
};

module Util = {

  module JsYamlBind = {
    type schema;

    @deriving(abstract)
    type loadOptions = {
      schema: schema,
      json: bool,
    };
    @val @module("js-yaml") external jsonSchema: schema = "JSON_SCHEMA";
    @val @module("js-yaml") external load: (string, loadOptions) => Js.Json.t = "load";
  };

  let parseYaml: string => r<Js.Json.t> =
    rawStr =>
      try {
        Belt.Result.Ok(JsYamlBind.load(rawStr, JsYamlBind.loadOptions(~schema=JsYamlBind.jsonSchema, ~json=false)))
      } catch {
        | error => Error(error)
      };

  let parseJson: string => r<Js.Json.t> =
    rawStr =>
      try {
        Ok(Js.Json.parseExn(rawStr))
      } catch {
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
        -> Js.Dict.fromArray
        -> Js.Json.object_
      }
      | (_, _) => b
    };

  module OptionList = {
    let getSome: list<option<'a>> => option<'a> =
      list => list -> Belt.List.keep(Belt.Option.isSome) -> Belt.List.map(Belt.Option.getExn) -> Belt.List.head;
  };
};

module Loaders = {
  @val external environment: Js.Dict.t<string> = "process.env";
  @val external processCwd: unit => string = "process.cwd";

  type loader = unit => r<Js.Json.t>;
  type parser = string => r<Js.Json.t>;

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

  let getConfigProfile: unit => option<string> =
    () =>
      Util.OptionList.getSome(list{
        Js.Dict.get(environment, "NODE_CONFIG_ENV"),
        Js.Dict.get(environment, "NODE_ENV"),
      });

  let loadFileIfExists: string => parser => r<Js.Json.t> =
    (filename, parser) => if (Node.Fs.existsSync(filename)) {
      Node.Fs.readFileAsUtf8Sync(filename) -> parser
    } else {
      emptyConfig
    };

  let fileLoader: string => parser => loader =
    (filename, parser, ()) =>
      Node.Path.join2(getConfigFilePath(), filename) -> loadFileIfExists(parser);

  let profileFileLoader: string => parser => loader =
    (ext, parser, ()) => switch (getConfigProfile()) {
      | Some(profile) => Node.Path.join2(getConfigFilePath(), profile ++ ext) -> loadFileIfExists(parser)
      | None => emptyConfig
    };

  let rec substitute: Js.Json.t => Js.Json.t =
    json => switch(Js.Json.classify(json)) {
      | JSONObject(obj) => Js.Dict.entries(obj)
        -> Belt.Array.map(((key, value)) => switch (Js.Json.classify(value)) {
          | JSONString(envParameterName) => switch (Js.Dict.get(environment, envParameterName)) {
            | Some(value) => try {
                Some((key, Js.Json.parseExn(value)))
              } catch {
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

  let customEnvParamsLoader: string => parser => loader =
    (ext, parser, ()) =>
      (Node.Path.join2(getConfigFilePath(), "custom-environment-variables" ++ ext) -> loadFileIfExists(parser))
      -> Belt.Result.map(substitute);
};

let loadConfig: unit => r<t> =
  () => {
    let results = list{
      Loaders.fileLoader("default.json", Util.parseJson)(),
      Loaders.fileLoader("default.yaml", Util.parseYaml)(),
      Loaders.profileFileLoader(".json", Util.parseJson)(),
      Loaders.profileFileLoader(".yaml", Util.parseYaml)(),
      Loaders.fileLoader("local.json", Util.parseJson)(),
      Loaders.fileLoader("local.yaml", Util.parseYaml)(),
      Loaders.envConfigJsonLoader(),
      Loaders.customEnvParamsLoader(".json", Util.parseJson)(),
      Loaders.customEnvParamsLoader(".yaml", Util.parseYaml)(),
      };
    let mergedResult = results -> Belt.List.reduce(
      Loaders.emptyConfig,
      (acc, item) => acc -> Belt.Result.flatMap(
        accJson => item -> Belt.Result.map(itemJson => Util.mergeJson(accJson, itemJson))));
    mergedResult -> Belt.Result.map(result => {
        name: "",
        value: Ok(result),
    });
  };

let rec pickPath: r<Js.Json.t> => string => list<string> => r<Js.Json.t> =
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

let key: (t, string) => t =
  (config, keyPath) => switch (config.value) {
    | Ok(json) => ({
      name: (Js.String.length(config.name) > 0 ? config.name ++ "." ++ keyPath : keyPath),
      value: (Js.String.split(".", keyPath) -> Belt.Array.keep(s => Js.String.length(s) > 0) -> Belt.List.fromArray)
             |> pickPath(Ok(json), "")
    })
    | Error(_) => config
  };

let keyHasValue: t => string => bool =
  (config, keyPath) => switch (key(config, keyPath).value) {
    | Ok(jsonValue) => Js.Json.classify(jsonValue) != JSONNull
    | Error(_) => false
  };

type parser<'a> = t => r<'a>;

let decodeToResult: (Js.Json.t => option<'a>) => string => Js.Json.t => r<'a> =
  (decoder, configName, json) => switch(decoder(json)) {
    | Some(x) => Ok(x)
    | None => Error(TypeMismatch(configName))
  };

let parseBool: parser<bool> =
  config =>
    config.value
    -> Belt.Result.flatMap(decodeToResult(Js.Json.decodeBoolean, config.name));

let parseString: parser<string> =
  config =>
    config.value
    -> Belt.Result.flatMap(decodeToResult(Js.Json.decodeString, config.name));

let parseFloat: parser<float> =
  config =>
    config.value
    -> Belt.Result.flatMap(decodeToResult(Js.Json.decodeNumber, config.name));

let parseInt: parser<int> =
  config =>
    config.value
    -> Belt.Result.flatMap(decodeToResult(
      json =>
        Js.Json.decodeNumber(json) -> Belt.Option.flatMap(
          number => if (Js.Math.floor_float(number) == number) { Some(Js.Math.floor_int(number)) } else { None }),
      config.name
    ));

let parseList: t => parser<'a> => r<list<'a>> =
  (config, itemParser) =>
    config.value
    -> Belt.Result.flatMap(
      json =>
        decodeToResult(Js.Json.decodeArray, config.name, json)
        -> Belt.Result.map(Array.mapi((idx, item) => itemParser({ name: config.name ++ "[" ++ string_of_int(idx) ++ "]", value: Ok(item) })))
        -> Belt.Result.flatMap(array => try {
            Ok(Array.map(Belt.Result.getExn, array))
          } catch {
            | error => Error(error)
          })
        -> Belt.Result.map(Array.to_list));

let parseDict: t => parser<'a> => r<Js.Dict.t<'a>> =
  (config, itemParser) =>
    config.value
    -> Belt.Result.flatMap(
      json =>
        decodeToResult(Js.Json.decodeObject, config.name, json)
        -> Belt.Result.map(Js.Dict.entries)
        -> Belt.Result.map(Array.mapi((idx, (key, item)) => (key, itemParser({ name: config.name ++ "[" ++ string_of_int(idx) ++ "]", value: Ok(item) }))))
        -> Belt.Result.flatMap(array => try {
            Ok(Array.map(((key, value)) => (key, Belt.Result.getExn(value)), array))
          } catch {
            | error => Error(error)
          })
        -> Belt.Result.map(Js.Dict.fromArray));

let parseCustom: t => (Js.Json.t => 'a) => r<'a> =
  (config, customParser) =>
    config.value
    -> Belt.Result.flatMap(
      json => try {
          Ok(customParser(json))
        } catch {
          | _ => Error(TypeMismatch(config.name))
        });

let get: r<'a> => option<'a> =
  value => switch (value) {
    | Ok(value) => Some(value)
    | Error(_) => None
  };

let getExn: r<'a> => 'a = Belt.Result.getExn;

let result: r<'a> => Belt.Result.t<'a, exn> = x => x;


let getBool: t => string => bool = (config, keyPath) => key(config, keyPath) -> parseBool -> getExn;
let getString: t => string => string = (config, keyPath) => key(config, keyPath) -> parseString -> getExn;
let getFloat: t => string => float = (config, keyPath) => key(config, keyPath) -> parseFloat -> getExn;
let getInt: t => string => int = (config, keyPath) => key(config, keyPath) -> parseInt -> getExn;
