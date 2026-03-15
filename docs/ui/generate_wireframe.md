# Permy Generate Wireframe (SSOT)

## Purpose
The Generate screen is not a settings screen.
It is an action screen whose goal is to let the user press **Generate** quickly and confidently.

The screen should guide the user through a single natural flow:

1. Understand current persona
2. Confirm minimal generation settings
3. Press Generate
4. Review generated results

---

## Wireframe Structure

```text
┌────────────────────────────┐
│ Top Brand Header           │
├────────────────────────────┤
│ Persona Summary            │
│ True Self / Night Self     │
│ Compact current state      │
├────────────────────────────┤
│ Generation Settings        │
│ Minimal selectable options │
├────────────────────────────┤
│                            │
│       [ Generate ]         │
│                            │
├────────────────────────────┤
│ Generated Result Area      │
│ Empty / Loading / A/B/C    │
│ Copy actions               │
└────────────────────────────┘
```

---

## Block 1: Persona Summary

### Purpose
Show the user's current persona state at a glance.

### Content
- True Self Type
- Night Self Type

### Rules
- Keep compact
- Avoid long descriptions
- Do not make this area the main focus
- Optional detail navigation is allowed, but must not compete with the primary CTA

---

## Block 2: Generation Settings

### Purpose
Allow quick adjustment before generation.

### Rules
- Maximum 2–3 controls
- Short, immediately understandable labels
- No long explanation text
- No nested settings
- No complex form layout

### Design intent
This block should feel lightweight and quick to scan.

---

## Block 3: Primary CTA

### Purpose
This is the most important action on the screen.

### Rules
- Only one primary CTA
- Must be the most visually prominent element
- Must be separated from surrounding blocks with larger whitespace
- Must not be visually grouped with secondary actions
- Prefer placement in the middle to lower area of the screen

### Forbidden
- Placing reset/save/detail actions next to the primary CTA
- Making secondary buttons visually similar in weight

---

## Block 4: Generated Result Area

### Purpose
Display the generated content clearly and consistently.

### States
1. Empty state
2. Loading state
3. Generated state

### Rules
- This block should occupy the largest vertical area
- The location of the result must be obvious even before generation
- A/B/C results must be easy to compare
- Copy actions must be easy to discover
- Prioritize readability over decoration

---

## Visual Priority

The user should visually notice the following in order:

1. Generate Button
2. Result Area
3. Generation Settings
4. Persona Summary

---

## Density Rules

- Keep the screen low to medium density
- Avoid excessive explanatory text
- Prefer whitespace over decorative elements
- Keep the upper half of the screen light and fast to scan
- Use the lower half primarily for action and results

---

## UX Principle

The Generate screen should feel:

- Immediate
- Simple
- Action-first
- Low-friction

The user should not feel like they are configuring a system.
They should feel like they are about to get a result quickly.

---

## Enforcement

This wireframe must be implemented with the Permy Design System.

Required:
- AppScaffold
- AppSectionHeader
- AppButton
- AppSpacing
- AppRadius
- AppTextStyles
- AppColors

Forbidden:
- Hard-coded colors
- Hard-coded spacing
- Direct BorderRadius values
- Direct TextStyle definitions
