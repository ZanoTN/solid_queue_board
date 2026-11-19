# Changelog

## 0.1.0 (unreleased)

- First version: jobs by state (ready, running, scheduled, blocked, failed, finished), search and queue filter,
  failed job retry/discard and "retry all", queues pause/resume, recurring tasks with "run now", processes and heartbeats.
- Auto-refresh by polling (off, 2, 5, 10, 30 s), paused while the tab is hidden or the user is typing.
  Rows are updated in place (new, changed and removed rows only), so open rows, hover and animations survive a refresh.
- New jobs that appear on a refresh pulse green twice for about 3 seconds; jobs that change state keep a short flash.
- Light and dark theme (system, light, dark), Bootstrap 3 look with square corners.
- English and Italian translations.
