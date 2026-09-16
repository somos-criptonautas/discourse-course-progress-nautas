import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";
import { categoryIdFromHref, topicIdFromHref } from "../lib/topic-href";

const MARKER = "course-progress-badge";

// Core renders the badge slot itself (.sidebar-section-link-content-badge is
// pushed right and ellipsized), so reusing its class keeps the row layout,
// hover and active states untouched. An empty marker is drawn as a dot.
function marker(text) {
  const span = document.createElement("span");

  span.className = `sidebar-section-link-content-badge ${MARKER}`;

  if (text) {
    span.textContent = text;
  } else {
    span.classList.add("--done");
  }

  return span;
}

function replaceMarker(link, text) {
  link.querySelector(`.${MARKER}`)?.remove();

  if (text !== false) {
    link.appendChild(marker(text));
  }
}

function decorate(courses) {
  const read = new Set();

  for (const course of Object.values(courses)) {
    course.read_topic_ids.forEach((id) => read.add(id));
  }

  // Course categories anywhere in the main sidebar: how many lessons are read.
  document.querySelectorAll("a.sidebar-section-link").forEach((link) => {
    const course = courses[categoryIdFromHref(link.getAttribute("href"))];

    if (!course || course.total_topics === 0) {
      return;
    }

    replaceMarker(
      link,
      course.read_count >= course.total_topics
        ? null
        : `${course.read_count}/${course.total_topics}`
    );
  });

  // Lessons in the docs sidebar: read or not.
  document.querySelectorAll("a.docs-sidebar-nav-link").forEach((link) => {
    const topicId = topicIdFromHref(link.getAttribute("href"));

    replaceMarker(link, topicId && read.has(topicId) ? null : false);
  });
}

export default {
  name: "course-progress-sidebar-markers",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (
      !siteSettings?.course_progress_enabled ||
      !siteSettings?.course_progress_sidebar_markers_enabled
    ) {
      return;
    }

    withPluginApi((api) => {
      if (!api.getCurrentUser()) {
        return;
      }

      // Read counts change as the user moves through a course, so the endpoint
      // is re-read per navigation rather than cached.
      api.onPageChange(() => {
        ajax("/course-progress.json")
          .then((data) => decorate(data?.courses ?? {}))
          .catch(() => {});
      });
    });
  },
};
