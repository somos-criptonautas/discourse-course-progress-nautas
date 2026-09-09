class CourseProgressController < ::ApplicationController
  requires_login # Only logged-in users have read histories

  def index
    # 0. Safety check: Ensure the Docs plugin table actually exists
    unless ActiveRecord::Base.connection.table_exists?('doc_categories_indexes')
      return render json: { courses: {} }
    end

    # 1. Query the Docs table for the categories configured as courses, plus
    #    each course's Index Topic. The index is navigation, not course
    #    content, so it is excluded from the progress totals below.
    #    NB: DB.query_single flattens results, so keep one column per call.
    course_category_ids = DB.query_single("SELECT category_id FROM doc_categories_indexes").uniq
    index_topic_ids = DB.query_single("SELECT index_topic_id FROM doc_categories_indexes").to_set

    # Fail gracefully if no courses are configured
    return render json: { courses: {} } if course_category_ids.empty?

    # 2. Grab ALL topic IDs inside those course categories
    topic_data = Topic.where(category_id: course_category_ids, deleted_at: nil).pluck(:id, :category_id)
    all_topic_ids = topic_data.map(&:first)

    # 3. Ask the TopicUser table: "Out of this huge list of topic IDs, which ones has THIS user read?"
    read_topic_ids = TopicUser
      .where(user_id: current_user.id, topic_id: all_topic_ids)
      .where('last_read_post_number >= 1')
      .pluck(:topic_id)
      .to_set

    # 4. Build the final JSON payload
    results = {}

    course_category_ids.each do |cat_id|
      results[cat_id] = { total_topics: 0, read_count: 0, read_topic_ids: [] }
    end

    # Tally up the totals and the read states
    topic_data.each do |topic_id, cat_id|
      next unless results[cat_id]
      next if index_topic_ids.include?(topic_id)

      results[cat_id][:total_topics] += 1

      if read_topic_ids.include?(topic_id)
        results[cat_id][:read_topic_ids] << topic_id
        results[cat_id][:read_count] += 1
      end
    end

    render json: { courses: results }
  end
end