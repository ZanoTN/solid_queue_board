# frozen_string_literal: true

require_relative "lib/solid_queue_board/version"

Gem::Specification.new do |spec|
  spec.name = "solid_queue_board"
  spec.version = SolidQueueBoard::VERSION
  spec.authors = [ "Riccardo Zanotelli" ]
  spec.summary = "A self-contained, auto-refreshing dashboard for Solid Queue."
  spec.description = "Mountable Rails engine to inspect and operate Solid Queue: jobs by state, failed job retry/discard, " \
                     "queues pause/resume, recurring tasks and processes. Plain HTML tables, light and dark theme, " \
                     "polling refresh, no JavaScript or CSS dependencies."
  spec.license = "MIT"
  spec.homepage = "https://github.com/ZanoTN/solid_queue_board"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["{app,config,lib}/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "railties", ">= 7.1"
  spec.add_dependency "actionpack", ">= 7.1"
  spec.add_dependency "activerecord", ">= 7.1"
  # Uses Solid Queue's models directly (executions, Queue, RecurringTask, Process):
  # stay on 1.x until a new major version has been checked.
  spec.add_dependency "solid_queue", "~> 1.0"
end
