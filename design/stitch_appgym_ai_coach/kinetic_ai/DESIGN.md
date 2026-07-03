---
name: Kinetic AI
colors:
  surface: '#131319'
  surface-dim: '#131319'
  surface-bright: '#39383f'
  surface-container-lowest: '#0e0e14'
  surface-container-low: '#1b1b21'
  surface-container: '#1f1f25'
  surface-container-high: '#2a2930'
  surface-container-highest: '#34343b'
  on-surface: '#e4e1ea'
  on-surface-variant: '#c8c4d7'
  inverse-surface: '#e4e1ea'
  inverse-on-surface: '#303036'
  outline: '#928ea0'
  outline-variant: '#474554'
  surface-tint: '#c6bfff'
  primary: '#c6bfff'
  on-primary: '#2900a0'
  primary-container: '#6c5ce7'
  on-primary-container: '#faf6ff'
  inverse-primary: '#5847d2'
  secondary: '#44f5bd'
  on-secondary: '#003828'
  secondary-container: '#00d8a2'
  on-secondary-container: '#005840'
  tertiary: '#8aceff'
  on-tertiary: '#00344e'
  tertiary-container: '#0079ae'
  on-tertiary-container: '#f4f8ff'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e4dfff'
  primary-fixed-dim: '#c6bfff'
  on-primary-fixed: '#160066'
  on-primary-fixed-variant: '#4029ba'
  secondary-fixed: '#50fec5'
  secondary-fixed-dim: '#1fe0aa'
  on-secondary-fixed: '#002116'
  on-secondary-fixed-variant: '#00513b'
  tertiary-fixed: '#c9e6ff'
  tertiary-fixed-dim: '#8aceff'
  on-tertiary-fixed: '#001e2f'
  on-tertiary-fixed-variant: '#004b6f'
  background: '#131319'
  on-background: '#e4e1ea'
  surface-variant: '#34343b'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 57px
    fontWeight: '700'
    lineHeight: 64px
    letterSpacing: -0.25px
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  title-lg:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.5px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.25px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 16px
  margin-tablet: 24px
  margin-desktop: 48px
---

## Brand & Style

The design system is engineered for a high-performance, AI-driven fitness environment. It balances the high-energy aesthetics of modern athletics with the systematic precision of developer-centric tools. The personality is motivational yet analytical, designed to reduce cognitive load during intense physical activity.

The visual style follows a **Modern / Material 3** hybrid approach:
- **Dark-First:** A deep, obsidian-based interface that minimizes eye strain and emphasizes vibrant data visualizations.
- **Clean Kineticism:** High-contrast accents (Violet and Mint) are used to draw attention to progress and primary actions.
- **Systematic Precision:** Utilitarian typography and structured layouts ensure that complex workout data remains legible at a glance.
- **Subtle Depth:** Use of tonal overlays rather than heavy shadows to maintain a sleek, digital-forward feel.

## Colors

This design system utilizes a high-contrast palette optimized for dark environments. The **Primary Violet** (#6C5CE7) represents brand identity and core interactions, while **Secondary Mint** (#00D9A3) is reserved for "success" states, completions, and positive growth metrics.

The color system includes a specific sub-palette for **Muscle Group Mapping**. These colors should be used consistently across anatomical diagrams, workout tags, and volume distribution charts to provide immediate visual feedback on training split focus.

In dark mode, surfaces use tonal elevation—adding opacity layers of the primary color or white to the base surface (#1C1C26) to indicate hierarchy.

## Typography

The design system adopts a strict **Inter** typeface implementation for its neutral, geometric qualities and exceptional legibility at small sizes.

- **Display & Headlines:** Used for heavy data points (e.g., total weight lifted) and screen titles. Use bold or semi-bold weights to create a sense of strength.
- **Body:** Optimized for workout instructions and AI insights. Line height is generous to ensure readability during movement.
- **Labels:** Used for metadata, muscle group tags, and button text. All-caps is permitted only for short labels or "Overline" styles to add variety without breaking the typeface system.

## Layout & Spacing

This design system uses an **8px linear grid system** to ensure vertical rhythm. 

- **Grid:** A 4-column fluid grid for mobile and a 12-column grid for desktop.
- **Safe Areas:** Maintain a minimum 16px horizontal margin on mobile devices to prevent content from touching the screen edges.
- **Rhythm:** Use `md` (16px) for standard gaps between elements in a list, and `lg` (24px) for spacing between logical sections or different card groups.
- **Touch Targets:** No interactive element should be smaller than 48x48px, even if the visual representation is smaller.

## Elevation & Depth

Elevation in this design system is primarily expressed through **Tonal Layering** rather than traditional drop shadows, following Material 3 principles.

- **Level 0 (Background):** Base color (#121218). Used for the main canvas.
- **Level 1 (Cards/Surfaces):** Surface color (#1C1C26). Used for the primary container of content.
- **Level 2 (Active/Hover):** A 5% Primary color overlay on top of the Surface color.
- **App Bar:** Remains at Level 0 with no elevation or shadow. On scroll, it may transition to Level 1 with a subtle background blur (backdrop-filter) to maintain content separation.
- **Shadows:** Only used for floating action buttons (FAB) or transient elements like menus. Use a soft, 15% opacity shadow with a large blur radius (16px) and 0px offset.

## Shapes

The shape language is "Rounded" to convey an approachable and modern feel.

- **Cards:** Fixed at 16px (`rounded-lg`) to create a distinct containerized look for workout modules.
- **Input Fields:** Fixed at 12px to differentiate them slightly from the larger card containers.
- **Buttons:** Fully rounded (Pill) for primary actions to maximize tap-friendliness, or 12px for secondary/ghost buttons.
- **Chips:** Always pill-shaped (half-height radius) for categorizing muscle groups or equipment.

## Components

### Buttons
- **Primary:** Solid Violet background, White text. High emphasis.
- **Secondary:** Solid Surface color with Mint text or a subtle Mint stroke.
- **Tertiary:** Transparent background with Violet or Mint text.

### Cards
- **Structure:** 16px corner radius. No border. Surface color background.
- **Padding:** Internal padding of 16px or 20px depending on content density.
- **Interaction:** Use a subtle scale-down effect (0.98) on press to provide tactile feedback.

### Inputs
- **Style:** Filled with #252533 (slightly lighter than surface), no visible border. 12px corner radius.
- **States:** On focus, the bottom 2px of the input should animate a Violet underline or a thin Violet halo.

### App Bar
- **Design:** Transparent or Background-colored, centerTitle: false. Use Headline-lg or Title-lg for the title font.
- **Icons:** 24px icon size with 12px padding for touch targets.

### Bottom Navigation
- **Structure:** 5 sections (e.g., Home, Workouts, AI Coach, Progress, Profile).
- **Style:** Surface color background with no shadow. Use active-indicator pill (a subtle background shape behind the active icon) per Material 3 guidelines.

### Progress Bars & Rings
- **Implementation:** Use Mint for completion and Violet for current "in-progress" sets. Background tracks should be a low-opacity version of the color or the Surface color.