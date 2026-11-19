# frozen_string_literal: true

module SolidQueueBoard
  class JobsController < ApplicationController
    before_action :set_job, only: %i[retry discard]

    def index
      @query = JobsQuery.new(status: params[:status], search: params[:q], queue: params[:queue], page: params[:page])
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
      def set_job
        @job = SolidQueue::Job.find_by(id: params[:id])
        back_to_board jobs_path, alert: t("solid_queue_board.flash.not_found", id: params[:id]) unless @job
      end
  end
end
