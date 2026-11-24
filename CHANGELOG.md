# Changelog

## 0.1.1 (2026-11-25)

- Security: the dashboard now checks the CSRF token itself (`protect_from_forgery with: :exception`).
  Before, retry, discard, pause and "run now" were protected only if the host app turned forgery
  protection on by default, so a host app without it was open to cross-site requests.
- Gem metadata: links to the issue tracker and the documentation on rubygems.org.

## 0.1.0 (2026-11-24)

- First version: jobs by state (ready, running, scheduled, blocked, failed, finished), search and queue filter,
  failed job retry/discard and "retry all", queues pause/resume, recurring tasks with "run now", processes and heartbeats.
- Auto-refresh by polling (3, 6, 12, 24 s or paused; default 6 s), paused while the tab is hidden or the user is typing.
  Rows are updated in place (new, changed and removed rows only), so open rows, hover and animations survive a refresh.
  The jobs page refreshes through JSON with one HTML fragment per row; new rows slide in and the rows below move down.
- New jobs that appear on a refresh get one long green pulse (about 4 seconds); jobs that change state keep a short flash.
- Compact top bar: one live button (click cycles the refresh interval and refreshes) and one theme button.
- Jobs table in five columns with a status stripe; retry and discard sit on the row, "retry all" only on the Failed tab.
  Below 600px each job becomes a card, without horizontal scrolling.
- Processes expand on click like jobs: ID, start time and uptime, supervisor, supervised processes,
  full metadata and the jobs the process is running (each linked to the jobs list). Below 600px each process
  becomes a card, like the jobs.
- Jobs: filter by job class (menu in the toolbar) and sort by job, queue or time by clicking the column header.
  Built on Ransack, now a dependency; a read-only `SolidQueueBoard::JobRecord` model holds the Ransack allowlist,
  so the app's `SolidQueue::Job` is not changed.
- Fix: below 600px the job details were always open, and the card background and status stripe had gaps.
- Light and dark theme (system, light, dark), Bootstrap 3 look with square corners.
- English, Italian, German, Spanish, French, Portuguese, Simplified Chinese, Japanese and Korean translations.
