// Index links are whatever the author typed in the index topic, so they can be
// root-relative ("/t/slug/1", "/t/1") or absolute ("https://host/t/slug/1").
const TOPIC_HREF = /^(?:https?:\/\/[^/]+)?\/t\/(?:[^/]+\/)?(\d+)/;

export function topicIdFromHref(href) {
  const match = href?.match(TOPIC_HREF);

  return match ? Number(match[1]) : null;
}

// Sidebar category links keep the id last: "/c/cursos/15", "/c/cursos/btc/15".
const CATEGORY_HREF = /^(?:https?:\/\/[^/]+)?\/c\/(?:[^/?#]+\/)*(\d+)(?:[/?#]|$)/;

export function categoryIdFromHref(href) {
  const match = href?.match(CATEGORY_HREF);

  return match ? Number(match[1]) : null;
}

// A topic belongs to a doc index when that index links to it, whatever
// category the topic itself lives in. Index links carry only `text` and
// `href`, so membership is resolved by parsing the href.
export function indexLinksTopic(category, topicId) {
  const structure = category?.doc_category_index;

  if (!Array.isArray(structure) || !topicId) {
    return false;
  }

  return structure.some((section) =>
    (section?.links ?? []).some(
      (link) => topicIdFromHref(link?.href) === topicId
    )
  );
}

// Which category's doc index drives this topic: its own when that category
// is a doc category, otherwise whichever index lists the topic.
export function docCategoryForTopic(categories, topicId, ownCategory) {
  if (ownCategory?.doc_category_index) {
    return ownCategory;
  }

  return (
    (categories ?? []).find((category) =>
      indexLinksTopic(category, topicId)
    ) ?? ownCategory
  );
}
