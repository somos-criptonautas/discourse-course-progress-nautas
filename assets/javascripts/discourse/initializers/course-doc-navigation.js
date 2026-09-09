import { withPluginApi } from "discourse/lib/plugin-api";
import CourseDocNavigation from "../components/course-doc-navigation";

export default {
  name: "course-doc-navigation",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (
      !siteSettings?.course_progress_enabled ||
      !siteSettings?.course_progress_doc_navigation_enabled
    ) {
      return;
    }

    withPluginApi((api) => {
      api.renderInOutlet("topic-area-bottom", CourseDocNavigation);
    });
  },
};
