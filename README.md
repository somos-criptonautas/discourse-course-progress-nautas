# Discourse Course Progress — Criptonautas Fork

Server-side Discourse plugin that returns the **true historical read status** of topics per user, for LMS-style course progression. Fork of [zsviczian/discourse-course-progress](https://github.com/zsviczian/discourse-course-progress) (MIT).

## What this fork adds

**Previous / Next topic navigation** for Doc Categories:

- Renders **Previous / Next** links right after the last post, above the topic's reply/bookmark/share buttons, following the exact order of the category's configured Docs **Index Topic**.
- Reads the ordered index the official **Doc Categories** plugin already serializes on the category (`doc_category_index`) — no extra API calls.
- Works for topics in **subcategories** of the docs category, and for topics the index borrows from other readable categories (the index is looked up by walking up the category tree, then across the site's categories).
- Matches both root-relative (`/t/slug/1`) and absolute (`https://host/t/slug/1`) links in the Index Topic.
- Auto-hidden on topics outside the index (e.g. the Index Topic itself).
- Glimmer component rendered in the `topic-above-footer-buttons` outlet; styles scoped under `.course-doc-nav`, overridable from any theme.

**Docs sidebar scoping.** Doc Categories resolves a category's index by walking
up the category tree, so every subcategory of a docs category inherits its
sidebar. This fork stops that walk: the sidebar appears only in the category
that actually has an Index Topic configured.

It works by overriding the sidebar service's `activeCategory` getter — the
private `#findIndexForActiveCategory` method that does the walking cannot be
patched, but the getter it reads can, so returning nothing for a category
without its own `doc_category_index` ends the walk before it starts.

Scope to be aware of: this hides the docs sidebar on subcategory listing pages
**and on topics inside those subcategories**. If some of your lessons live in
subcategories, those lesson pages lose the sidebar too — Previous / Next still
works there, since it keys off the Index Topic rather than the category tree.
Turn the whole behaviour off with the
`course_progress_docs_sidebar_only_on_index_category` site setting.

## Why it exists

Discourse's notification engine hides topics created before a user's account, so client-side scripts cannot track historical reading progress. This plugin queries the `TopicUser` table directly, bypassing that engine.

## Dependencies

- Official **Discourse Docs** plugin, with an **Index Topic** configured on the category (Docs settings).

## Installation

1. SSH into your Discourse server and edit `app.yml`.
2. Add the clone URL under `hooks`, below `docker_manager`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/somos-criptonautas/discourse-course-progress-nautas.git
```

3. Rebuild: `cd /var/discourse && ./launcher rebuild app`

## Progress UI

This plugin only serves data. To display badges/checkmarks, also install the companion theme component: [discourse-course-progress-theme](https://github.com/zsviczian/discourse-course-progress-theme).

> **Set the theme component's `non_course_files` setting to `0`.** It defaults
> to `2` because upstream's `total_topics` counted the Index Topic and the
> "About this category" topic as lessons. This fork excludes both server-side,
> so leaving the setting at `2` deducts them twice — the count reaches
> "complete" early and the `read / total` badge is replaced by a checkmark.

## API

`GET /course-progress.json` — logged-in users only (guests have no read history).

```json
{
  "courses": {
    "36": {
      "total_topics": 69,
      "read_count": 66,
      "read_topic_ids": [502, 503, 504]
    }
  }
}
```

Totals come from the **Index Topic**, not from a raw category scan, so lessons
in subcategories (or borrowed from another readable category) are counted and
the numbers agree with the Previous / Next navigation. The Index Topic itself is
**excluded** — it is navigation, not course content, so a course of 10 lessons
reports `total_topics: 10`.

Everything is scoped to the requesting user's permissions: restricted
categories, deleted and unreadable topics never appear. If a course's Index
Topic has never been parsed, the endpoint falls back to scanning the category
directly (subcategories excluded) rather than reporting zero.

## Troubleshooting

**Previous / Next links don't show up.** The Doc Categories plugin only exposes
the ordered index (`doc_category_index`) once its sidebar structure has been
built, which happens in a background job when the Index Topic is **edited or
re-assigned**. On a course that was configured before that mechanism existed,
just re-save the Index Topic (edit it and Save, or re-pick it in the category's
Docs settings).

**A lesson is missing from the Previous / Next list.** The Doc Categories
parser only picks up links inside a `<ul>`/`<ol>` list item in the Index
Topic's first post; anything else is ignored. Re-save the Index Topic after
fixing it.

## Tests

```
node test/topic-href.test.mjs
```
