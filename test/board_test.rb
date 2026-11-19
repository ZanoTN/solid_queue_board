# frozen_string_literal: true

require "test_helper"

class JobsPageTest < BoardTest
  test "lists jobs with state counts in the menu" do
    enqueue(SampleJob, 1)
    fail!(enqueue(SampleJob, 2), "kaboom")

    get "/jobs"
    assert_response :success
    assert_includes response.body, "<!DOCTYPE html>"
    assert_select "nav.tabs a.tab", 10
    assert_select "a.tab[aria-current=page]", text: /All\s*2/
    assert_select "a.tab", text: /Failed\s*1/
    assert_select "tr[data-sqb-sig=failed]", 1
    assert_select "tr[data-sqb-sig=ready]", 1
    assert_includes response.body, "kaboom"
  end

  test "filters by status, search and queue" do
    enqueue(SampleJob)
    enqueue(OtherJob)
    fail!(enqueue(SampleJob))

    get "/jobs", params: { status: "failed" }
    assert_select "tr[data-sqb-sig]", 1

    get "/jobs", params: { q: "Other" }
    assert_select "tr[data-sqb-sig]", 1
    assert_select "span.cls", text: "OtherJob"

    get "/jobs", params: { queue: "mailers" }
    assert_select "tr[data-sqb-sig]", 1
  end

  test "partial requests return only the live region" do
    enqueue
    get "/jobs", headers: { "X-SQB-Partial" => "1" }
    assert_response :success
    assert_not_includes response.body, "<html"
    assert_select "nav.tabs"
    assert_select "main.panel"
  end

  test "retries and discards failed jobs" do
    job = fail!(enqueue)
    post "/jobs/jobs/#{job.id}/retry"
    assert_redirected_to "/jobs/jobs"
    assert job.reload.ready_execution
    assert_nil job.failed_execution

    other = fail!(enqueue)
    post "/jobs/jobs/#{other.id}/discard"
    assert_nil SolidQueue::Job.find_by(id: other.id)
  end

  test "retries all failed jobs" do
    2.times { fail!(enqueue) }
    post "/jobs/jobs/retry_all"
    assert_equal 0, SolidQueue::FailedExecution.count
    assert_equal 2, SolidQueue::ReadyExecution.count
  end

  test "paginates" do
    SolidQueueBoard.per_page = 2
    3.times { enqueue }
    get "/jobs"
    assert_select "tr[data-sqb-sig]", 2
    assert_select ".pager a", 1
    get "/jobs", params: { page: 2 }
    assert_select "tr[data-sqb-sig]", 1
  ensure
    SolidQueueBoard.per_page = 50
  end

  test "denies access when authorize returns false" do
    SolidQueueBoard.authorize = ->(_) { false }
    get "/jobs"
    assert_response :forbidden
  end

  test "renders in Italian" do
    I18n.with_locale(:it) do
      fail!(enqueue)
      get "/jobs"
      assert_select "a.tab", text: /Falliti\s*1/
    end
  end
end

class QueuesPageTest < BoardTest
  test "lists, pauses and resumes queues" do
    enqueue(SampleJob)
    get "/jobs/queues"
    assert_response :success
    assert_select "td.cls", text: "default"

    post "/jobs/queues/default/pause"
    assert SolidQueue::Queue.find_by_name("default").paused?
    post "/jobs/queues/default/resume"
    assert_not SolidQueue::Queue.find_by_name("default").paused?
  end
end

class RecurringPageTest < BoardTest
  test "lists recurring tasks and runs one now" do
    SolidQueue::RecurringTask.create!(key: "nightly_sample", class_name: "SampleJob", schedule: "every day at 3am", static: true)
    get "/jobs/recurring_tasks"
    assert_response :success
    assert_select "td.cls", text: "nightly_sample"

    assert_difference -> { SolidQueue::Job.count }, 1 do
      post "/jobs/recurring_tasks/nightly_sample/run"
    end
  end
end

class ProcessesPageTest < BoardTest
  test "lists processes with heartbeat status" do
    SolidQueue::Process.create!(kind: "Worker", pid: 42, hostname: "web-1", name: "worker-abc",
                                last_heartbeat_at: Time.current, metadata: { queues: "*", thread_pool_size: 3 })
    get "/jobs/processes"
    assert_response :success
    assert_select "td.cls", text: "Worker"
    assert_select ".label-success"
  end
end
