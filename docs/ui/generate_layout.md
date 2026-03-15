# Permy Generate Screen Layout (SSOT)

## Purpose

The Generate screen exists to allow the user to **generate a message as
quickly and confidently as possible**.

The user should understand the next action within **3 seconds**.

Primary goal: - Make the **Generate button** obvious and easy to press.

This screen is **not a configuration screen**. It is an **action
screen**.

------------------------------------------------------------------------

# Core UX Principle

Generate screen = **Press screen**, not **Settings screen**.

The interface should encourage users to press the main CTA quickly,
without reading excessive information.

Design priorities:

1.  CTA visibility
2.  Clear information hierarchy
3.  Low cognitive load
4.  Minimal configuration friction

------------------------------------------------------------------------

# Screen Structure

The screen is composed of **four blocks only**.

1.  Persona Information
2.  Generation Settings
3.  Generate Button (Primary CTA)
4.  Generated Result Area

No additional major blocks should be introduced without UX review.

------------------------------------------------------------------------

# Layout Order

Top → Bottom

1.  Persona Information
2.  Generation Settings
3.  Generate Button
4.  Generated Result

This order follows the natural user mental flow:

Current Persona → Generation Method → Execute → See Result

------------------------------------------------------------------------

# Persona Information Block

Purpose: Show the user **which persona is currently active**.

Content example: - True Self Type - Night Self Type

Design rules: - Compact height - Avoid large descriptions - Show only
essential identity information

------------------------------------------------------------------------

# Generation Settings Block

Purpose: Allow quick adjustment of generation style.

Rules: - Maximum **2--3 options** - No long explanation text - Controls
must be immediately understandable

Example: - Generation Strategy - Tone control

Avoid: - Complex forms - Nested settings

------------------------------------------------------------------------

# Primary CTA (Generate Button)

This is the **most important element on the screen**.

Rules:

-   Only **one primary CTA**
-   Must visually dominate the screen
-   Should be reachable with the user's thumb
-   Placed in the **middle to lower area** of the screen

Spacing around the button should be larger than surrounding elements.

------------------------------------------------------------------------

# Generated Result Area

This area displays the output message.

The result area should exist **even before generation** to establish
spatial awareness.

States:

1.  Empty state
2.  Generating state
3.  Generated result

Design goals:

-   High readability
-   Clear message boundaries
-   Easy copy/share actions

This block should occupy the **largest vertical area** of the screen.

------------------------------------------------------------------------

# Visual Hierarchy Rules

Priority order:

1.  Generate Button
2.  Generated Result
3.  Generation Settings
4.  Persona Information

Users should visually locate the CTA first.

------------------------------------------------------------------------

# Information Density Rules

To reduce cognitive load:

-   Maximum **4 UI blocks**
-   Maximum **3 decisions**
-   Minimize explanatory text
-   Prefer whitespace over decoration

------------------------------------------------------------------------

# Design System Enforcement

All UI must follow the Permy Design System.

Required components:

-   AppScaffold
-   AppSectionHeader
-   AppButton
-   AppSpacing
-   AppRadius
-   AppTextStyles
-   AppColors

Forbidden:

-   Hard-coded colors
-   Hard-coded spacing
-   Direct BorderRadius values
-   Direct TextStyle definitions

------------------------------------------------------------------------

# Implementation Goal

The Generate screen should feel:

-   Immediate
-   Clear
-   Lightweight
-   Action‑focused

The user should instinctively press **Generate** without hesitation.
