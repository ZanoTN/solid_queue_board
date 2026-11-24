# frozen_string_literal: true

module SolidQueueBoard
  # Read model for the jobs table: SolidQueue::Job plus the Ransack allowlist, so the host app's
  # model is not touched. Same table, no STI column, so it loads every job.
  class JobRecord < SolidQueue::Job
    RANSACKABLE = %w[id class_name queue_name priority created_at scheduled_at finished_at].freeze

    def self.ransackable_attributes(_auth_object = nil) = RANSACKABLE
    def self.ransackable_associations(_auth_object = nil) = []
    def self.ransackable_scopes(_auth_object = nil) = []
  end
end
