# Discourse Course Progress — Criptonautas Fork

Server-side Discourse plugin that returns the **true historical read status** of topics per user, for LMS-style course progression. Fork of [zsviczian/discourse-course-progress](https://github.com/zsviczian/discourse-course-progress) (MIT).

## What this fork adds

**Previous / Next topic navigation** for Doc Categories:

- Renders **Previous / Next** links at the end of the lesson post, **before any replies** — in both the flat post stream and the nested-replies view — styled as a pair of cards so they read as course navigation rather than as part of the suggested-topics list.
- Reads the ordered index the official **Doc Categories** plugin already serializes on the category (`doc_category_index`) — no extra API calls.
- Scoped to the category that has the Index Topic. Its **subcategories are ordinary categories** — normal listing, no Previous / Next, no docs sidebar.
- Matches both root-relative (`/t/slug/1`) and absolute (`https://host/t/slug/1`) links in the Index Topic.
- Auto-hidden on topics outside the index (e.g. the Index Topic itself).
- Labels are localised (`en`, `es`) and carry `arrow-left` / `arrow-right` icons, which the [Phosphor duotone](https://github.com/somos-criptonautas/discourse-phosphor-duotone-icons) component swaps for its own arrows automatically.
- Glimmer component registered with `renderAfterWrapperOutlet("post-links")` and shown only on post #1; styles scoped under `.course-doc-nav`, overridable from any theme. Visible to anonymous visitors too.

**Sidebar progress markers.** A muted `read/total` count next to course
categories in the main sidebar, and a dot on every lesson already read in the
Docs sidebar — replacing the companion theme component (see *Progress UI*).

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
are plugin settings, not theme settings.

(Discourse renders no admin page for a plugin whose only setting is its own
enable toggle — see `Plugin::Instance#has_only_enabled_setting?`. This fork has
four, so the page shows.)

| Setting | Default | What it does |
| --- | --- | --- |
| `course_progress_enabled` | on | Master switch for the endpoint and everything below. |
| `course_progress_doc_navigation_enabled` | on | The Previous / Next links. |
| `course_progress_docs_sidebar_only_on_index_category` | on | Stops subcategories inheriting the docs sidebar. |
| `course_progress_sidebar_markers_enabled` | on | The sidebar read/total counts and read dots. |

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

Progress markers are drawn by this plugin — **the companion theme component
[discourse-course-progress-theme](https://github.com/zsviczian/discourse-course-progress-theme)
is no longer needed and must be uninstalled**, or both sets of markers render
side by side.

- **Course categories in the main sidebar** get a muted `read/total` count, and
  a small dot once every lesson is read.
- **Lessons in the Docs sidebar** get the same dot once read, and nothing
  before that.

The markers use core's own badge slot (`.sidebar-section-link-content-badge`),
which core already pushes to the end of the row and ellipsizes, so the row
keeps core's hover and active styling untouched. The theme component instead
forced `display: flex` / `width: 100%` / `padding-right` onto the link, which
pulled the highlight out of line with the neighbouring rows. Its
`non_course_files` setting is gone too: this fork already excludes the Index
Topic and the "About this category" topic server-side, so nothing needs
deducting.

Turn the markers off with `course_progress_sidebar_markers_enabled`. Styles are
scoped under `.course-progress-badge` and overridable from any theme.

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

## Completion badges

No plugin code: core's custom SQL badges can both grant and revoke from the
same tables the endpoint reads. Enable the hidden setting first
(`rails runner 'SiteSetting.enable_badge_sql = true'`), then create a badge per
course per milestone with the trigger set to **update daily**, changing
`i.category_id` and the final threshold:

```sql
WITH lessons AS (
  SELECT DISTINCT l.topic_id
  FROM doc_categories_indexes i
  JOIN doc_categories_sidebar_sections s ON s.index_id = i.id
  JOIN doc_categories_sidebar_links l ON l.sidebar_section_id = s.id
  JOIN topics t ON t.id = l.topic_id AND t.deleted_at IS NULL
  WHERE i.category_id = 41
    AND l.topic_id <> i.index_topic_id
),
progress AS (
  SELECT tu.user_id,
         COUNT(DISTINCT tu.topic_id)::numeric
           / NULLIF((SELECT COUNT(*) FROM lessons), 0) AS ratio,
         MAX(tu.last_visited_at) AS at
  FROM topic_users tu
  JOIN lessons ON lessons.topic_id = tu.topic_id
  WHERE tu.last_read_post_number >= 1
  GROUP BY tu.user_id
)
SELECT user_id, COALESCE(at, CURRENT_TIMESTAMP) AS granted_at
FROM progress
WHERE ratio >= 0.30
```

Badges stack: a user holds every milestone reached. To keep only the highest
visible, bound the lower ones (`ratio >= 0.30 AND ratio < 0.50`).

**Auto revoke** is on by default, so adding a lesson to an index lowers
everyone's ratio and the next daily run takes the badge back. Turn it off per
badge unless that is what you want.

To send a PM on a grant, use core's Automation plugin: trigger **User badge
granted** (tick *only first grant*) with the **Send PMs** script.

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
