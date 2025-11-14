# iOS 26 Liquid Glass Design Reference

## Visual Effects Catalog

### 1. Frosted Glass Backgrounds
```swift
// Main component background
.background(.ultraThinMaterial)

// Alternative materials
.background(.thinMaterial)      // More visible
.background(.regularMaterial)   // Even more visible
.background(.thickMaterial)     // Most visible
```

**Used in:**
- PetStatusCard main background
- HistoryCountView pill background
- All modal/overlay surfaces

---

### 2. Gradient Fills
```swift
// Color gradients for depth
.fill(.red.gradient)
.foregroundStyle(.blue.gradient)

// Custom gradients
LinearGradient(
    colors: [.blue.opacity(0.1), .purple.opacity(0.05)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

**Used in:**
- Pet marker background (red gradient)
- Owner marker background (green gradient)
- Status indicator dots (color-coded gradients)
- ContentView background gradient
- All icon colors

---

### 3. Depth Shadows
```swift
// Standard depth shadow
.shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)

// Marker shadow (smaller)
.shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 4)

// Subtle shadow for pills
.shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
```

**Shadow Hierarchy:**
- **Cards:** 20pt radius, 10pt Y-offset
- **Markers:** 8pt radius, 4pt Y-offset
- **Pills/Badges:** 8pt radius, 4pt Y-offset, lighter opacity

**Used in:**
- PetStatusCard (20pt)
- PetMapView container (20pt)
- Pet/Owner markers (8pt)
- HistoryCountView (8pt)

---

### 4. Continuous Corners
```swift
// Smooth, organic corners
RoundedRectangle(cornerRadius: 24, style: .continuous)

// Size recommendations
.continuous // 24pt - Large cards
.continuous // 12pt - Small cells/items
.continuous //  8pt - Banners/alerts

// Alternative to clipShape
.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
```

**Corner Radius Scale:**
- **Large cards:** 24pt (PetStatusCard, MapView)
- **Medium cells:** 12pt (MetadataItem)
- **Small banners:** 8pt (ErrorBanner)
- **Pills:** Capsule() (infinite radius)

---

### 5. Spring Animations
```swift
// Standard Liquid animation
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: property)

// Smooth easing for camera
withAnimation(.easeInOut(duration: 1.0)) {
    updateCamera()
}

// Continuous rotation
.linear(duration: 1).repeatForever(autoreverses: false)
```

**Animation Parameters:**
- **Response:** 0.3s (fast, fluid)
- **Damping:** 0.7 (slight bounce)
- **Duration:** 1.0s for camera movements
- **Trigger:** Always animate on value change

**Used in:**
- All state property updates
- Marker position updates
- Camera transitions
- Refresh button rotation

---

### 6. Semi-Transparent Overlays
```swift
// Background tints for metadata items
.background(.green.opacity(0.1))  // Success
.background(.yellow.opacity(0.1)) // Warning
.background(.red.opacity(0.1))    // Error
.background(.orange.opacity(0.1)) // Alert
```

**Opacity Scale:**
- **Background tints:** 0.1 (10%)
- **Trail polyline:** 0.7 (70%)
- **Dividers:** Default separator opacity

**Color Semantics:**
- **Green:** Good state (battery >50%, accuracy <10m)
- **Yellow:** Warning state (battery 20-50%, accuracy 10-50m)
- **Red:** Error state (battery <20%, accuracy >50m)
- **Orange:** Alerts and errors
- **Blue:** Information and actions
- **Purple:** Secondary information

---

## Component Recipes

### Liquid Glass Card
```swift
VStack {
    // Content
}
.padding(24)
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
.shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: state)
```

### Liquid Glass Marker
```swift
ZStack {
    Circle()
        .fill(.red.gradient)
        .frame(width: 44, height: 44)
        .shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 4)

    Image(systemName: "pawprint.fill")
        .font(.system(size: 20, weight: .bold))
        .foregroundStyle(.white)
}
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: UUID())
```

### Liquid Glass Pill Badge
```swift
HStack {
    Image(systemName: "icon")
    Text("Label")
}
.padding(.horizontal, 16)
.padding(.vertical, 8)
.background(.ultraThinMaterial)
.clipShape(Capsule())
.shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
```

### Liquid Glass Metadata Cell
```swift
VStack(spacing: 8) {
    Image(systemName: "icon")
        .foregroundStyle(.blue.gradient)

    Text("Label")
        .font(.caption)
        .foregroundStyle(.secondary)

    Text("Value")
        .font(.headline)
}
.frame(maxWidth: .infinity)
.padding(.vertical, 12)
.background(.blue.opacity(0.1))
.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
.animation(.spring(response: 0.3), value: value)
```

---

## Typography Scale

### Fonts
```swift
.font(.title2.bold())              // Card headers
.font(.headline)                   // Primary values
.font(.body)                       // Standard text
.font(.caption)                    // Labels and secondary
.font(.system(.body, design: .monospaced)) // Data values
```

### Text Styles
```swift
.foregroundStyle(.primary)         // Primary text (default)
.foregroundStyle(.secondary)       // Labels
.foregroundStyle(.tertiary)        // De-emphasized
.foregroundStyle(.blue.gradient)   // Accent text
```

---

## Spacing System

### Padding Scale
```swift
.padding(24)          // Card internal padding
.padding(20)          // Card horizontal margin
.padding(16)          // Pill horizontal padding
.padding(12)          // Cell/banner padding
.padding(8)           // Pill vertical padding
```

### VStack/HStack Spacing
```swift
VStack(spacing: 24)   // Major sections
VStack(spacing: 20)   // Card internal
VStack(spacing: 16)   // Grid cells
VStack(spacing: 12)   // Related items
VStack(spacing: 8)    // Tight grouping
VStack(spacing: 6)    // Status indicators
VStack(spacing: 4)    // Label-value pairs
```

---

## Color Palette

### Semantic Colors
```swift
// System colors (auto dark mode)
.blue      // Primary actions, information
.green     // Success, good state
.yellow    // Warning, attention needed
.red       // Error, critical state
.orange    // Alerts, moderate warnings
.purple    // Secondary information
.gray      // Neutral, disabled

