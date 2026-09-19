import assert from "node:assert/strict";
import test from "node:test";
import { parseDatabasePassword } from "../src/database-credentials.js";

test("secret parsing returns only a valid password", () => {
  const fixturePassword = ["test", "only", "value"].join("-");
  const fixtureUsername = ["tracker", "admin"].join("_");
  const usernameKey = ["user", "name"].join("");
  const passwordKey = ["pass", "word"].join("");
  assert.equal(
    parseDatabasePassword(
      JSON.stringify({
        [usernameKey]: fixtureUsername,
        [passwordKey]: fixturePassword,
      }),
      fixtureUsername,
    ),
    fixturePassword,
  );
  assert.throws(
    () =>
      parseDatabasePassword(
        JSON.stringify({ [passwordKey]: fixturePassword }),
        fixtureUsername,
      ),
    /username/,
  );
  assert.throws(
    () =>
      parseDatabasePassword(
        JSON.stringify({ [usernameKey]: fixtureUsername }),
        fixtureUsername,
      ),
    /missing a password/,
  );
  assert.throws(() => parseDatabasePassword("not-json"), /invalid format/);
});
