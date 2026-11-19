# frozen_string_literal: true

module SolidQueueBoard
  # Filters, searches and paginates SolidQueue::Job rows for the jobs table.
  class JobsQuery
    STATUSES = %w[all ready claimed scheduled blocked failed finished].freeze

    EXECUTIONS = {
      "ready" => SolidQueue::ReadyExecution,
      "claimed" => SolidQueue::ClaimedExecution,
      "scheduled" => SolidQueue::ScheduledExecution,
      "blocked" => SolidQueue::BlockedExecution,
      "failed" => SolidQueue::FailedExecution
    }.freeze

    attr_reader :status, :search, :queue, :page, :per_page

    def self.counts
      EXECUTIONS.transform_values(&:count).merge(
        "all" => SolidQueue::Job.count,
        "finished" => SolidQueue::Job.finished.count
      )
    end

    def initialize(status: nil, search: nil, queue: nil, page: nil, per_page: SolidQueueBoard.per_page)
      @status = STATUSES.include?(status.to_s) ? status.to_s : "all"
      @search = search.to_s.strip.presence
      @queue = queue.to_s.strip.presence
      @page = [ page.to_i, 1 ].max
      @per_page = per_page
    end

    # Loads one extra row to know whether a next page exists.
    def jobs
      @jobs ||= scope
        .includes(:ready_execution, :claimed_execution, :failed_execution, :scheduled_execution, :blocked_execution)
        .order(id: :desc)
        .offset((page - 1) * per_page)
        .limit(per_page + 1)
        .to_a
    end

    def rows = jobs.first(per_page)
    def next_page? = jobs.size > per_page
    def prev_page? = page > 1

    private
      def scope
        relation = by_status(SolidQueue::Job.all)
        relation = relation.where(queue_name: queue) if queue
        relation = by_search(relation) if search
        relation
      end

      def by_status(relation)
        case status
        when "finished" then relation.finished
        when "all" then relation
        else relation.where(id: EXECUTIONS.fetch(status).select(:job_id))
        end
      end

      def by_search(relation)
        table = SolidQueue::Job.arel_table
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search)}%"
        condition = table[:class_name].matches(pattern).or(table[:active_job_id].eq(search))
        condition = condition.or(table[:id].eq(search.to_i)) if search.match?(/\A\d+\z/)
        relation.where(condition)
      end
  end
end
