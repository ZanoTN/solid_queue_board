# frozen_string_literal: true

module SolidQueueBoard
  module ApplicationHelper
    STATUS_TONES = {
      "ready" => "primary", "claimed" => "info", "scheduled" => "default",
      "blocked" => "warning", "failed" => "danger", "finished" => "success"
    }.freeze

    NAV_TONES = { "ready" => "warning", "claimed" => "info", "blocked" => "warning", "failed" => "danger" }.freeze

    def sqb_t(key, **options)
      t("solid_queue_board.#{key}", **options)
    end

    # ---- layout ----

    def sqb_inline_css
      tag.style(SolidQueueBoard::Web.css.html_safe, nonce: content_security_policy_nonce)
    end

    def sqb_inline_js
      tag.script(SolidQueueBoard::Web.js.html_safe, nonce: content_security_policy_nonce)
    end

    def sqb_nav_tab(label, url, count:, active:, tone: nil)
      badge = tag.span(count, class: [ "badge", (tone if count.to_i.positive?) ])
      link_to(safe_join([ label, badge ], " "), url, class: "tab", "aria-current": (active ? "page" : nil))
    end

    # ---- jobs ----

    def sqb_job_status(job)
      return "finished" if job.finished?
      return "failed" if job.failed_execution
      return "claimed" if job.claimed_execution
      return "ready" if job.ready_execution
      return "scheduled" if job.scheduled_execution
      return "blocked" if job.blocked_execution

      "unknown"
    end

    def sqb_status_label(status, text = nil)
      tag.span(text || sqb_t("status.#{status}"), class: "label label-#{STATUS_TONES.fetch(status.to_s, 'default')}")
    end

    def sqb_job_time(job, status)
      case status
      when "finished" then job.finished_at
      when "failed" then job.failed_execution.created_at
      when "claimed" then job.claimed_execution.created_at
      when "scheduled" then job.scheduled_at
      else job.created_at
      end
    end

    def sqb_job_detail(job, status)
      case status
      when "finished"
        sqb_duration(job.finished_at - job.created_at) if job.finished_at && job.created_at
      when "failed"
        tag.span(job.failed_execution.exception_class, class: "err-msg")
      when "claimed"
        tag.span(sqb_t("jobs.running_for", time: sqb_duration(Time.current - job.claimed_execution.created_at)), class: "muted")
      when "blocked"
        tag.span(sqb_t("jobs.blocked_by", key: job.concurrency_key), class: "muted")
      end
    end

    def sqb_payload(job)
      job.arguments.is_a?(Hash) ? job.arguments : { "arguments" => job.arguments }
    end

    def sqb_arguments(job, limit: 120)
      args = sqb_simplify(sqb_payload(job)["arguments"] || [])
      text = args.is_a?(String) ? args : JSON.generate(args)
      text.length > limit ? "#{text[0, limit]}…" : text
    rescue StandardError
      ""
    end

    def sqb_arguments_pretty(job)
      JSON.pretty_generate(sqb_simplify(sqb_payload(job)["arguments"] || []))
    rescue StandardError
      sqb_payload(job)["arguments"].inspect
    end

    def sqb_executions(job)
      sqb_payload(job)["executions"]
    end

    # Column header that sorts the jobs by attribute: first click descending (newest, Z-A), then toggles.
    def sqb_sort_header(label, attribute)
      current = @query.sort_attribute == attribute ? @query.sort_direction : nil
      next_direction = current == "desc" ? "asc" : "desc"
      arrow = { "asc" => "\u25B2", "desc" => "\u25BC" }[current]
      link = link_to(jobs_path(@query.url_params(sort: "#{attribute} #{next_direction}")), class: "sort",
                     title: sqb_t("jobs.sort_by", column: label)) do
        safe_join([ label, (tag.span(arrow, class: "sort-dir", "aria-hidden": true) if arrow) ].compact, " ")
      end
      tag.th(link, "aria-sort": { "asc" => "ascending", "desc" => "descending" }.fetch(current, "none"))
    end

    def sqb_discardable?(status)
      %w[failed ready scheduled blocked].include?(status)
    end

    # ---- formatting ----

    def sqb_time(time)
      return tag.span("—", class: "muted") unless time

      time = time.in_time_zone
      format = time.to_date == Time.zone.today ? "%H:%M:%S" : sqb_t("formats.datetime")
      tag.time(datetime: time.iso8601, title: time.strftime(sqb_t("formats.full"))) do
        safe_join([ time.strftime(format), " ", tag.span("(#{sqb_ago(time)})", class: "muted") ])
      end
    end

    def sqb_ago(time)
      seconds = (Time.current - time).round
      amount = sqb_amount(seconds.abs)
      seconds >= 0 ? sqb_t("time.ago", time: amount) : sqb_t("time.in", time: amount)
    end

    def sqb_amount(seconds)
      if seconds < 60 then sqb_t("time.seconds", count: seconds)
      elsif seconds < 3600 then sqb_t("time.minutes", count: seconds / 60)
      elsif seconds < 86_400 then sqb_t("time.hours", count: seconds / 3600, minutes: (seconds % 3600) / 60)
      else sqb_t("time.days", count: seconds / 86_400)
      end
    end

    def sqb_duration(seconds)
      seconds = seconds.to_f
      return "#{(seconds * 1000).round} ms" if seconds < 1
      return "#{seconds.round(1)} s" if seconds < 60

      sqb_amount(seconds.round)
    end

    def sqb_metadata(metadata)
      return "" if metadata.blank?

      metadata.map { |key, value| "#{key}: #{value.is_a?(Array) ? value.join(', ') : value}" }.join(" · ")
    end

    private
      # Shows ActiveJob GlobalID arguments as their gid string instead of the wrapper hash.
      def sqb_simplify(value)
        case value
        when Array then value.map { |item| sqb_simplify(item) }
        when Hash
          return value["_aj_globalid"] if value.key?("_aj_globalid")

          value.except("_aj_symbol_keys", "_aj_ruby2_keywords", "_aj_serialized").transform_values { |item| sqb_simplify(item) }
        else value
        end
      end
  end
end
