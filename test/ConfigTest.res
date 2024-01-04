open RescriptMocha;
open Mocha;
module C = Config;


describe("Config", () => {

  before_each(() => {
    Node.Process.deleteEnvVar("NODE_CONFIG_ENV");
  });
  it("should load default.json and have basic values available", () => {
    let config: C.t = C.loadConfig() -> C.getExn;
    Assert.equal(
      C.getString(config, "server.host"),
      "dream.beam.com"
    );
    Assert.equal(
      C.getInt(config, "server.port"),
      1234
    );
    Assert.equal(
      C.getBool(config, "server.deeper.enabled"),
      false
    );
    Assert.deep_equal(
      config -> C.key("other") -> C.parseList(C.parseString) -> C.getExn,
      list{"first", "second", "third"}
    );
    Assert.deep_equal(
      C.getList(config, "other", C.parseString),
      list{"first", "second", "third"}
    );
    Assert.deep_equal(
      C.getDict(config, "numberDict", C.parseInt),
      Js.Dict.fromArray([("first", 123), ("second", 456), ("third", 0), ("fourth", -234), ("fifth", 93)])
    );
  });

  it("should load profile-x.yaml and have basic values available", () => {
    Node.Process.putEnvVar("NODE_CONFIG_ENV", "profile-x");
    let config = C.loadConfig() -> C.getExn;
    Assert.equal(
      C.getString(config, "some.interesting"),
      "value"
    );
    Assert.equal(
      C.getFloat(config, "some.and"),
      123.45
    );
    Assert.equal(
      C.getBool(config, "some.then"),
      true
    );
    Assert.deep_equal(
      config -> C.key("other") -> C.parseList(C.parseString) -> C.getExn,
      list{"foo", "barf", "garh"}
    );
  });

  it("should be able to read custom-environment-variables.yaml and override from env", () => {
    Node.Process.putEnvVar("SERVER_HOST", "hostus.mostus");
    Node.Process.putEnvVar("OTHER_THINGS", "[\"pertama\", \"kedua\"]");
    let config = C.loadConfig() -> C.getExn;
    Assert.equal(
      C.getString(config, "server.host"),
      "hostus.mostus"
    );
    Assert.equal(
      C.getInt(config, "server.port"),
      1234
    );
    Assert.deep_equal(
      config -> C.key("other") -> C.parseList(C.parseString) -> C.getExn,
      list{"pertama", "kedua"}
    );
  });

  it("should contain error for trying to access non-existing key", () => {
    let config = C.loadConfig() -> C.getExn;
    Assert.deep_equal(
      config -> C.key("fantasy.land.utopia") -> C.parseString -> C.result,
      Belt.Result.Error(C.MissingKey(".fantasy"))
    );
  });

  it("should contain error for trying to typecast incorrectly", () => {
    let config = C.loadConfig() -> C.getExn;
    Assert.deep_equal(
      config -> C.key("server.host") -> C.parseInt -> C.result,
      Belt.Result.Error(C.TypeMismatch("server.host"))
    );
  });
});
