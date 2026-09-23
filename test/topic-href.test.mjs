// Run: node test/topic-href.test.mjs
// Loaded from source as a data: URL so the plugin needs no package.json/build.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const src = await readFile(
  new URL("../assets/javascripts/discourse/lib/topic-href.js", import.meta.url),
  "utf8"
);
const { topicIdFromHref, categoryIdFromHref, indexLinksTopic, docCategoryForTopic } =
  await import(
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

// Index membership: a topic counts as part of a course when the course's
// Index Topic links to it, wherever the topic itself lives.
const docs = {
  id: 4,
  doc_category_index: [
    { text: "Start", links: [{ text: "One", href: "/t/one/11" }] },
    { text: "More", links: [{ text: "Two", href: "/t/two/22" }] },
  ],
};
const guides = { id: 7 };
const categories = [guides, docs];

assert.equal(indexLinksTopic(docs, 22), true);
assert.equal(indexLinksTopic(docs, 99), false);
assert.equal(indexLinksTopic(guides, 22), false);
assert.equal(indexLinksTopic(docs, undefined), false);
assert.equal(indexLinksTopic(undefined, 22), false);
assert.equal(indexLinksTopic({ doc_category_index: "nope" }, 22), false);

// A topic in Guides that the Docs index lists is driven by Docs.
assert.equal(docCategoryForTopic(categories, 22, guides), docs);
// A doc category always drives its own topics.
assert.equal(docCategoryForTopic(categories, 22, docs), docs);
// Listed nowhere: unchanged, so nothing renders as before.
assert.equal(docCategoryForTopic(categories, 99, guides), guides);
assert.equal(docCategoryForTopic(undefined, 22, guides), guides);
assert.equal(docCategoryForTopic(categories, 22, undefined), docs);

console.log("ok");
