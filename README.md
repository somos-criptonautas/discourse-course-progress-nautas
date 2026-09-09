# Discourse Course Progress — Criptonautas Fork

Server-side Discourse plugin that returns the **true historical read status** of topics per user, for LMS-style course progression. Fork of [zsviczian/discourse-course-progress](https://github.com/zsviczian/discourse-course-progress) (MIT).

## What this fork adds

**Previous / Next topic navigation** for Doc Categories:

- Renders **Previous / Next** links at the end of the post stream (`topic-area-bottom`), styled as a pair of cards so they read as course navigation rather than as part of the suggested-topics list below.
- Reads the ordered index the official **Doc Categories** plugin already serializes on the category (`doc_category_index`) — no extra API calls.
- Scoped to the category that has the Index Topic. Its **subcategories are ordinary categories** — normal listing, no Previous / Next, no docs sidebar.
- Matches both root-relative (`/t/slug/1`) and absolute (`https://host/t/slug/1`) links in the Index Topic.
- Auto-hidden on topics outside the index (e.g. the Index Topic itself).
- Labels are localised (`en`, `es`) and carry `arrow-left` / `arrow-right` icons, which the [Phosphor duotone](https://github.com/somos-criptonautas/discourse-phosphor-duotone-icons) component swaps for its own arrows automatically.
- Glimmer component; styles scoped under `.course-doc-nav`, overridable from any theme.

**Docs sidebar scoping.** Doc Categories resolves a category's index by walking
up the category tree, so every subcategory of a docs category inherits its
sidebar. This fork stops that walk: the sidebar appears only in the category
that actually has an Index Topic configured.

It works by overriding the sidebar service's `activeCategory` getter — the
private `#findIndexForActiveCategory` method that does the walking cannot be
patched, but the getter it reads can, so returning nothing for a category
without its own `doc_category_index` ends the walk before it starts.

This applies to subcategory listing pages and to topics inside them, which is
the intended behaviour: a subcategory of a docs category is an ordinary
category and should look like one. Turn it off with the
`course_progress_docs_sidebar_only_on_index_category` site setting.

## Site settings

All of this fork's behaviour is switchable from **Admin → Plugins → Course
Progress**, or from **Admin → Settings** by searching `course_progress`. These
are plugin settings; the companion theme component's `non_course_files` lives
separately under Admin → Customize → Components.

(Discourse renders no admin page for a plugin whose only setting is its own
enable toggle — see `Plugin::Instance#has_only_enabled_setting?`. This fork has
three, so the page shows.)

| Setting | Default | What it does |
| --- | --- | --- |
| `course_progress_enabled` | on | Master switch for the endpoint and everything below. |
| `course_progress_doc_navigation_enabled` | on | The Previous / Next links. |
| `course_progress_docs_sidebar_only_on_index_category` | on | Stops subcategories inheriting the docs sidebar. |

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

Totals come from the **Index Topic**, not from a raw category scan, so the
numbers count exactly the lessons the index lists and agree with the
Previous / Next navigation. The Index Topic itself is
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
