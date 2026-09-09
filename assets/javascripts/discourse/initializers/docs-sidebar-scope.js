import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "course-docs-sidebar-scope",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (
      !siteSettings?.course_progress_enabled ||
      !siteSettings?.course_progress_docs_sidebar_only_on_index_category
    ) {
      return;
    }

    // Doc Categories is an optional dependency.
    if (!container.factoryFor?.("service:doc-category-sidebar")) {
      return;
    }

    withPluginApi((api) => {
      api.modifyClass(
        "service:doc-category-sidebar",
        (Superclass) =>
          class extends Superclass {
            // Upstream resolves the index by walking up the category tree, so
            // every subcategory of a docs category inherits its sidebar.
            // Returning nothing for those categories stops the walk before it
            // starts, leaving the sidebar only where an index is configured.
            get activeCategory() {
              const category = super.activeCategory;

              return category?.doc_category_index ? category : undefined;
            }
          }
      );
    });
  },
};
