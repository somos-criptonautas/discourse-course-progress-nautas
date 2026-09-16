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
