// Upstream resolves a category's index by walking up the category tree, so
// every subcategory of a docs category inherits its sidebar. Narrowing
// `activeCategory` to categories that carry their own index ends that walk
// before it starts: `#findIndexForActiveCategory` then returns nothing and the
// service hides the sidebar by itself.
//
// The narrowing is installed on the service *instance*, not through
// modifyClass: Doc Categories looks the service up on the first line of its own
// initializer, and a class modified after instantiation is ignored (Discourse
// logs "it was already initialized earlier in the boot process" and moves on).
// An own property shadows the prototype getter whenever it is defined.
function scopeToIndexCategory(service) {
  let descriptor;
  let proto = Object.getPrototypeOf(service);

  while (proto && !descriptor) {
    descriptor = Object.getOwnPropertyDescriptor(proto, "activeCategory");
    proto = Object.getPrototypeOf(proto);
  }

  if (!descriptor?.get) {
    return;
  }

  const activeCategory = descriptor.get;

  Object.defineProperty(service, "activeCategory", {
    configurable: true,
    get() {
      const category = activeCategory.call(this);

      return category?.doc_category_index ? category : undefined;
    },
  });
}

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

    scopeToIndexCategory(container.lookup("service:doc-category-sidebar"));
  },
};
