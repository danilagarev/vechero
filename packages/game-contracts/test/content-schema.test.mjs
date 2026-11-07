import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import Ajv from 'ajv';

const schema = JSON.parse(
  await readFile(new URL('../schemas/content-pack.schema.json', import.meta.url), 'utf8'),
);
const fixture = JSON.parse(
  await readFile(new URL('../../game-content/packs/spy-ru-base.json', import.meta.url), 'utf8'),
);
const validate = new Ajv({ strict: true }).compile(schema);

test('content contract rejects unsupported versions, games, and extra fields', () => {
  assert.ok(validate(fixture));
  for (const change of [{ schemaVersion: 2 }, { gameId: 'unknown' }, { secret: true }]) {
    assert.equal(validate({ ...fixture, ...change }), false);
  }
  assert.equal(validate({ ...fixture, items: [] }), false);
});
