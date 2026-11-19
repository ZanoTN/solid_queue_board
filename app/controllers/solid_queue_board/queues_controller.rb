# frozen_string_literal: true

module SolidQueueBoard
  class QueuesController < ApplicationController
    def index
      paused = SolidQueue::Pause.pluck(:queue_name)
      names = (SolidQueue::Queue.all.map(&:name) + paused).uniq.sort
      @queues = names.map { |name| SolidQueue::Queue.find_by_name(name) }
    end

    def pause
      SolidQueue::Queue.find_by_name(params[:name]).pause
      back_to_board queues_path, notice: t("solid_queue_board.flash.paused", name: params[:name])
    end

    def resume
      SolidQueue::Queue.find_by_name(params[:name]).resume
      back_to_board queues_path, notice: t("solid_queue_board.flash.resumed", name: params[:name])
    end
  end
end
