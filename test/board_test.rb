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

  test "filters by job class through Ransack and keeps the filter in links" do
    enqueue(SampleJob)
    enqueue(OtherJob)

    get "/jobs", params: { f: { class_name_eq: "OtherJob" } }
    assert_response :success
    assert_select "tr[data-sqb-sig]", 1
    assert_select "span.cls", text: "OtherJob"
    assert_select "select[name='f[class_name_eq]'] option[selected]", text: "OtherJob"
    assert_select "select[name='f[class_name_eq]'] option", 3 # blank + 2 classes
    assert_select "th a.sort[href*='class_name_eq%5D=OtherJob']", 3
  end

  test "sorts columns through Ransack" do
    enqueue(SampleJob, queue: "zeta")
    enqueue(OtherJob, queue: "alpha")

    get "/jobs", params: { f: { s: "class_name asc" } }
    assert_equal %w[OtherJob SampleJob], css_select("span.cls").map(&:text)
    assert_select "th[aria-sort=ascending] a.sort[href*='class_name+desc']"

    get "/jobs", params: { f: { s: "queue_name desc" } }
    assert_equal %w[SampleJob OtherJob], css_select("span.cls").map(&:text)

    get "/jobs", params: { f: { s: "arguments desc" } } # not sortable: default order
    assert_response :success
    assert_select "th[aria-sort=descending]", 0

    get "/jobs", params: { f: "junk" }
    assert_response :success
  end

  test "partial requests return only the live region" do
    enqueue
    get "/jobs", headers: { "X-SQB-Partial" => "1" }
    assert_response :success
    assert_not_includes response.body, "<html"
    assert_select "nav.tabs"
    assert_select "main.panel"
  end

  test "auto-refresh of the jobs page returns JSON with one fragment per row" do
    job = enqueue
    fail!(enqueue)
    get "/jobs", headers: { "X-SQB-Partial" => "1", "Accept" => "application/json" }
    assert_response :success
    data = JSON.parse(response.body)
    assert_equal %w[nav pager rows toolbar empty].sort, data.keys.sort
    assert_equal 2, data["rows"].size
    row = data["rows"].find { |r| r["id"] == job.id.to_s }
    assert_equal "ready", row["sig"]
    assert_includes row["html"], %(data-sqb-toggle="#{job.id}")
    assert_includes row["html"], %(id="sqb-detail-#{job.id}")
    assert_includes data["nav"], "Failed"
    assert_nil data["empty"]
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

  test "shows retry all only on the failed tab, and row actions per status" do
    fail!(enqueue)
    enqueue
    get "/jobs"
    assert_select "form[action$='/retry_all']", 0
    assert_select "tr[data-sqb-sig=failed] .row-actions form", 2
    assert_select "tr[data-sqb-sig=ready] .row-actions form", 1
    get "/jobs", params: { status: "failed" }
    assert_select "form[action$='/retry_all']", 1
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

  test "every locale has the same keys and placeholders as English" do
    flatten = lambda do |hash, prefix = nil|
      hash.flat_map do |key, value|
        path = [ prefix, key ].compact.join(".")
        value.is_a?(Hash) ? flatten.call(value, path) : [ [ path, value.to_s.scan(/%\{\w+\}/).sort ] ]
      end
    end
    dir = File.expand_path("../config/locales", __dir__)
    english = flatten.call(YAML.load_file(File.join(dir, "en.yml"))["en"]).to_h

    Dir[File.join(dir, "*.yml")].each do |file|
      locale = File.basename(file, ".yml")
      other = flatten.call(YAML.load_file(file).fetch(locale)).to_h
      assert_equal english.keys.sort, other.keys.sort, "#{locale}.yml keys differ from en.yml"
      english.each { |key, vars| assert_equal vars, other[key], "#{locale}.yml #{key} placeholders differ" }
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

  test "expands a process to show supervisor and running jobs" do
    supervisor = SolidQueue::Process.create!(kind: "Supervisor", pid: 1, hostname: "web-1", name: "supervisor-1",
                                             last_heartbeat_at: Time.current)
    worker = SolidQueue::Process.create!(kind: "Worker", pid: 42, hostname: "web-1", name: "worker-abc",
                                         supervisor: supervisor, last_heartbeat_at: Time.current)
    job = enqueue
    SolidQueue::ClaimedExecution.create!(job: job, process: worker)

    get "/jobs/processes"
    assert_select "tr[data-sqb-toggle=p#{worker.id}]"
    assert_select "#sqb-detail-p#{worker.id}[hidden]" do
      assert_select "dd", text: /supervisor-1/
      assert_select "a[href=?]", "/jobs/jobs?q=#{job.id}"
    end
    assert_select "#sqb-detail-p#{supervisor.id} dd", text: /worker-abc/
  end
end
