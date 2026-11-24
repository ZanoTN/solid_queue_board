# frozen_string_literal: true

module SolidQueueBoard
  class ApplicationController < SolidQueueBoard.base_controller_class.constantize
    PARTIAL_HEADER = "X-SQB-Partial"

    layout :board_layout
    helper SolidQueueBoard::ApplicationHelper

    # Retry, discard, pause and run change data: check the CSRF token even when the host app
    # (or the base controller class) does not turn forgery protection on by default.
    protect_from_forgery with: :exception

    before_action :authorize_board!
    before_action :load_navigation

    private
      def authorize_board!
        return if SolidQueueBoard.authorize.call(self)

        render plain: I18n.t("solid_queue_board.forbidden"), status: :forbidden, layout: false
      end

      def load_navigation
        @job_counts = JobsQuery.counts
        @section_counts = {
          "queues" => SolidQueue::Queue.all.size,
          "recurring_tasks" => SolidQueue::RecurringTask.count,
          "processes" => SolidQueue::Process.count
        }
      end

      # Auto-refresh requests get only the live region (menu + content), not the full page.
      def partial_request?
        request.headers[PARTIAL_HEADER].present?
      end

      def board_layout
        partial_request? ? "solid_queue_board/partial" : "solid_queue_board/application"
      end

      def back_to_board(fallback, **flash_message)
        redirect_back fallback_location: fallback, allow_other_host: false, **flash_message
      end
  end
end
