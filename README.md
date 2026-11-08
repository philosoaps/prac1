# My Life Planner

A Flutter life-planning app using MVVM with Riverpod state management.

## Project structure

```text
lib/
  core/                 App-wide theme, constants, and timezone utilities
  data/
    models/             Settings, calendar category, task, and goal models
    repositories/       Google API and local persistence access
  presentation/
    viewmodels/         Riverpod providers and screen state
    views/              Auth, calendar, tasks, and Life Goal screens
    widgets/             Reusable UI, including the settings drawer
  services/             Authentication and external service integrations
```

Views render state and send user actions to Riverpod viewmodels. Viewmodels
coordinate repositories, which isolate Google API and local storage details
from the UI.

## Calendar and preferences

The calendar opens by default and supports month, week, day, and continuous
schedule views. All views share an eight-column layout with a week-number rail.
Horizontal swipes move by week; vertical swipes move the week/day schedule
views, while continuous schedules load in two-week ranges.
Calendar preferences include a 3x3 app-theme palette, week start day, time
zone, language, and five color-coded time categories. The selected time zone
is used for calendar display and schedule creation. The shared schedule/task
composer offers simple and detailed modes. Every schedule requires an active
Google Task and stores its ID and name in the event's private extended
properties. Detailed schedules also support descriptions, locations,
categories, recurrence, availability, and visibility. Tasks support optional
due dates and detailed notes.

The Life Goal screen is available from the app menu and saves its content to
Google Drive's app data folder.
