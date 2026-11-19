# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
ENV["DATABASE_URL"] = "sqlite3::memory:"

require "rails"
require "active_record/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "solid_queue"
require "solid_queue_board"

# Minimal host application: SQLite in memory, Solid Queue as Active Job adapter.
class DummyApp < Rails::Application
  config.root = __dir__
  config.eager_load = false
  config.secret_key_base = "test" * 16
  config.hosts.clear
  config.logger = Logger.new(nil)
  config.active_support.deprecation = :silence
  config.active_job.queue_adapter = :solid_queue
  config.action_controller.allow_forgery_protection = false
  config.i18n.available_locales = %i[en it]
  config.i18n.default_locale = :en
end

Rails.application.initialize!
Rails.application.routes.draw do
  mount SolidQueueBoard::Engine, at: "/jobs"
end

ActiveRecord::Schema.verbose = false
load Gem.loaded_specs["solid_queue"].full_gem_path + "/lib/generators/solid_queue/install/templates/db/queue_schema.rb"

require "minitest/autorun"
require "rails/test_help"

class SampleJob < ActiveJob::Base
  queue_as :default
  def perform(*); end
end

class OtherJob < ActiveJob::Base
  queue_as :mailers
  def perform(*); end
end

class BoardTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = true

  setup { SolidQueueBoard.authorize = ->(_) { true } }

  # Rails 7.1 swaps every job to the test adapter inside integration tests: keep Solid Queue.
  def queue_adapter_for_test
    ActiveJob::QueueAdapters::SolidQueueAdapter.new
  end

  def enqueue(job_class = SampleJob, *args, **options)
    job_class.set(**options).perform_later(*args)
    SolidQueue::Job.order(:id).last
  end

  def fail!(job, message = "boom")
    job.ready_execution&.destroy!
    job.failed_with(RuntimeError.new(message).tap { |e| e.set_backtrace([ "app/jobs/sample_job.rb:3:in 'perform'" ]) })
    job.reload
  end
end
