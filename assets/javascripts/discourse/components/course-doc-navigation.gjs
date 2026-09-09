import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

// Internal doc index links look like "/t/<slug>/<id>" or "/t/<id>".
const INTERNAL_TOPIC_HREF = /^\/t\/(?:[^/]+\/)?(\d+)/;

/**
 * Previous / next topic navigation for Doc Categories.
 *
 * Renders in the `topic-above-suggested` outlet (bottom of the topic, above
 * the suggested/more topics list) and follows the exact order of the
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

  get category() {
    return (
      this.topic?.category ??
      this.site.categories?.find(
        (category) => category.id === this.topic?.category_id
      )
    );
  }

  @cached
  get links() {
    const structure = this.category?.doc_category_index;

    if (!Array.isArray(structure)) {
      return [];
    }

    return structure.flatMap((section) => section?.links ?? []);
  }

  @cached
  get currentIndex() {
    const topic = this.topic;

    if (!topic?.id || topic.isPrivateMessage) {
      return -1;
    }

    return this.links.findIndex((link) => {
      // The regex only matches root-relative "/t/..." URLs, so external
      // links simply fall through to no-match.
      const match = link?.href?.match(INTERNAL_TOPIC_HREF);

      return match ? Number(match[1]) === topic.id : false;
    });
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
