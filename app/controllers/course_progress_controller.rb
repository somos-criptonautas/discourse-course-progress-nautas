# frozen_string_literal: true

class CourseProgressController < ::ApplicationController
  requires_login # Only logged-in users have read histories

  INDEXES_TABLE = "doc_categories_indexes"
  SECTIONS_TABLE = "doc_categories_sidebar_sections"
  LINKS_TABLE = "doc_categories_sidebar_links"

  def index
    # 0. Safety check: the Doc Categories plugin may not be installed at all.
    return render json: { courses: {} } unless table_exists?(INDEXES_TABLE)

    # 1. Which categories are configured as courses, and which topic is each
    #    course's Index Topic. The index is navigation, not course content, so
    #    it is excluded from the totals below.
    #    NB: DB.query_single flattens results, so keep one column per call.
    course_category_ids = DB.query_single("SELECT category_id FROM #{INDEXES_TABLE}").uniq
    index_topic_ids = DB.query_single("SELECT index_topic_id FROM #{INDEXES_TABLE}").to_set

    # Only report on categories this user is allowed to see, otherwise the
    # payload leaks the existence and topic counts of restricted courses.
    course_category_ids &= Category.secured(guardian).where(id: course_category_ids).pluck(:id)

    return render json: { courses: {} } if course_category_ids.empty?

    # 2. Which topics make up each course. The Index Topic is the source of
    #    truth, so lessons living in subcategories (or borrowed from another
    #    category) are counted, matching the Previous/Next navigation.
    topic_data = indexed_topic_data(course_category_ids) || []

    # A course whose Index Topic has never been parsed (or that predates the
    # sidebar tables) yields nothing above; fall back to scanning its category
    # so it reports progress instead of a silent zero.
    unindexed = course_category_ids - topic_data.map(&:last)
    topic_data += category_topic_data(unindexed) if unindexed.any?

    topic_data.reject! { |topic_id, _| index_topic_ids.include?(topic_id) }

    # 3. Drop anything this user cannot see (restricted borrowed categories,
    #    deleted or private topics).
    visible_topic_ids =
      Topic
        .secured(guardian)
        .listable_topics
        .where(id: topic_data.map(&:first), deleted_at: nil)
        .pluck(:id)
        .to_set

    topic_data.select! { |topic_id, _| visible_topic_ids.include?(topic_id) }

    # 4. Ask TopicUser which of those this user has actually read.
    read_topic_ids =
      TopicUser
        .where(user_id: current_user.id, topic_id: topic_data.map(&:first))
        .where("last_read_post_number >= 1")
        .pluck(:topic_id)
        .to_set

    # 5. Build the payload.
    results = {}
    course_category_ids.each do |cat_id|
      results[cat_id] = { total_topics: 0, read_count: 0, read_topic_ids: [] }
    end

    topic_data.each do |topic_id, cat_id|
      next unless results[cat_id]

      results[cat_id][:total_topics] += 1

      if read_topic_ids.include?(topic_id)
        results[cat_id][:read_topic_ids] << topic_id
        results[cat_id][:read_count] += 1
      end
    end

    render json: { courses: results }
  end

  private

  def table_exists?(name)
    ActiveRecord::Base.connection.table_exists?(name)
  end

  # [[topic_id, category_id], ...] taken from the parsed Index Topic.
  # Returns nil when this Doc Categories version has no sidebar tables, so the
  # caller can fall back to the plain category scan.
  def indexed_topic_data(course_category_ids)
    return nil unless table_exists?(SECTIONS_TABLE) && table_exists?(LINKS_TABLE)
    return [] if course_category_ids.empty?

    DB.query_array(<<~SQL, category_ids: course_category_ids).uniq
      SELECT DISTINCT l.topic_id, i.category_id
      FROM #{INDEXES_TABLE} i
      JOIN #{SECTIONS_TABLE} s ON s.index_id = i.id
      JOIN #{LINKS_TABLE} l ON l.sidebar_section_id = s.id
      WHERE l.topic_id IS NOT NULL
        AND i.category_id IN (:category_ids)
    SQL
  end

  # Fallback for courses whose Index Topic has not been parsed: every topic
  # sitting directly in the course category, minus the "About this category"
  # definition topics. Misses subcategories.
  def category_topic_data(course_category_ids)
    return [] if course_category_ids.empty?

    categories = Category.where(id: course_category_ids)
    definition_topic_ids = categories.pluck(:topic_id).compact

    Topic
      .where(category_id: course_category_ids)
      .where.not(id: definition_topic_ids)
      .pluck(:id, :category_id)
  end
end
