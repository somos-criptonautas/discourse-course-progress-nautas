# Discourse Course Progress — Criptonautas Fork

Server-side Discourse plugin that returns the **true historical read status** of topics per user, for LMS-style course progression. Fork of [zsviczian/discourse-course-progress](https://github.com/zsviczian/discourse-course-progress) (MIT).

## What this fork adds

**Previous / Next topic navigation** for Doc Categories:

- Renders **Previous / Next** links at the bottom of a topic (above the suggested topics), following the exact order of the category's configured Docs **Index Topic**.
- Reads the ordered index the official **Doc Categories** plugin already serializes on the category (`doc_category_index`) — no extra API calls.
- Auto-hidden on topics outside the index (e.g. the Index Topic itself).
- Glimmer component rendered in the `topic-above-suggested` outlet; styles scoped under `.course-doc-nav`, overridable from any theme.

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

The Index Topic itself is **excluded** from `total_topics` — it is course
navigation, not course content. A course of 10 lessons reports `total_topics: 10`.

## Troubleshooting

**Previous / Next links don't show up.** The Doc Categories plugin only exposes
the ordered index (`doc_category_index`) once its sidebar structure has been
built, which happens in a background job when the Index Topic is **edited or
re-assigned**. On a course that was configured before that mechanism existed,
just re-save the Index Topic (edit it and Save, or re-pick it in the category's
Docs settings).

**A lesson is missing from the Previous / Next list.** Give its link in the
Index Topic an explicit title — a link carrying only a topic id is skipped by
the Doc Categories parser.
