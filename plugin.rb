# name: discourse-course-progress
# about: Returns true historical read progress for Doc Categories with configured index topics. Adds `/course-progress.json` for LMS-style course progress tracking. Build your own theme component UI, or install https://github.com/zsviczian/discourse-course-progress-theme for ready-made badges and checkmarks. Builds on the Discourse Doc Categories plugin.
# version: 0.1
# authors: zsviczian

enabled_site_setting :course_progress_enabled

register_asset "stylesheets/common.scss"

after_initialize do
  # Load the controller
  load File.expand_path('../app/controllers/course_progress_controller.rb', __FILE__)

  # Create the custom route
  Discourse::Application.routes.append do
    get '/course-progress' => 'course_progress#index', constraints: { format: 'json' }
  end
end