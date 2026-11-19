# frozen_string_literal: true

module SolidQueueBoard
  class ProcessesController < ApplicationController
    def index
      @processes = SolidQueue::Process.order(:hostname, :kind, :id).to_a
      @claimed = SolidQueue::ClaimedExecution.group(:process_id).count
    end
  end
end
