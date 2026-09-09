import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import { topicIdFromHref } from "../lib/topic-href";

/**
 * Previous / next topic navigation for Doc Categories.
 *
 * Renders in the `topic-above-footer-buttons` outlet (right below the last
 * post, above the topic's reply/bookmark/share buttons) and follows the exact
 * order of the category's configured docs Index Topic.
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

  // The index lives on the category that has it configured, but the topics it
  // lists can sit in a subcategory (or, per doc-categories, in any other
  // category the user can read). So walk up from the topic's own category the
  // way doc-categories does, then fall back to every category we know about.
  get candidateCategories() {
    const start =
      this.topic?.category ??
      this.site.categories?.find((c) => c.id === this.topic?.category_id);

    const chain = [];

    for (let category = start; category; category = category.parentCategory) {
      chain.push(category);
    }

    return chain.concat(this.site.categories ?? []);
  }

  @cached
  get links() {
    const topicId = this.topic?.id;

    if (!topicId || this.topic.isPrivateMessage) {
      return [];
    }

    for (const category of this.candidateCategories) {
      const structure = category?.doc_category_index;

      if (!Array.isArray(structure)) {
        continue;
      }

      const links = structure.flatMap((section) => section?.links ?? []);

      if (links.some((link) => topicIdFromHref(link?.href) === topicId)) {
        return links;
      }
    }

    return [];
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
            </span>
            <span class="course-doc-nav__title">{{this.nextTopic.text}}</span>
          </a>
        {{/if}}
      </nav>
    {{/if}}
  </template>
}
