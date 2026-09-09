import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { topicIdFromHref } from "../lib/topic-href";

/**
 * Previous / next topic navigation for Doc Categories.
 *
 * Renders in the `topic-area-bottom` outlet, at the end of the post stream and
 * before the topic's footer buttons, following the exact order of the
 * category's configured docs Index Topic.
 *
 * The ordered structure is provided by the official discourse-doc-categories
 * plugin through the category serializer (`doc_category_index`), so no
 * additional requests are needed:
 *
 *   [{ text: "Section", links: [{ text: "Topic title", href: "/t/slug/1" }] }]
 *
 * The serialized links only carry `text` and `href` (no `topic_id`), so the
 * current topic is located by parsing the topic id out of each href.
 */
export default class CourseDocNavigation extends Component {
  @service site;

  get topic() {
    return this.args.outletArgs?.model;
  }

  // Only the category that has an Index Topic configured is a course; its
  // subcategories are ordinary categories with ordinary listings.
  get category() {
    return (
      this.topic?.category ??
      this.site.categories?.find((c) => c.id === this.topic?.category_id)
    );
  }

  @cached
  get links() {
    const topicId = this.topic?.id;

    if (!topicId || this.topic.isPrivateMessage) {
      return [];
    }

    const structure = this.category?.doc_category_index;

    if (!Array.isArray(structure)) {
      return [];
    }

    return structure.flatMap((section) => section?.links ?? []);
  }

  @cached
  get currentIndex() {
    return this.links.findIndex(
      (link) => topicIdFromHref(link?.href) === this.topic.id
    );
  }

  get shouldRender() {
    return this.currentIndex > -1 && this.links.length > 1;
  }

  get previousTopic() {
    const index = this.currentIndex;

    return index > 0 ? this.links[index - 1] : null;
  }

  get nextTopic() {
    const index = this.currentIndex;

    return index > -1 && index < this.links.length - 1
      ? this.links[index + 1]
      : null;
  }

  <template>
    {{#if this.shouldRender}}
      <nav
        class="course-doc-nav"
        aria-label={{i18n "course_progress.doc_nav.label"}}
      >
        {{#if this.previousTopic}}
          <a
            class="course-doc-nav__link course-doc-nav__link--prev"
            href={{this.previousTopic.href}}
          >
            <span class="course-doc-nav__label">
              {{icon "arrow-left"}}
              {{i18n "course_progress.doc_nav.previous"}}
            </span>
            <span class="course-doc-nav__title">
              {{this.previousTopic.text}}
            </span>
          </a>
        {{/if}}
        {{#if this.nextTopic}}
          <a
            class="course-doc-nav__link course-doc-nav__link--next"
            href={{this.nextTopic.href}}
          >
            <span class="course-doc-nav__label">
              {{i18n "course_progress.doc_nav.next"}}
              {{icon "arrow-right"}}
            </span>
            <span class="course-doc-nav__title">{{this.nextTopic.text}}</span>
          </a>
        {{/if}}
      </nav>
    {{/if}}
  </template>
}
