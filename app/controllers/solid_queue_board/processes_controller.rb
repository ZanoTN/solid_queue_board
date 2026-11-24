# frozen_string_literal: true

module SolidQueueBoard
  class ProcessesController < ApplicationController
    def index
      @processes = SolidQueue::Process.order(:hostname, :kind, :id).to_a
      @by_id = @processes.index_by(&:id)
      @supervised = @processes.group_by(&:supervisor_id)
      @claimed = SolidQueue::ClaimedExecution.includes(:job).order(:id).group_by(&:process_id)
    end
  end
end
