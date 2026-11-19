# frozen_string_literal: true

# Demo host app for looking at the dashboard. Not part of the gem (see gemspec "files").
# Run: cd demo && bundle install && bundle exec rackup -p 3000 -o 0.0.0.0   then open /jobs

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
  config.i18n.available_locales = %i[en it]
  config.i18n.default_locale = :en
end

# Long busy timeout: worker, scheduler and web share one SQLite file.
ENV["DATABASE_URL"] = "sqlite3:#{DB_FILE}?timeout=30000&pool=10"
Rails.application.initialize!
Rails.application.routes.draw do
  root to: redirect("/jobs")
  mount SolidQueueBoard::Engine, at: "/jobs"
end

class SampleJob < ActiveJob::Base
  queue_as :default
  def perform(*); end
end

class MailerJob < ActiveJob::Base
  queue_as :mailers
  def perform(*); end
end

class ReportJob < ActiveJob::Base
  queue_as :reports
  def perform(*); end
end

# Job that creates jobs: enqueues one test job. Scheduled as a recurring task below.
class SpawnerJob < ActiveJob::Base
  queue_as :default

  def perform
    [ SampleJob, MailerJob, ReportJob ].sample.perform_later(rand(100))
  end
end

# Schema and sample data.
ActiveRecord::Base.establish_connection
ActiveRecord::Schema.verbose = false
load Gem.loaded_specs["solid_queue"].full_gem_path + "/lib/generators/solid_queue/install/templates/db/queue_schema.rb"

def last_job = SolidQueue::Job.order(:id).last

def fail!(job, message)
  job.ready_execution&.destroy!
  job.failed_with(RuntimeError.new(message).tap { |e| e.set_backtrace([ "app/jobs/report_job.rb:12:in 'perform'", "app/jobs/application_job.rb:5:in 'block in <class:ApplicationJob>'" ]) })
end

3.times { |i| SampleJob.perform_later(i) }
2.times { |i| MailerJob.perform_later("user#{i}@example.com") }
2.times { |i| ReportJob.set(wait: (i + 1).hours).perform_later(i) }
%w[Timeout::Error ArgumentError].each_with_index do |msg, i|
  ReportJob.perform_later(i)
  fail!(last_job, "#{msg}: demo failure #{i + 1}")
end
2.times do |i|
  SampleJob.perform_later(i)
  last_job.finished! rescue last_job.update!(finished_at: Time.current)
end
SolidQueue::Queue.find_by_name("reports")&.pause

# Show Solid Queue thread errors in the terminal (otherwise a dying scheduler is silent).
SolidQueue.on_thread_error = ->(e) { warn "[demo] solid_queue thread error: #{e.class}: #{e.message}" }

# In-process worker so the spawner actually runs (it skips the paused "reports" queue).
SolidQueue::Worker.new(queues: "*", threads: 2, polling_interval: 1).start

# SpawnerJob as a recurring task, run by an in-process scheduler (listed under "recurring").
spawner_task = SolidQueue::RecurringTask.from_configuration(
  "spawner", class: "SpawnerJob", schedule: "every 10 seconds", description: "Enqueues one random test job", static: true
)
begin
  SolidQueue::Scheduler.new(recurring_tasks: [ spawner_task ]).start
  warn "[demo] scheduler started: #{spawner_task.key} #{spawner_task.schedule}"
rescue => e
  warn "[demo] scheduler FAILED: #{e.class}: #{e.message}"
end

run Rails.application
