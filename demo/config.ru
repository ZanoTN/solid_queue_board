# frozen_string_literal: true

# Demo host app for looking at the dashboard. Not part of the gem (see gemspec "files").
# Run from the repo root: bundle exec rake demo   then open http://localhost:3000/jobs

ENV["RAILS_ENV"] = "development"

require "rails"
require "active_record/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "solid_queue"
require "solid_queue_board"

DB_FILE = ENV.fetch("DEMO_DB", File.join(__dir__, "demo.sqlite3"))

# Fresh database on every start (before Rails opens a connection).
Dir["#{DB_FILE}*"].each { |f| File.delete(f) }

class DemoApp < Rails::Application
  config.root = __dir__
  config.eager_load = false
  config.secret_key_base = "demo" * 16
  config.hosts.clear
  config.logger = Logger.new($stdout, level: :warn)
  config.active_job.queue_adapter = :solid_queue
  config.i18n.available_locales = %i[en it de es fr pt zh-CN ja ko]
  config.i18n.default_locale = :en
end

# Long busy timeout: worker, scheduler and web share one SQLite file.
ENV["DATABASE_URL"] = "sqlite3:#{DB_FILE}?timeout=30000&pool=10"
Rails.application.initialize!
Rails.application.routes.draw do
  root to: redirect("/jobs")
  mount SolidQueueBoard::Engine, at: "/jobs"
end

# The only job class. Run by the recurring task every 15 seconds; it also keeps
# just the last 10 finished jobs, so the list stays short.
class TestJob < ActiveJob::Base
  queue_as :default

  def perform(*)
    keep = SolidQueue::Job.finished.order(id: :desc).limit(10).pluck(:id)
    SolidQueue::Job.finished.where.not(id: keep).delete_all
  end
end

# Schema and sample data: one scheduled, one failed, one finished job.
ActiveRecord::Base.establish_connection
ActiveRecord::Schema.verbose = false
load Gem.loaded_specs["solid_queue"].full_gem_path + "/lib/generators/solid_queue/install/templates/db/queue_schema.rb"

def last_job = SolidQueue::Job.order(:id).last

TestJob.set(wait: 1.hour).perform_later("scheduled")
TestJob.perform_later("will fail")
last_job.ready_execution.destroy!
last_job.failed_with(RuntimeError.new("Timeout::Error: demo failure").tap { |e| e.set_backtrace([ "app/jobs/test_job.rb:5:in 'perform'" ]) })
TestJob.perform_later("done")
last_job.tap { |job| job.ready_execution.destroy! }.update!(finished_at: Time.current)

# Show Solid Queue thread errors in the terminal (otherwise a dying scheduler is silent).
SolidQueue.on_thread_error = ->(e) { warn "[demo] solid_queue thread error: #{e.class}: #{e.message}" }

# In-process worker and scheduler, so the recurring task runs (listed under "recurring").
SolidQueue::Worker.new(queues: "*", threads: 1, polling_interval: 1).start
test_task = SolidQueue::RecurringTask.from_configuration(
  "test_job", class: "TestJob", schedule: "every 15 seconds", description: "One test job every 15 seconds", static: true
)
begin
  SolidQueue::Scheduler.new(recurring_tasks: [ test_task ]).start
  warn "[demo] scheduler started: #{test_task.key} #{test_task.schedule}"
rescue => e
  warn "[demo] scheduler FAILED: #{e.class}: #{e.message}"
end

run Rails.application
