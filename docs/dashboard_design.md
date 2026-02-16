# TrendAI v10 Dashboard Design Specification

## Overview

The TrendAI v10 dashboard system consists of three integrated visual components that provide real-time intelligence and performance monitoring without interfering with trading operations.

## Design Philosophy

### Institutional Aesthetic
- **Dark Theme:** Professional charcoal background (C'20,22,28')
- **Minimal Color:** Only meaningful color coding (green/red/yellow)
- **No Clutter:** Information density balanced with readability
- **Monospace Font:** Consolas for precise alignment
- **Semi-Transparent:** Overlays don't obstruct chart analysis

### Information Hierarchy
1. **Critical:** Trade status, risk state (large, prominent)
2. **Important:** ML probability, session info (medium emphasis)
3. **Context:** Statistics, metrics (smaller, less prominent)

## Component 1: Main Dashboard Panel

### Layout Wireframe

```
┌─────────────────────────────────────────┐
│  TrendAI v10 PRO                        │ ← Header (12pt, white)
│  INSTITUTIONAL TRADING SYSTEM           │ ← Subtitle (8pt, gray)
│                                         │
│  Symbol:           USDJPY / M15         │ ← Chart info
│  Session:          LONDON               │ ← Current session (colored)
│  AI Probability:   78.5%                │ ← ML prediction (colored)
│  Confidence:       HIGH                 │ ← Derived confidence
│  Spread:           2.1 pips             │ ← Market condition
│  ADX Strength:     28.3                 │ ← Trend strength
│  Cloud Status:     ABOVE                │ ← Ichimoku position
│  Trading Window:   YES                  │ ← Session filter
│  Daily Trades:     2                    │ ← Trade count
│  Risk Status:      ACTIVE               │ ← Risk state (colored)
└─────────────────────────────────────────┘
```

### Dimensions
- **Width:** 280 pixels
- **Height:** 320 pixels
- **Position:** Top-left (20, 50) - configurable
- **Corner:** CORNER_LEFT_UPPER

### Color Coding

#### Session Colors
```cpp
ASIA    → Cornflower Blue   C'100,149,237'
LONDON  → Orange            C'255,165,0'
NEWYORK → Crimson           C'220,20,60'
OFF     → Gray              C'149,165,166'
```

#### Probability Colors
```cpp
>= 80% → Green              C'46,204,113'  (High confidence)
>= 70% → Light Green        C'140,230,140'
>= 65% → Yellow             C'241,196,15'  (Medium)
>= 50% → Orange             C'243,156,18'
<  50% → Red                C'231,76,60'   (Low)
```

#### Risk Status Colors
```cpp
ACTIVE      → Green         C'46,204,113'
COOLDOWN    → Yellow        C'241,196,15'
LOCKED      → Red           C'231,76,60'
DRAWDOWN    → Red           C'231,76,60'
VOLATILITY  → Yellow        C'241,196,15'
```

### Update Frequency
- **Every Tick:** All fields update in real-time
- **Performance:** ~2ms per update
- **No Flicker:** ObjectSetString only on value change

### Font Specifications
- **Font:** Consolas (monospace)
- **Header:** 12pt, bold effect via white color
- **Subtitle:** 8pt
- **Labels:** 9pt
- **Values:** 9-10pt (emphasis on important values)

## Component 2: Telemetry Panel

### Layout Wireframe

```
┌─────────────────────────────────────────┐
│  PERFORMANCE TELEMETRY                  │ ← Header (11pt)
│                                         │
│  Today P&L:       $12.50 (2.5%)        │ ← Daily profit (colored)
│  Winrate (Rolling): 62.5%              │ ← Success rate
│  Session Winrate:   65.0%              │ ← Current session
│  Avg Trade Dur:     45.2 min           │ ← Hold time
│  AI Accuracy (20T): 68.0%              │ ← Model accuracy
│  Current DD:        1.2%               │ ← Drawdown
└─────────────────────────────────────────┘
```

### Dimensions
- **Width:** 280 pixels
- **Height:** 220 pixels
- **Position:** Below main dashboard (20, 390)
- **Corner:** CORNER_LEFT_UPPER

### Color Coding

#### P&L Display
```cpp
Positive → Green    C'46,204,113'
Negative → Red      C'231,76,60'
Zero     → Gray     C'220,220,220'
```

#### Winrate Display
```cpp
>= 60% → Green      C'46,204,113'  (Good)
50-60% → Gray       C'220,220,220' (Neutral)
<  50% → Red        C'231,76,60'   (Poor)
```

#### Drawdown Display
```cpp
<= 2% → Green       C'46,204,113'  (Safe)
2-5%  → Yellow      C'241,196,15'  (Caution)
>  5% → Red         C'231,76,60'   (Warning)
```

### Update Frequency
- **On Trade Close:** P&L, winrate, accuracy
- **Every Tick:** Drawdown
- **Buffered Updates:** Refresh() method batches changes

### Statistical Windows
- **Rolling Winrate:** All trades in session
- **AI Accuracy:** Last 20 trades (circular buffer)
- **Average Duration:** Cumulative mean

## Component 3: AI Overlay System

### Signal Arrows

#### Buy Signal
```
Visual: ▲ (Arrow code 233)
Color:  Green C'46,204,113'
Size:   Width 3
Position: Below candle (price - 0.05)
Tooltip: "BUY Signal\nProb: 78.5%\nTime: 2024-01-15 14:30"
```

#### Sell Signal
```
Visual: ▼ (Arrow code 234)
Color:  Red C'231,76,60'
Size:   Width 3
Position: Above candle (price + 0.05)
Tooltip: "SELL Signal\nProb: 72.3%\nTime: 2024-01-15 14:45"
```

