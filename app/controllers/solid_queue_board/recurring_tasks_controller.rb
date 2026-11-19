# frozen_string_literal: true

module SolidQueueBoard
  class RecurringTasksController < ApplicationController
    def index
      @tasks = SolidQueue::RecurringTask.order(:key).to_a
      @last_runs = @tasks.to_h do |task|
        execution = SolidQueue::RecurringExecution.where(task_key: task.key).order(run_at: :desc).first
        job = execution && SolidQueue::Job.includes(:failed_execution, :claimed_execution, :ready_execution).find_by(id: execution.job_id)
        [ task.key, { at: execution&.run_at, job: job } ]
      end
    end

    def run
      task = SolidQueue::RecurringTask.find_by(key: params[:key])
      if task && task.enqueue(at: Time.current)
        back_to_board recurring_tasks_path, notice: t("solid_queue_board.flash.enqueued", key: task.key)
      else
        back_to_board recurring_tasks_path, alert: t("solid_queue_board.flash.not_enqueued", key: params[:key])
      end
    end
  end
end
