# Chronicle for visionOS

Spatial computing companion for Apple's Vision Pro headset.

## Overview

Chronicle on visionOS reimagines bill tracking as a spatial experience — bills and
spending data exist in the user's environment rather than on a flat screen.

## Minimum Requirements

- **visionOS 1.0** (Apple Vision Pro, first generation)
- **RealityKit** for 3D rendering and spatial layouts
- **SwiftUI** for UI components and navigation

## Core Spatial Features

### Bill List in 3D Window Arrangement
Bills are presented as a vertical scrollable window anchored in the user's space.
Cards show due date, amount, and payee. The user can reposition the window by dragging
its title bar, resize it with the share grip, or collapse it to a small billboard.

### Immersive Spending Overview
An optional full-space mode renders the monthly spending chart as a volumetric
bar chart floating in front of the user. Categories are color-coded and heights
represent relative spend. The user can rotate and inspect from any angle.

### Gesture-Based Interactions
- **Gaze + pinch:** Open a bill detail window
- **Hand tracking:** Scroll through bill lists
- **Voice:** "Show bills due this week" / "Remind me to pay [bill]"
- **Eye tracking:** Highlight and focus elements for subtle UI reveals

## Tech Stack

- **SwiftUI** — Declarative UI framework with visionOS extensions
- **RealityKit** — 3D entity rendering, environment anchoring
- **AppKit / RealityKit blends** — For any custom space-filling components
- **CloudKit** — Same sync container as iOS/macOS for data access

## Design Language

Follows Apple's visionOS design principles (layers, depth, blur materials) while
maintaining Chronicle's salmon accent (`#FF6B4A`) for interactive and priority elements.

## Current Status

Early scaffold. SwiftUI entry points exist; RealityKit 3D components are stubs.

## Project Structure

```
ChronicleVision/
├── ChronicleVisionApp.swift   # @main app entry
├── ContentView.swift          # Main SwiftUI window
├── BillSpatialView.swift      # 3D bill list arrangement
└── SpendingChartView.swift    # Immersive spending chart
```
