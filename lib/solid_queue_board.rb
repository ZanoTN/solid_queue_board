# frozen_string_literal: true

require "solid_queue"
require "solid_queue_board/version"
require "solid_queue_board/engine"

# A self-contained dashboard for Solid Queue.
#
#   # config/routes.rb
#   mount SolidQueueBoard::Engine, at: "/jobs"
#
#   # config/initializers/solid_queue_board.rb
#   SolidQueueBoard.configure do |config|
#     config.base_controller_class = "ApplicationController"
#     config.authorize = ->(controller) { controller.current_user&.admin? }
#   end
module SolidQueueBoard
  # Controller the dashboard inherits from. Use your ApplicationController to reuse its
  # authentication (before_actions, current_user, ...).
  mattr_accessor :base_controller_class, default: "ActionController::Base"

  # Called with the controller instance before every action. Return true to allow access.
  # Default: open only in development and test, closed everywhere else.
  mattr_accessor :authorize, default: ->(_controller) { Rails.env.local? }

  # Title shown in the top bar. Defaults to the host application name.
  mattr_accessor :title, default: nil

  # Link shown in the top bar to go back to the host application (nil hides it).
  mattr_accessor :back_url, default: "/"

  # Rows per page in the jobs table.
  mattr_accessor :per_page, default: 50

  # Auto-refresh choices, in seconds (0 = off), and the default one.
  mattr_accessor :poll_intervals, default: [ 3, 6, 12, 24, 0 ]
  mattr_accessor :default_poll_interval, default: 6

  def self.configure
    yield self
  end

  def self.app_title
    return title if title.present?

    klass = Rails.application.class
    name = klass.module_parent_name || klass.name.to_s.delete_suffix("Application")
    name.underscore.humanize
  end
end