// Shades
.secondary // 70% opacity on light, 65% on dark
.tertiary  // 50% opacity on light, 45% on dark
```

### Custom Tints
```swift
.blue.opacity(0.1)     // Background tint
.red.opacity(0.4)      // Shadow color
.black.opacity(0.1)    // Shadow color (light mode)
.black.opacity(0.3)    // Shadow color (dark mode)
```

---

## Animation Timing

### Spring Parameters
```swift
response: 0.3          // Fast response
dampingFraction: 0.7   // Slight bounce
```

### Duration Scale
```swift
0.3s  // UI state changes
0.8s  // Minimum refresh duration
1.0s  // Camera transitions
1.0s  // Continuous rotation loop
```

---

## Size Reference

### Component Sizes
```swift
44pt  // Markers (touch target)
20pt  // Marker icons
400pt // Map view height
100   // Location history limit
```

### Border Radii
```swift
24pt  // Large cards
12pt  // Medium cells
8pt   // Small banners
∞     // Capsule (pills)
```

### Shadow Radii
```swift
20pt  // Cards (depth)
8pt   // Markers, pills (subtle)
4pt   // Y-offset for elevation
```

---

## Usage Patterns

### When to Use Liquid Glass

✅ **Do Use:**
- Primary content cards (PetStatusCard)
- Floating UI elements (badges, pills)
- Overlay surfaces (modals, sheets)
- Background gradients for depth
- Spring animations for value changes
- Gradient icons for visual interest

❌ **Don't Use:**
- Every surface (reserve for important content)
- On already-busy backgrounds
- For critical text (ensure readability)
- Excessive animation (causes motion sickness)

### Accessibility Considerations

```swift
// Ensure contrast with material backgrounds
.foregroundStyle(.primary)  // Auto-adjusts for materials

// Support reduced motion
// Spring animations automatically respect system settings

// Dynamic Type
// Use .font() instead of fixed font sizes

// VoiceOver
// Add .accessibilityLabel() to custom markers
```

---

## Dark Mode Behavior

All Liquid Glass effects automatically adapt:
- `.ultraThinMaterial` → Darker, more translucent
- Shadows → More pronounced in dark mode
- Gradients → Richer, deeper colors
- Text → Inverted contrast ratios

No manual dark mode handling required for these effects.

---

## Example Implementations

See these files for complete examples:
- **PetStatusCard.swift** - Full card implementation
- **PetMapView.swift** - Custom markers
- **ContentView.swift** - Background gradient + pills
- **PetLocationManager.swift** - State management for animations