### Probability Heatbar

```
Visual: Vertical bar beside current price
Height: Scaled by probability (0.0001 * prob * 1000)
Color:  Gradient based on probability
Style:  Filled rectangle (OBJ_RECTANGLE)
Label:  "78%" text at top of bar
```

### Session Background

```
Purpose: Subtle visual session indicator
Type:   OBJ_RECTANGLE covering recent bars
Colors:
  - ASIA:    Dark blue tint   C'40,45,70'
  - LONDON:  Dark orange tint C'70,50,30'
  - NEWYORK: Dark red tint    C'70,35,40'
Style:  Semi-transparent, back layer
Width:  Last 2 hours of bars
```

### Object Lifecycle
- **Creation:** On signal generation or session change
- **Naming:** Prefix "TrendAI_Overlay_" + timestamp
- **Cleanup:** Auto-cleanup when >500 objects
- **Removal:** All objects removed on OnDeinit()

## Chart Configuration

### Auto-Setup (chart_setup.mqh)

#### Color Scheme
```cpp
Background:      C'20,22,28'   (Dark charcoal)
Foreground:      C'220,220,220' (Light text)
Grid:            C'40,42,48'   (Subtle)
Candle Bull:     C'46,204,113' (Green)
Candle Bear:     C'231,76,60'  (Red)
Volume:          C'100,100,100' (Dark gray)
```

#### Indicator Attachment
- **Main Window:** Ichimoku (9, 26, 52)
- **Sub-Window 1:** ATR(14)
- **Sub-Window 2:** ADX(14)

#### Chart Properties
```cpp
Mode:            CHART_CANDLES
Grid:            Enabled
OHLC Display:    Enabled
Period Sep:      Enabled
Autoscroll:      Enabled
Trade Levels:    Enabled
One-Click Trade: Disabled (safety)
Scale:           2 (medium zoom)
```

## Positioning Logic

### Default Positions
```cpp
Main Dashboard:  (20, 50)   - Top left with margin
Telemetry Panel: (20, 390)  - Below main dashboard
AI Overlays:     Dynamic    - On chart at price levels
```

### Configurable via Inputs
```cpp
InpDashboardX = 20;   // X position
InpDashboardY = 50;   // Y position
```

### Alternative Positions
```cpp
Top Right:    (ChartWidth - 300, 50)
Bottom Left:  (20, ChartHeight - 600)
Bottom Right: (ChartWidth - 300, ChartHeight - 600)
```

### Position Validation
- Check chart boundaries
- Ensure panels don't overlap
- Adjust if chart is resized

## Responsive Behavior

### Chart Resize
- Panels maintain relative position
- No automatic repositioning (could be jarring)
- User can adjust via input parameters

### Timeframe Change
- Warning: EA designed for M15 only
- Dashboard shows error state
- No trading until correct timeframe

### Symbol Change
- Warning: EA designed for USDJPY only
- Dashboard shows error state
- No trading until correct symbol

## Performance Optimization

### Object Reuse
- Labels created once, updated with ObjectSetString
- Background rectangles static
- Only text content changes

### Batch Updates
- Telemetry uses Refresh() to batch all updates
- Reduces ObjectSetString calls
- Minimizes chart redraw frequency

### Memory Limits
- Max ~50 objects per panel
- AI overlays limited to 500 total
- Auto-cleanup removes oldest objects

## Accessibility

### Visual Hierarchy
1. **Immediate attention:** Red risk warnings
2. **Active monitoring:** Green probability >70%
3. **Background info:** Gray neutral states

### Color Blindness Consideration
- Not solely reliant on color
- Text labels always present
- Status text explicit ("ACTIVE", "LOCKED")

### Font Legibility
- Monospace ensures alignment
- Minimum 8pt font size
- High contrast (light on dark)

## Testing Checklist

### Dashboard Display
- [ ] All labels render correctly
- [ ] Colors match specification
- [ ] Updates occur on every tick
- [ ] No flickering or redraw issues
- [ ] Position is configurable

### Telemetry Accuracy
- [ ] P&L matches account values
- [ ] Winrate calculates correctly
- [ ] AI accuracy tracks properly
- [ ] Drawdown updates in real-time

### AI Overlays
- [ ] Signal arrows appear on trades
- [ ] Probability heatbars render
- [ ] Session backgrounds show correctly
- [ ] Old objects cleaned up
- [ ] No memory leaks

### Chart Setup
- [ ] Correct symbol/timeframe enforced
- [ ] Dark theme applies properly
- [ ] Indicators attach to chart
- [ ] Chart is readable and professional

## UI State Diagram

```
[EA Load]
    ↓
[Initialize Panels]
    ↓
[Display Loading State]
    ↓
[Check Symbol/TF] ──ERROR──→ [Display Error State]
    ↓ OK                            ↓
[Check Model] ──MISSING──→ [Display Warning State]
    ↓ LOADED                        ↓
[Display Active State] ←────────────┘
    ↓
[Every Tick: Update]
    ├─ [New Data → Update Values]
    ├─ [Risk Change → Update Colors]
    └─ [Trade → Draw Overlays]
```

## Error States

### Model Not Loaded
```
Dashboard shows:
  AI Probability: N/A
  Confidence:     MODEL NOT LOADED
  Color:          Yellow warning
```

### Risk Locked
```
Dashboard shows:
  Risk Status:    LOCKED (Red, bold)
  Alert message displayed
  Dashboard blinks briefly
```

### Wrong Chart
```
Dashboard shows:
  Symbol:         ERROR - USE USDJPY M15
  All other values: Grayed out
  No trading permitted
```

---

**Version:** 10.0  
**Last Updated:** 2024  
**Document Type:** UI/UX Design Specification
