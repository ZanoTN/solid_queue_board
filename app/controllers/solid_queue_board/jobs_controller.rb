# frozen_string_literal: true

module SolidQueueBoard
  class JobsController < ApplicationController
    before_action :set_job, only: %i[retry discard]

    def index
      @query = JobsQuery.new(status: params[:status], search: params[:q], queue: params[:queue], page: params[:page])
      render json: live_payload if request.format.json?
    end

    def retry
      if @job.failed_execution
        @job.retry
        back_to_board jobs_path, notice: t("solid_queue_board.flash.retried", id: @job.id)
      else
        back_to_board jobs_path, alert: t("solid_queue_board.flash.not_failed", id: @job.id)
      end
    end

    def discard
      execution = @job.failed_execution || @job.ready_execution || @job.scheduled_execution || @job.blocked_execution
      if execution
        execution.discard
        back_to_board jobs_path, notice: t("solid_queue_board.flash.discarded", id: @job.id)
      else
        back_to_board jobs_path, alert: t("solid_queue_board.flash.not_discardable", id: @job.id)
      end
    end

    def retry_all
      failed = SolidQueue::Job.where(id: SolidQueue::FailedExecution.select(:job_id))
      count = failed.count
      SolidQueue::FailedExecution.retry_all(failed) if count.positive?
      back_to_board jobs_path, notice: t("solid_queue_board.flash.retried_all", count: count)
    end

    private
      # Auto-refresh of the jobs page: one HTML fragment per job row, keyed by id, so the page
      # can insert, update and remove rows one by one (and animate them). Markup stays in ERB.
      def live_payload
        fragment = ->(partial, **locals) { render_to_string(partial: partial, formats: [ :html ], locals: locals) }
        {
          nav: fragment.call("solid_queue_board/shared/nav"),
          toolbar: fragment.call("solid_queue_board/jobs/toolbar"),
          pager: fragment.call("solid_queue_board/jobs/pager"),
          empty: (fragment.call("solid_queue_board/jobs/empty") if @query.rows.empty?),
          rows: @query.rows.map do |job|
            { id: job.id.to_s, sig: helpers.sqb_job_status(job), html: fragment.call("solid_queue_board/jobs/row", job: job) }
          end
        }
      end

      def set_job
        @job = SolidQueue::Job.find_by(id: params[:id])
        back_to_board jobs_path, alert: t("solid_queue_board.flash.not_found", id: params[:id]) unless @job
      end
  end
end
