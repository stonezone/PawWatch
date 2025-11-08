UI/UX Strategy Overview

  Navigation Structure

  Horizontal Swipe Navigation (PageTabView):
  ┌─────────────────────────────────────────────────────┐
  │  [History] ← [Map View] → [Stats] → [Settings]     │
  │     (1)        (Home)       (3)        (4)          │
  └─────────────────────────────────────────────────────┘

  Primary Navigation: Swipe gestures between 4 main screens
  Modal Overlays: Onboarding, Pet Setup, Alerts, Watch Pairing

  Design System

  - Style: iOS 26 Liquid Glass aesthetic
  - Colors: Tropical ocean (turquoise #40E0D0, teal #008080, coral #FF6F61, ocean blue #0077BE)
  - Typography: SF Pro Rounded (playful pet theme)
  - Materials: Frosted glass, depth layering, soft shadows
  - Animations: Fluid, organic motion (120fps ProMotion)

  ---
  Screen 1: Onboarding Welcome (First Launch)

  Purpose: Introduce app concept and create excitement
  Duration: 3 screens (swipe through)

  DALL-E Prompt - Onboarding Screen 1/3

  iOS 26 mobile app onboarding screen for PetTracker pet GPS app, liquid glass aesthetic, iPhone 16 Pro Max dimensions (1290x2796px).

  Header: Large playful macaw illustration (matching app icon style) at top third of screen, tropical ocean gradient background (turquoise to ocean blue), glassmorphic card overlay with frosted blur
  effect.

  Main content card: Semi-transparent white glass card (20% opacity, 40px blur) centered on screen, containing:
  - Title: "Track Your Pet Anywhere" in SF Pro Rounded Bold, 34pt, white text with subtle shadow
  - Subtitle: "Transform your Apple Watch into a real-time GPS tracker for your pet" in SF Pro, 17pt, white 80% opacity
  - Illustrated icon: Simple Apple Watch with pet collar graphic below text
  - Visual hierarchy with generous whitespace

  Bottom section: Rounded "Continue" button in coral (#FF6F61) with slight elevation shadow, white text. Small page indicator dots below (1 of 3 active).

  Style: Modern iOS 26 liquid glass design, depth and layering, soft glow effects, clean minimalist, tropical ocean color palette, friendly and trustworthy mood, high-quality UI/UX design, mobile app
  interface

  DALL-E Prompt - Onboarding Screen 2/3 (Permissions)

  iOS 26 permissions request screen for PetTracker, liquid glass design, iPhone interface.

  Background: Soft tropical ocean gradient (turquoise to teal), subtle animated wave pattern.

  Main content: Large frosted glass card with three permission sections stacked vertically:

  1. Location permission card:
     - Icon: Blue location pin in glassmorphic circle
     - Title: "Location Access" (SF Pro Bold, 20pt)
     - Description: "Track your pet's real-time GPS location" (SF Pro, 15pt, 70% opacity)
     - Status badge: "Required" in small pill shape

  2. HealthKit permission card:
     - Icon: Red heart in glassmorphic circle
     - Title: "HealthKit Access" (SF Pro Bold, 20pt)
     - Description: "Extended GPS runtime via workout sessions" (SF Pro, 15pt, 70% opacity)
     - Status badge: "Required"

  3. Bluetooth permission card:
     - Icon: Blue wireless waves in glassmorphic circle
     - Title: "Bluetooth & Watch" (SF Pro Bold, 20pt)
     - Description: "Connect to your Apple Watch" (SF Pro, 15pt, 70% opacity)
     - Status badge: "Required"

  Bottom: Large coral "Grant Permissions" button, page indicator (2 of 3).

  Style: iOS 26 liquid glass aesthetic, layered depth, soft shadows, clean spacing, tropical colors, modern mobile UI

  DALL-E Prompt - Onboarding Screen 3/3 (Setup Complete)

  iOS 26 onboarding completion screen for PetTracker, celebration design, liquid glass aesthetic.

  Background: Vibrant tropical ocean gradient with subtle confetti particle effect.

  Center content: Large success checkmark in glassmorphic circle (turquoise gradient), pulsing glow animation implied.

  Glass card below checkmark:
  - Title: "You're All Set!" (SF Pro Rounded Bold, 32pt, white)
  - Subtitle: "Attach your Apple Watch to your pet's collar to start tracking" (SF Pro, 17pt, white 80%)
  - Small illustrated diagram: Apple Watch on collar graphic

  Visual element: Macaw silhouette watermark in background (subtle, 10% opacity)

  Bottom section:
  - Primary button: "Pair Apple Watch" (coral, prominent)
  - Secondary button: "Skip for Now" (white outline, transparent)
  - Page indicator (3 of 3 filled)

  Style: Celebratory, friendly, iOS 26 liquid glass, tropical ocean colors, clean modern mobile UI, high-end design

  ---
  Screen 2: Main Map View (Home Screen)

  Purpose: Primary tracking interface - live pet location visualization
  Key Elements: Map, markers, distance overlay, controls

  DALL-E Prompt - Main Map View

  iOS 26 main screen for PetTracker pet GPS app, liquid glass design, iPhone 16 Pro Max interface.

  Full-screen map background: Apple Maps style showing outdoor park area with green spaces, trails visible. Map fills entire screen edge-to-edge.

  Pet location marker: Large custom marker with macaw icon (tropical colors), pulsing location ring animation implied, positioned upper-left quadrant of map.

  Owner location marker: Standard blue dot with accuracy circle, positioned lower-right quadrant of map.

  Dashed line: Connecting pet to owner markers showing distance relationship.

  Top overlay (glassmorphic pill bar):
  - Frosted glass bar spanning width with rounded corners (60px height)
  - Left: Connection status indicator (green dot + "Connected")
  - Center: "PetTracker" title or pet name
  - Right: Watch battery icon "78%" in ocean blue

  Middle-right floating card (glassmorphic):
  - Vertical card showing live distance: "47.2 m" in large bold text
  - Subtext: "Distance"
  - GPS accuracy indicator: "±5m" in small text
  - Frosted white glass with 30% opacity, subtle blur

  Bottom control section (glassmorphic dock):
  - Wide frosted glass bar (100px height) anchored to bottom with rounded top corners
  - Three icon buttons horizontally centered:
    1. History icon (calendar/clock)
    2. Center "Stop Tracking" button (coral, prominent, slightly elevated)
    3. Settings icon (gear)
  - Live update timestamp: "Updated 2s ago" in small text at very bottom

  Style: iOS 26 liquid glass aesthetic, tropical ocean accent colors (turquoise, coral, teal), depth and layering, soft shadows, clean modern interface, professional GPS tracking app, spatial design,
  ultra-realistic mobile UI mockup

  ---
  Screen 3: Pet Profile Setup

  Purpose: Configure pet information and Watch pairing
  Key Elements: Pet photo, name, collar setup instructions

  DALL-E Prompt - Pet Profile Setup

  iOS 26 pet profile setup screen for PetTracker, liquid glass design, iPhone interface.

  Header section (glassmorphic):
  - Back button (< Profile) top-left
  - Title "Pet Profile" centered, SF Pro Rounded Semibold 20pt
  - "Save" button top-right in coral

  Main content (scrollable):

  1. Pet photo section (top):
  - Large circular photo placeholder (150px diameter) with dashed border
  - Camera icon overlay "Add Photo"
  - Glassmorphic card background, centered

  2. Pet information card (glassmorphic):
  - Text field: "Pet Name" with placeholder "e.g., Rio the Macaw"
  - Picker: "Pet Type" showing Macaw/Parrot icon selected
  - Frosted glass input fields with subtle borders

  3. Apple Watch selection card:
  - Title: "Select Apple Watch" (SF Pro Bold, 18pt)
  - Card showing Apple Watch Ultra 2 with "Connected" green status badge
  - Device name: "Zack's Watch"
  - Battery level: 85% with icon
  - Glassmorphic card with watch illustration

  4. Collar attachment guide card:
  - Title: "Collar Setup" with info icon
  - Small illustrated diagram: Watch attached to collar securely
  - Bullet points:
    • "Attach Watch to collar with band"
    • "Ensure GPS sensor faces upward"
    • "Test fit before releasing pet"
  - Expandable glassmorphic card

  Background: Soft tropical gradient (top to bottom: turquoise fade to white), subtle pattern.

  Bottom: Large coral "Start Tracking" button, floating above bottom edge.

  Style: iOS 26 liquid glass, tropical ocean colors, clean form design, friendly and instructional, modern mobile UI, high-quality

  ---
  Screen 4: History/Trail View

  Purpose: View past tracking sessions and trail visualizations
  Key Elements: Session list, trail maps, date filters

  DALL-E Prompt - History/Trail View

  iOS 26 history screen for PetTracker, liquid glass design, iPhone interface.

  Top navigation bar (glassmorphic):
  - Title: "Tracking History" centered, SF Pro Rounded Semibold 20pt
  - Filter button (funnel icon) top-right
  - Frosted glass bar with blur

  Date filter pills (horizontal scroll):
  - Row of glassmorphic pill buttons: "Today", "This Week", "This Month", "All Time"
  - "Today" selected (coral background), others transparent with border
  - Below nav bar, scrollable

  Main content (scrollable list of session cards):

  Session card 1 (glassmorphic, prominent):
  - Small map thumbnail showing trail path (turquoise line) on left side (80x80px)
  - Right side info:
    - Title: "Morning Walk" (SF Pro Semibold, 17pt)
    - Date/time: "Today, 8:42 AM - 9:28 AM"
    - Stats row: "2.4 km" with distance icon, "46 min" with clock icon
    - Battery used: "Watch: 78% → 65%" in small text
  - Subtle shadow, rounded corners, frosted glass

  Session card 2:
  - Similar layout
  - Map showing different trail pattern
  - "Yesterday, 3:15 PM - 4:02 PM"
  - "1.8 km • 47 min"

  Session card 3:
  - "Nov 5, 11:20 AM - 12:10 PM"
  - "3.1 km • 50 min"

  Cards stacked vertically with spacing, each with slight depth.

  Bottom floating button:
  - Coral "+ New Session" button, glassmorphic with elevation

  Background: Tropical gradient (subtle), clean white base.

  Style: iOS 26 liquid glass design, tropical ocean accent colors, list interface with depth, clean data presentation, modern mobile UI

  DALL-E Prompt - Trail Detail View (Modal)

  iOS 26 trail detail modal for PetTracker, liquid glass design, full-screen overlay.

  Header (glassmorphic bar):
  - Close button (X) top-left
  - Title: "Morning Walk" centered
  - Share button (export icon) top-right
  - Date subtitle: "Nov 7, 2025 • 8:42 AM"

  Full map view:
  - Detailed trail path in turquoise gradient (thick line, 4px)
  - Start marker: Green pin with "Start" label
  - End marker: Red pin with "End" label
  - Multiple pet location dots along path
  - Map fills 60% of screen

  Bottom stats panel (large glassmorphic card):
  - Rounded top corners, frosted glass with blur
  - Grid of 6 stat tiles (2 rows x 3 columns):

  Row 1:
    - Duration: "46 min" with clock icon
    - Distance: "2.4 km" with ruler icon
    - Avg Speed: "3.1 km/h" with speedometer icon

  Row 2:
    - GPS Points: "152 fixes" with location icon
    - Battery Used: "13%" with battery icon
    - Accuracy: "±8m avg" with target icon

  - Each stat in small glassmorphic sub-card with icon and value

  Bottom action buttons:
  - "Export GPX" button (outline, coral border)
  - "Delete Session" button (text only, gray)

  Background: Darkened overlay with blur (60% opacity) behind modal.

  Style: iOS 26 liquid glass, tropical ocean colors, detailed stats dashboard, modern modal design, spatial depth

  ---
  Screen 5: Live Stats Dashboard

  Purpose: Real-time tracking metrics and GPS quality indicators
  Key Elements: Large distance display, live stats, connection quality

  DALL-E Prompt - Live Stats Dashboard

  iOS 26 live stats dashboard for PetTracker, liquid glass design, iPhone interface.

  Top section (large hero card - glassmorphic):
  - Massive distance number: "47.2" in extra-large SF Pro Rounded (72pt), white
  - Unit label: "meters" below in smaller text
  - Subtitle: "Distance from your pet" (15pt, 70% opacity)
  - Pulsing animation implied with subtle glow
  - Gradient background (turquoise to ocean blue) within card
  - Takes up top 40% of screen

  Live stats grid (4 glassmorphic cards in 2x2 grid):

  Card 1 (top-left):
  - Icon: Green signal waves
  - Label: "Update Rate"
  - Value: "0.8 Hz"
  - Subtext: "Real-time"

  Card 2 (top-right):
  - Icon: Target crosshair (turquoise)
  - Label: "GPS Accuracy"
  - Value: "±5m"
  - Subtext: "Excellent"

  Card 3 (bottom-left):
  - Icon: Battery icon (ocean blue)
  - Label: "Watch Battery"
  - Value: "78%"
  - Subtext: "~6h remaining"
  - Progress bar below value

  Card 4 (bottom-right):
  - Icon: Bluetooth waves (green)
  - Label: "Connection"
  - Value: "Strong"
  - Subtext: "54ms latency"

  Each card: Frosted glass with 25% opacity, rounded corners, subtle shadows, generous padding.

  Bottom section (connection timeline - glassmorphic card):
  - Title: "Connection Quality (Last 5 min)"
  - Simple line graph showing signal strength over time (turquoise line)
  - Y-axis: Signal strength, X-axis: Time
  - Smooth curve, minimal design

  Background: Soft tropical gradient.

  Style: iOS 26 liquid glass aesthetic, tropical ocean colors, data visualization, real-time dashboard, clean modern mobile UI, high contrast, readable

  ---
  Screen 6: Settings Screen

  Purpose: App configuration and preferences
  Key Elements: Settings groups, toggles, navigation

  DALL-E Prompt - Settings Screen

  iOS 26 settings screen for PetTracker, liquid glass design, iPhone interface.

  Header (glassmorphic bar):
  - Back button (< Back) top-left
  - Title: "Settings" centered, SF Pro Rounded Semibold 20pt
  - Done button top-right

  Scrollable content (grouped list with glassmorphic cards):

  Section 1: "Pet Profile"
  - Glass card with pet thumbnail (circular, 50px) + "Rio the Macaw" + chevron right
  - Tappable row

  Section 2: "Units & Display"
  Glass card containing:
  - Row 1: "Distance Units" | "Metric" with chevron
  - Divider line
  - Row 2: "Temperature" | "Celsius" with chevron
  - Divider
  - Row 3: "Map Type" | "Standard" with chevron

  Section 3: "Alerts & Notifications"
  Glass card containing:
  - Row 1: "Distance Alerts" | Toggle switch (ON, coral color)
  - Subtext: "Alert when pet exceeds 100m"
  - Divider
  - Row 2: "Battery Alerts" | Toggle switch (ON, coral)
  - Subtext: "Notify at 20% Watch battery"
  - Divider
  - Row 3: "Connection Alerts" | Toggle switch (ON, coral)

  Section 4: "Watch"
  Glass card:
  - Row: "Zack's Apple Watch Ultra" with Watch icon | "Connected" green badge | chevron

  Section 5: "Privacy & Data"
  Glass card:
  - Row 1: "Location Permissions" | "Always" with chevron
  - Divider
  - Row 2: "Data Storage" | "On Device Only" info icon

  Section 6: "About"
  Glass card:
  - Row 1: "App Version" | "1.0.0" gray text
  - Divider
  - Row 2: "Licenses" | chevron
  - Divider
  - Row 3: "Contact Support" | chevron

  Each section has header label in uppercase small text, gray color.

  Background: Soft white to light turquoise gradient.

  Style: iOS 26 liquid glass, Settings app style, grouped list design, tropical accent colors, clean modern iOS UI

  ---
  Screen 7: Alert Configuration (Modal)

  Purpose: Configure distance and battery alert thresholds
  Key Elements: Sliders, previews, test alerts

  DALL-E Prompt - Alert Configuration Modal

  iOS 26 alert configuration modal for PetTracker, liquid glass design, sheet presentation.

  Modal header (glassmorphic):
  - Drag handle at top center (gray pill)
  - Title: "Alert Settings" centered, SF Pro Semibold 24pt
  - "Done" button top-right (coral)

  Main content (scrollable):

  Distance Alert Card (glassmorphic):
  - Title: "Distance Alert" with bell icon
  - Toggle switch (ON, coral) at right
  - Slider control:
    - Label: "Alert when distance exceeds:"
    - Slider (coral thumb) with min 25m, max 500m
    - Current value display: "100 meters" in large text centered
    - Visual indicator: Circular preview showing pet/owner dots with 100m radius circle
  - "Test Alert" button (outline, small)

  Battery Alert Card (glassmorphic):
  - Title: "Low Battery Alert" with battery icon
  - Toggle ON
  - Picker/Slider:
    - Label: "Notify when Watch battery reaches:"
    - Segmented control: 30%, 20%, 10%
    - 20% selected (coral)
  - Preview: Battery icon at 20% with notification badge

  Connection Alert Card (glassmorphic):
  - Title: "Connection Lost Alert" with wifi-slash icon
  - Toggle ON
  - Description: "Receive notification if Watch connection is lost for more than 2 minutes"
  - "Test Alert" button

  Each card: Frosted glass with shadow, rounded corners, generous padding, stacked vertically.

  Example notification preview (small card at bottom):
  - Shows iOS notification banner mockup
  - "PetTracker: Rio is 105m away!"
  - With macaw app icon

  Background: Blurred app content behind modal (60% opacity).

  Style: iOS 26 liquid glass design, modal sheet presentation, tropical colors, interactive controls, modern mobile UI

  ---
  Screen 8: Watch Pairing/Connection Status

  Purpose: Manage Watch connection and troubleshoot issues
  Key Elements: Pairing flow, status indicators, troubleshooting

  DALL-E Prompt - Watch Connection Screen

  iOS 26 Watch connection screen for PetTracker, liquid glass design, iPhone interface.

  Header (glassmorphic):
  - Back button (< Settings)
  - Title: "Apple Watch" centered
  - Info button (i icon) top-right

  Watch status card (large glassmorphic, prominent):
  - Large Apple Watch Ultra illustration centered (3D render style)
  - Glowing blue connection ring around watch (animated pulse implied)
  - Status badge: "Connected" with green dot
  - Watch name below: "Zack's Apple Watch Ultra"
  - Model: "49mm • watchOS 26.0"

  Connection details card (glassmorphic):
  - Grid of connection stats (2x2):

    Top-left:
    - Icon: Bluetooth waves (green)
    - Label: "Connection Type"
    - Value: "Bluetooth"

    Top-right:
    - Icon: Signal strength bars
    - Label: "Signal Strength"
    - Value: "Strong (-45 dBm)"

    Bottom-left:
    - Icon: Speedometer
    - Label: "Latency"
    - Value: "54ms"

    Bottom-right:
    - Icon: Clock with arrow
    - Label: "Last Sync"
    - Value: "2 sec ago"

  Active messaging paths card (glassmorphic):
  - Title: "Active Channels" with info icon
  - Three rows with status indicators:
    1. "Application Context" | Green checkmark | "2 Hz"
    2. "Interactive Messages" | Green checkmark | "Active"
    3. "File Transfer" | Orange dot | "Queue: 0"

  Actions section (glassmorphic card):
  - Button: "Reconnect Watch" (outline, coral border)
  - Button: "Forget This Watch" (text only, red, destructive)

  Troubleshooting link (bottom):
  - "Connection Issues?" with chevron (small text, gray)

  Background: Soft tropical gradient.

  Style: iOS 26 liquid glass, technical status display, tropical accents, modern device management UI, high-quality

  ---
  Screen 9: Empty State (No Watch Connected)

  Purpose: Onboard users to pair their Watch
  Key Elements: Instructions, pairing button, illustration

  DALL-E Prompt - Empty State

  iOS 26 empty state screen for PetTracker when no Watch connected, liquid glass design, iPhone interface.

  Center content (vertically and horizontally centered):

  Large illustration:
  - Apple Watch with question mark overlay (grayscale, subtle)
  - Floating above glassmorphic card
  - Size: 200x200px

  Main card (large glassmorphic):
  - Title: "No Apple Watch Found" (SF Pro Rounded Bold, 28pt, centered)
  - Subtitle: "Connect your Apple Watch to start tracking your pet's location" (SF Pro, 17pt, gray, centered, multi-line)
  - Generous padding

  Steps card (glassmorphic, below main card):
  - Small numbered list:
    1. "Make sure your Apple Watch is paired with this iPhone"
    2. "Enable Bluetooth on both devices"
    3. "Open the Watch app to verify pairing"
  - Clean typography, left-aligned, icons for each step

  Action buttons (stacked):
  - Primary: "Pair Apple Watch" (coral, large, prominent)
  - Secondary: "Open Watch App" (outline, white with border)
  - Tertiary: "Continue Without Watch" (text only, small, gray)

  Background: Tropical ocean gradient (subtle), clean white base.

  Subtle macaw watermark in background (5% opacity).

  Style: iOS 26 liquid glass aesthetic, empty state design, friendly and instructional, tropical colors, modern mobile UI, centered layout

  ---
  Screen 10: Live Activity (Lock Screen Widget)

  Purpose: Show tracking status on lock screen during active session
  Key Elements: Compact stats, map preview, controls

  DALL-E Prompt - Live Activity Lock Screen

  iOS 26 Lock Screen Live Activity for PetTracker, liquid glass design, iPhone 16 Pro Max lock screen.

  Lock screen context:
  - Time: 3:42 PM at top (large)
  - Date: Wednesday, November 7 below time
  - Wallpaper: Blurred tropical beach scene

  Live Activity widget (expanded):
  - Glassmorphic pill-shaped widget spanning width
  - Left section:
    - Small macaw app icon (circular, 40px)
    - Text: "Tracking Rio" (bold, white)
    - Subtext: "Active for 24 min" (small, 70% opacity)

  - Center section:
    - Large distance number: "47 m" (prominent, white)
    - Small map preview thumbnail showing pet location (60x60px, rounded)

  - Right section:
    - Watch battery: 78% with icon
    - GPS accuracy: "±5m" with icon
    - Connection: Green dot

  Bottom bar (interactive controls):
  - Two buttons side-by-side:
    - "View Map" (left, coral accent)
    - "Stop" (right, gray outline)

  Frosted glass background with blur, dark mode adapted, soft glow.

  Dynamic Island (top):
  - Compact: Macaw icon + "47m" live updating

  Style: iOS 26 Live Activity design, lock screen widget, liquid glass material, tropical accents, dark mode compatible, real-time updates, modern iOS UI

  ---
  Screen 11: Dynamic Island (Active Tracking)

  Purpose: Show compact tracking info in Dynamic Island
  Key Elements: Distance, connection status, tap to expand

  DALL-E Prompt - Dynamic Island States

  iOS 26 Dynamic Island mockup for PetTracker, three states shown on black iPhone 16 Pro background.

  State 1 - Compact (minimal):
  - Dynamic Island pill shape
  - Left: Small macaw icon (circular, animated pulse)
  - Right: "47m" in white text
  - Size: Standard compact Dynamic Island dimensions

  State 2 - Expanded (tapped):
  - Larger rounded rectangle expanding from island
  - Top section:
    - Macaw icon left, "Tracking Rio" title
    - Live distance: "47.2 meters" (large, center)
    - Connection status: Green dot "Connected"
  - Bottom section:
    - Mini map preview showing pet location (120x80px)
    - Update timestamp: "Updated 2s ago"
  - Background: Dark glassmorphic material with blur

  State 3 - Long-press menu:
  - Context menu floating above island
  - Options:
    - "View Full Map" with map icon
    - "Stop Tracking" with stop icon (red)
    - "Mute Alerts" with bell-slash icon
  - iOS context menu style, glassmorphic

  All three states shown in sequence on same image for comparison.

  Background: Pure black (#000000) iPhone screen, status bar visible.

  Style: iOS 26 Dynamic Island design, liquid glass materials, tropical color accents, real-time tracking indicator, modern iOS UI, high-fidelity mockup

  ---
  Design System Components

  DALL-E Prompt - Component Library

  iOS 26 UI component library sheet for PetTracker app, liquid glass design system.

  Grid layout showing reusable components:

  Row 1 - Buttons:
  - Primary button (coral #FF6F61, white text, rounded)
  - Secondary button (white outline, coral text, transparent)
  - Tertiary button (text only, gray)
  - Icon button (glassmorphic circle with icon)

  Row 2 - Cards:
  - Large card (frosted glass, 30% opacity, 40px blur, rounded corners)
  - Medium card (similar, smaller)
  - Stat card (icon + label + value layout)

  Row 3 - Inputs:
  - Text field (glassmorphic with subtle border)
  - Toggle switch (coral when ON, gray when OFF)
  - Slider (coral accent, white track)
  - Segmented control (coral selection)

  Row 4 - Indicators:
  - Status badge (green "Connected", red "Disconnected", orange "Searching")
  - Battery indicator (percentage + icon + progress bar)
  - Connection strength (signal bars)

  Row 5 - Navigation:
  - Top nav bar (frosted glass, title + buttons)
  - Bottom tab bar (glassmorphic with icons)
  - Back button (< chevron + label)

  Color palette swatches:
  - Turquoise #40E0D0
  - Teal #008080
  - Ocean Blue #0077BE
  - Coral #FF6F61
  - White with opacity levels (100%, 70%, 40%, 20%)

  Typography scale:
  - Title 1: SF Pro Rounded Bold 34pt
  - Title 2: SF Pro Rounded Semibold 24pt
  - Body: SF Pro 17pt
  - Caption: SF Pro 13pt

  Style: iOS 26 liquid glass design system, tropical ocean theme, component library sheet, design tokens, UI kit, high-quality design documentation

  ---
  Complete Navigation Flow Diagram

  DALL-E Prompt - App Flow Diagram

  iOS app navigation flow diagram for PetTracker, clean visual representation.

  Start node: "App Launch"
  ↓
  Decision: "First Launch?"
  ├─ Yes → Onboarding Flow (3 screens) → Pet Setup → Main Map
  └─ No → Main Map

  Main navigation (horizontal swipe):
  [History] ←→ [Map View] ←→ [Live Stats] ←→ [Settings]
      ↑            ↑              ↑              ↑
      │            │              │              │
      ↓            ↓              ↓              ↓
  Trail Detail  Alert Config  Watch Pairing   Pet Profile

  Lock screen integration:
  - Live Activity (always visible during tracking)
  - Dynamic Island (compact/expanded states)
  - Notifications (alerts trigger)

  Diagram style:
  - Nodes as rounded rectangles (glassmorphic style)
  - Arrows with labels
  - Color coding:
    - Primary screens (coral outline)
    - Modal overlays (turquoise outline)
    - System UI (gray outline)
  - Clean, minimal flowchart design
  - Tropical ocean color accents

  Background: White with subtle grid.

  Style: Professional UX flow diagram, clean design, app architecture visualization, modern UI/UX documentation

  ---
  Summary of Screens

  Production-Ready Screen Count: 11 Unique Screens

  1. ✅ Onboarding (3 slides) - Welcome, Permissions, Setup Complete
  2. ✅ Main Map View - Primary tracking interface (Home)
  3. ✅ Pet Profile Setup - Pet info, Watch selection, collar instructions
  4. ✅ History/Trail View - Session list with filters
  5. ✅ Trail Detail Modal - Full session stats and map
  6. ✅ Live Stats Dashboard - Real-time metrics
  7. ✅ Settings - App configuration
  8. ✅ Alert Configuration - Distance/battery/connection alerts
  9. ✅ Watch Connection Status - Pairing and troubleshooting
  10. ✅ Empty State - No Watch connected
  11. ✅ Live Activity + Dynamic Island - System-level tracking UI

  Bonus: Design System Component Library

  ---
  Implementation Notes

  SwiftUI Navigation Structure

  TabView {
      HistoryView()
      MapView() // Default
      StatsView()
      SettingsView()
  }
  .tabViewStyle(.page)
  .indexViewStyle(.page(backgroundDisplayMode: .never))

  iOS 26 Features to Implement

  - Liquid Glass Materials: .background(.ultraThinMaterial), custom blur effects
  - Live Activities: ActivityKit framework for lock screen widget
  - Dynamic Island: ActivityKit with DynamicIslandExpandedRegion
  - Fluid Animations: .animation(.smooth(duration: 0.5)) with spring curves
  - Haptics: UIImpactFeedbackGenerator for interactions
  - ProMotion: 120fps animations with .animation(.interpolatingSpring)

  ---
  Next Steps

  1. Generate Images: Use prompts with DALL-E 3, Midjourney, or Figma plugins
  2. Create Figma Prototype: Import generated images, add interactions
  3. User Testing: Validate navigation flow with 5-7 target users
  4. Refine: Iterate based on feedback
  5. Implement in SwiftUI: Build using generated mockups as reference

