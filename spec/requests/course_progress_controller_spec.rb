# frozen_string_literal: true

RSpec.describe CourseProgressController do
  fab!(:user)
  fab!(:category, :category_with_definition)
  fab!(:subcategory) { Fabricate(:category_with_definition, parent_category_id: category.id) }
  fab!(:index_topic) { Fabricate(:topic_with_op, category: category) }
  fab!(:lesson) { Fabricate(:topic, category: category) }
  fab!(:sub_lesson) { Fabricate(:topic, category: subcategory) }

  let!(:index) { DocCategories::Index.create!(category: category, index_topic: index_topic) }

  def add_links(*topics, section: nil)
    section ||= index.sidebar_sections.create!(title: "Lessons", position: 0)
    topics.each_with_index do |topic, position|
      section.sidebar_links.create!(
        title: topic.title,
        href: topic.relative_url,
        topic_id: topic.id,
        position: position,
      )
    end
    section
  end

  def course
    response.parsed_body["courses"][category.id.to_s]
  end

  before { SiteSetting.course_progress_enabled = true }

  it "refuses anonymous requests" do
    get "/course-progress.json"
    expect(response.status).to eq(403)
  end

  context "when signed in" do
    before { sign_in(user) }

    it "counts the lessons listed in the index, including ones in subcategories" do
      add_links(lesson, sub_lesson)

      get "/course-progress.json"

      expect(response.status).to eq(200)
      expect(course["total_topics"]).to eq(2)
      expect(course["read_count"]).to eq(0)
      expect(course["read_topic_ids"]).to eq([])
    end

    it "excludes the index topic itself" do
      add_links(index_topic, lesson)

      get "/course-progress.json"

      expect(course["total_topics"]).to eq(1)
    end

    it "reports the topics the user has read" do
      add_links(lesson, sub_lesson)
      TopicUser.create!(user_id: user.id, topic_id: lesson.id, last_read_post_number: 1)

      get "/course-progress.json"

      expect(course["read_count"]).to eq(1)
      expect(course["read_topic_ids"]).to eq([lesson.id])
    end

    it "skips lessons the user cannot see" do
      restricted = Fabricate(:private_category, group: Fabricate(:group))
      borrowed = Fabricate(:topic, category: restricted)
      add_links(lesson, borrowed)

      get "/course-progress.json"

      expect(course["total_topics"]).to eq(1)
    end

    it "hides courses in categories the user cannot see" do
      restricted = Fabricate(:private_category, group: Fabricate(:group))
      restricted_index_topic = Fabricate(:topic_with_op, category: restricted)
      DocCategories::Index.create!(category: restricted, index_topic: restricted_index_topic)
      add_links(lesson)

      get "/course-progress.json"

      expect(response.parsed_body["courses"].keys).to eq([category.id.to_s])
    end

    it "falls back to a category scan when the index has not been parsed yet" do
      get "/course-progress.json"

      # `lesson` only; the index topic and the category definition topic are not
      # course content, and `sub_lesson` is out of reach without a parsed index.
      expect(course["total_topics"]).to eq(1)
    end
  end
end
