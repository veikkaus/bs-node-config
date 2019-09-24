open BsMocha.Mocha;
module Assert = BsMocha.Assert;
module C = Config;


describe("Config", () => {

  before_each(() => {
    Node.Process.deleteEnvVar("NODE_CONFIG_ENV");
  });

  it("should load default.json and have basic values available", () => {
    let config = C.loadConfig() |> C.getExn;
    Assert.equal(
      config |> C.key("server.host") |> C.parseStringExn,
      "dream.beam.com"
    );
    Assert.equal(
      config |> C.key("server.port") |> C.parseIntExn,
      1234
    );
    Assert.equal(
      config |> C.key("server.deeper.enabled") |> C.parseBoolExn,
      false
    );
    Assert.deep_equal(
      config |> C.key("other") |> C.parseList(C.parseString) |> C.getExn,
      ["first", "second", "third"]
    );
  });

  it("should load profile-x.yaml and have basic values available", () => {
    Node.Process.putEnvVar("NODE_CONFIG_ENV", "profile-x");
    let config = C.loadConfig() |> C.getExn;
    Assert.equal(
      config |> C.key("some.interesting") |> C.parseStringExn,
      "value"
    );
    Assert.equal(
      config |> C.key("some.and") |> C.parseFloatExn,
      123.45
    );
    Assert.equal(
      config |> C.key("some.then") |> C.parseBoolExn,
      true
    );
    Assert.deep_equal(
      config |> C.key("other") |> C.parseList(C.parseString) |> C.getExn,
      ["foo", "barf", "garh"]
    );
  });

  it("should be able to read custom-environment-variables.yaml and override from env", () => {
    Node.Process.putEnvVar("SERVER_HOST", "hostus.mostus");
    Node.Process.putEnvVar("OTHER_THINGS", "[\"pertama\", \"kedua\"]");
    let config = C.loadConfig() |> C.getExn;
    Assert.equal(
      config |> C.key("server.host") |> C.parseStringExn,
      "hostus.mostus"
    );
    Assert.equal(
      config |> C.key("server.port") |> C.parseIntExn,
      1234
    );
    Assert.deep_equal(
      config |> C.key("other") |> C.parseList(C.parseString) |> C.getExn,
      ["pertama", "kedua"]
    );
  });

  it("should contain error for trying to access non-existing key", () => {
    let config = C.loadConfig() |> C.getExn;
    Assert.deep_equal(
      config |> C.key("fantasy.land.utopia") |> C.parseString |> C.result,
      Belt.Result.Error(C.MissingKey(".fantasy"))
    );
  });

  it("should contain error for trying to typecast incorrectly", () => {
    let config = C.loadConfig() |> C.getExn;
    Assert.deep_equal(
      config |> C.key("server.host") |> C.parseInt |> C.result,
      Belt.Result.Error(C.TypeMismatch("server.host"))
    );
  });

});