import assert from 'node:assert/strict';
import { readdir, readFile } from 'node:fs/promises';
import { test } from 'node:test';
import Ajv from 'ajv';

const readJson = async (url) => JSON.parse(await readFile(url, 'utf8'));
const schema = await readJson(
  new URL('../../game-contracts/schemas/content-pack.schema.json', import.meta.url),
);
const validate = new Ajv({ allErrors: true, strict: true }).compile(schema);
const directory = new URL('../packs/', import.meta.url);

test('all bundled packs match the contract and have unique identifiers', async () => {
  const files = (await readdir(directory)).filter((name) => name.endsWith('.json'));
  assert.ok(files.length > 0, 'at least one starter pack is required');
  const packIds = new Set();
  for (const file of files) {
    const pack = await readJson(new URL(file, directory));
    assert.ok(validate(pack), `${file}: ${JSON.stringify(validate.errors)}`);
    assert.ok(!packIds.has(pack.id), `duplicate pack id: ${pack.id}`);
    packIds.add(pack.id);
    const itemIds = pack.items.map((item) => item.id);
    assert.equal(new Set(itemIds).size, itemIds.length, `${file}: duplicate item ids`);
    assert.ok(pack.items.every((item) => item.label.trim().length > 0));
  }
});
