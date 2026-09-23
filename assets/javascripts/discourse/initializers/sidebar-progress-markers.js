import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import { categoryIdFromHref, topicIdFromHref } from "../lib/topic-href";

const MARKER = "course-progress-badge";

// Core renders the badge slot itself (.sidebar-section-link-content-badge is
// pushed right and ellipsized), so reusing its class keeps the row layout,
// hover and active states untouched. A marker with no text means finished, and
// is drawn as a check: a dot there would read as Discourse's unread indicator.
function marker(text, title) {
  const span = document.createElement("span");

  span.className = `sidebar-section-link-content-badge ${MARKER}`;
  span.title = title;

  if (text) {
    span.textContent = text;
  } else {
    span.classList.add("--done");
    span.innerHTML =
      `<svg class="fa d-icon d-icon-check svg-icon" aria-hidden="true">` +
      `<use href="#check"></use></svg>`;
  }

  return span;
}

function replaceMarker(link, text, title) {
  link.querySelector(`.${MARKER}`)?.remove();

  if (title) {
    link.appendChild(marker(text, title));
  }
}

function decorate(courses, nonCourseTopics) {
  const read = new Set();

  for (const course of Object.values(courses)) {
    course.read_topic_ids.forEach((id) => read.add(id));
  }

  // Course categories anywhere in the main sidebar: how many lessons are read.
  document.querySelectorAll("a.sidebar-section-link").forEach((link) => {
    const course = courses[categoryIdFromHref(link.getAttribute("href"))];

    if (!course) {
      return;
    }

    // Courses whose index lists topics that are not lessons (a welcome post, a
    // FAQ) can discount them here; the endpoint keeps reporting the real total.
    const total = Math.max(0, course.total_topics - nonCourseTopics);

    if (total === 0) {
      return;
    }

    const done = course.read_count >= total;

    replaceMarker(
      link,
      done ? null : `${course.read_count}/${total}`,
      done
        ? i18n("course_progress.sidebar.completed")
        : i18n("course_progress.sidebar.progress", {
            read: course.read_count,
            total,
          })
    );
  });

  // Lessons in the docs sidebar: read or not.
  document.querySelectorAll("a.docs-sidebar-nav-link").forEach((link) => {
    const topicId = topicIdFromHref(link.getAttribute("href"));

    replaceMarker(
      link,
      null,
      topicId && read.has(topicId)
        ? i18n("course_progress.sidebar.lesson_read")
        : null
    );
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
          .then((data) =>
            decorate(
              data?.courses ?? {},
              siteSettings.course_progress_non_course_topics
            )
          )
          .catch(() => {});
      });
    });
  },
};
