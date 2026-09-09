// Index links are whatever the author typed in the index topic, so they can be
// root-relative ("/t/slug/1", "/t/1") or absolute ("https://host/t/slug/1").
const TOPIC_HREF = /^(?:https?:\/\/[^/]+)?\/t\/(?:[^/]+\/)?(\d+)/;

export function topicIdFromHref(href) {
  const match = href?.match(TOPIC_HREF);

  return match ? Number(match[1]) : null;
}
