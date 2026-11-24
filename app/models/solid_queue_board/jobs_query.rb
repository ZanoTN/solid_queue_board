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

    SORTABLE = %w[id class_name queue_name created_at scheduled_at finished_at].freeze
    DIRECTIONS = %w[asc desc].freeze

    attr_reader :status, :search, :queue, :job_class, :sort_attribute, :sort_direction, :page, :per_page

    def self.counts
      EXECUTIONS.transform_values(&:count).merge(
        "all" => SolidQueue::Job.count,
        "finished" => SolidQueue::Job.finished.count
      )
    end

    # filters: the Ransack params (param "f"). Only the job class filter and the sort are read.
    def initialize(status: nil, search: nil, queue: nil, filters: nil, page: nil, per_page: SolidQueueBoard.per_page)
      @status = STATUSES.include?(status.to_s) ? status.to_s : "all"
      @search = search.to_s.strip.presence
      @queue = queue.to_s.strip.presence
      filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)
      filters = filters.is_a?(Hash) ? filters.with_indifferent_access : {}
      @job_class = filters["class_name_eq"].to_s.strip.presence
      @sort_attribute, @sort_direction = filters["s"].to_s.split
      @sort_attribute = @sort_direction = nil unless SORTABLE.include?(@sort_attribute) && DIRECTIONS.include?(@sort_direction)
      @page = [ page.to_i, 1 ].max
      @per_page = per_page
    end

    # Loads one extra row to know whether a next page exists.
    def jobs
      @jobs ||= scope
        .includes(:ready_execution, :claimed_execution, :failed_execution, :scheduled_execution, :blocked_execution)
        .order(id: :desc) # after the Ransack sort: newest first, and a stable order for paging
        .offset((page - 1) * per_page)
        .limit(per_page + 1)
        .to_a
    end

    def rows = jobs.first(per_page)
    def next_page? = jobs.size > per_page
    def prev_page? = page > 1
    def filtered? = !!(search || queue || job_class)

    # Job classes for the filter menu (solid_queue_jobs has an index on class_name).
    def job_classes
      @job_classes ||= JobRecord.distinct.order(:class_name).pluck(:class_name)
    end

    # The time shown in the "When" column, as a sortable attribute.
    def time_attribute
      { "finished" => "finished_at", "scheduled" => "scheduled_at" }.fetch(status, "created_at")
    end

    def sort = ("#{sort_attribute} #{sort_direction}" if sort_attribute)

    # Query string for links on the jobs page; overrides replace or (with nil) drop a value.
    def url_params(**overrides)
      params = { status: (status == "all" ? nil : status), q: search, queue: queue, class_name: job_class, sort: sort, page: nil }
        .merge(overrides)
      filters = { class_name_eq: params.delete(:class_name), s: params.delete(:sort) }.compact
      params.merge(f: filters.presence).compact
    end

    private
      def scope
        relation = by_status(JobRecord.all)
        relation = relation.where(queue_name: queue) if queue
        relation = by_search(relation) if search
        relation.ransack({ "class_name_eq" => job_class, "s" => sort }.compact).result
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
