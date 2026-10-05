# Chronicle

A bill, budget, and business expense tracker for macOS.

## What it does

- Bills
- templates
- categorisation
- import/export
- sharing

## Targets

- macOS with widgets

## Structure

Key types:

- ``CategorizationEngine``
- ``TemplateService``
- ``BusinessService``
- ``BillStore``
- ``ExchangeRateService``
- ``iCloudSyncManager``
- ``ImportExportView``

Also carries `AIInsightsService` and an `APIServerView`. Substantially larger than the iOS sibling — 50 Swift files.

## Status

Apple-platform experiment built to explore what an AI coding agent could produce for a native app. Not actively maintained.

Xcode projects here were generated with XcodeGen (`project.yml`) unless noted; open the `.xcodeproj` directly.
