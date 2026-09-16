// Run: node test/topic-href.test.mjs
// Loaded from source as a data: URL so the plugin needs no package.json/build.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const src = await readFile(
  new URL("../assets/javascripts/discourse/lib/topic-href.js", import.meta.url),
  "utf8"
);
const { topicIdFromHref, categoryIdFromHref } = await import(
  "data:text/javascript," + encodeURIComponent(src)
);

assert.equal(topicIdFromHref("/t/como-empezar/42"), 42);
assert.equal(topicIdFromHref("/t/42"), 42);
assert.equal(topicIdFromHref("/t/como-empezar/42/7"), 42);
assert.equal(topicIdFromHref("https://foro.example.com/t/como-empezar/42"), 42);
assert.equal(topicIdFromHref("http://foro.example.com/t/42"), 42);
assert.equal(topicIdFromHref("/c/cursos/5"), null);
assert.equal(topicIdFromHref("https://example.com/blog/t/42"), null);
assert.equal(topicIdFromHref(undefined), null);

assert.equal(categoryIdFromHref("/c/cursos/15"), 15);
assert.equal(categoryIdFromHref("/c/cursos/bitcoin/15"), 15);
assert.equal(categoryIdFromHref("/c/cursos/15?tag=foo"), 15);
assert.equal(categoryIdFromHref("https://foro.example.com/c/cursos/15"), 15);
assert.equal(categoryIdFromHref("/c/cursos/15/l/latest"), 15);
assert.equal(categoryIdFromHref("/t/como-empezar/42"), null);
assert.equal(categoryIdFromHref("/categories"), null);
assert.equal(categoryIdFromHref(undefined), null);

console.log("ok");
