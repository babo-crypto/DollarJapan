# TrendAI v10 System Architecture

## Overview

TrendAI v10 is a professional-grade institutional trading system that combines traditional technical analysis (Ichimoku) with modern machine learning (ONNX) and robust risk management for USDJPY M15 trading.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     TrendAI v10 System                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 DATA INGESTION LAYER                     │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │ Market Data  │  │  Indicators  │  │ Session Time │  │  │
│  │  │   (OHLC)     │  │   (Built-in) │  │   Detection  │  │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │  │
│  └─────────┼──────────────────┼──────────────────┼─────────┘  │
│            │                  │                  │             │
│            └──────────────────┴──────────────────┘             │
│                               │                                │
│  ┌────────────────────────────▼──────────────────────────────┐ │
│  │              FEATURE ENGINEERING LAYER                    │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │   feature_builder.mqh (MQL5)                        │ │ │
│  │  │  • Ichimoku: Tenkan, Kijun, Cloud, Chikou          │ │ │
│  │  │  • Volatility: ATR normalized                       │ │ │
│  │  │  • Trend: ADX                                       │ │ │
│  │  │  • Volume: Tick volume spike ratio                 │ │ │
│  │  │  • Session: Broker hour, Session ID                │ │ │
│  │  │  • Market: Spread, Candle compression              │ │ │
│  │  │  • Derived: Momentum strength, Kumo strength       │ │ │
│  │  │  ────────────────────────────────────────────────  │ │ │
│  │  │  Output: 14-dimensional feature vector             │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────┬──────────────────────────────┘ │
│                               │                                │
│  ┌────────────────────────────▼──────────────────────────────┐ │
│  │               INTELLIGENCE LAYER                          │ │
│  │  ┌──────────────────────────────────────────────────┐    │ │
│  │  │  Directional Bias Engine (Ichimoku)             │    │ │
│  │  │  • BUY: Price > Cloud AND Tenkan > Kijun        │    │ │
│  │  │  • SELL: Price < Cloud AND Tenkan < Kijun       │    │ │
│  │  └───────────────────────────┬──────────────────────┘    │ │
│  │                              │                            │ │
│  │  ┌───────────────────────────▼──────────────────────┐    │ │
│  │  │  ML Timing Engine (ONNX)                         │    │ │
│  │  │  • Model: LightGBM/XGBoost → ONNX               │    │ │
│  │  │  • Prediction: Continuation probability [0,1]   │    │ │
│  │  │  • Threshold: 0.72 minimum                       │    │ │
│  │  │  • Scaler: StandardScaler (mean/std)            │    │ │
│  │  └───────────────────────────┬──────────────────────┘    │ │
│  └────────────────────────────┬─┴──────────────────────────┘ │
│                               │                                │
│  ┌────────────────────────────▼──────────────────────────────┐ │
│  │               RISK MANAGEMENT LAYER                       │ │
│  │  ┌────────────────────────────────────────────────────┐  │ │
│  │  │   risk_engine.mqh                                  │  │ │
│  │  │  ✓ Fixed Lot: 0.01 (NEVER dynamic)                │  │ │
│  │  │  ✓ Session Limit: 3 trades per session             │  │ │
│  │  │  ✓ Daily Loss Lock: 3% of balance                  │  │ │
│  │  │  ✓ Spread Filter: Max 3.0 pips                     │  │ │
│  │  │  ✓ Cooldown: 4 candles after loss                  │  │ │
│  │  │  ✓ Volatility Filter: ATR spike > 2x average      │  │ │
│  │  │  ✓ Drawdown Limit: 8% from peak                    │  │ │
│  │  └────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────┬──────────────────────────────┘ │
│                               │                                │
│  ┌────────────────────────────▼──────────────────────────────┐ │
│  │              EXECUTION LAYER                              │ │
│  │  ┌──────────────────┐  ┌──────────────────┐              │ │
│  │  │  Trade Opening   │  │ Position Mgmt    │              │ │
│  │  │  • SL: 1.5x ATR  │  │ • Trailing Stop  │              │ │
│  │  │  • TP: 1.5:1 R:R │  │   (Kijun-based)  │              │ │
│  │  │  • Magic: 100710 │  │ • Partial close  │              │ │
│  │  └──────────────────┘  └──────────────────┘              │ │
│  └────────────────────────────┬──────────────────────────────┘ │
│                               │                                │
│  ┌────────────────────────────▼──────────────────────────────┐ │
│  │           VISUAL INTELLIGENCE LAYER                       │ │
│  │  ┌──────────────────┐  ┌──────────────┐  ┌────────────┐ │ │
│  │  │ Main Dashboard   │  │  Telemetry   │  │AI Overlays │ │ │
│  │  │ • Symbol/TF      │  │  • P&L       │  │• Signals   │ │ │
│  │  │ • Session        │  │  • Winrate   │  │• Probability│ │ │
│  │  │ • ML Probability │  │  • Duration  │  │• Heatbars  │ │ │
│  │  │ • Confidence     │  │  • Accuracy  │  │• Sessions  │ │ │
│  │  │ • Risk Status    │  │  • Drawdown  │  │            │ │ │
│  │  └──────────────────┘  └──────────────┘  └────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Module Dependency Map

```
TrendAI_v10.mq5 (Main EA)
├── chart_setup.mqh
│   └── Forces USDJPY M15, configures chart appearance
│
├── feature_builder.mqh
│   ├── Calculates 14 features from market data
│   └── Dependencies: iIchimoku(), iATR(), iADX()
│
├── onnx_runner.mqh
│   ├── Loads ONNX model and scaler
│   ├── Normalizes features
│   └── Returns probability prediction
│
├── risk_engine.mqh
│   ├── Validates trade conditions
│   ├── Tracks daily/session limits
│   └── Monitors drawdown and volatility
│
├── dashboard_ui.mqh
│   ├── Main information panel
│   └── Real-time status display
│
├── telemetry_panel.mqh
│   ├── Performance metrics
│   └── Accuracy tracking
│
└── ai_overlay.mqh
    ├── Signal arrows on chart
    ├── Probability visualization
    └── Session background colors
```

## Data Flow Pipeline

### 1. Signal Generation Flow

```
[New Candle] → [Feature Builder]
                      ↓
              [14 Features Calculated]
                      ↓
              [Feature Normalization]
                      ↓
              [ONNX Model Inference]
                      ↓
              [Probability: 0.0-1.0]
                      ↓
         [Check: Prob >= 0.72?] ──NO──→ [Skip Trade]
                      ↓ YES
              [Ichimoku Bias Check]
                      ↓
         [BUY: Price>Cloud & Tenkan>Kijun]
         [SELL: Price<Cloud & Tenkan<Kijun]
                      ↓
              [Risk Engine Validation]
                      ↓
         [Session OK? Spread OK? Cooldown OK?]
         [Daily limit OK? Volatility OK?]
                      ↓ ALL PASS
              [Execute Trade]
                      ↓
         [Monitor Position & Update UI]
```

### 2. Feature Calculation Flow

```
Market Data (OHLC + Volume + Spread)
         │
         ├─→ [Ichimoku Calculation]
         │   ├─→ Tenkan-sen (9)
         │   ├─→ Kijun-sen (26)
         │   ├─→ Senkou Span A & B
         │   └─→ Chikou Span
         │
         ├─→ [ATR Calculation (14)]
         │   └─→ Normalized by price
         │
         ├─→ [ADX Calculation (14)]
         │   └─→ Trend strength
         │
         ├─→ [Volume Analysis]
         │   └─→ Spike ratio (20-period)
         │
         ├─→ [Session Detection]
         │   ├─→ Broker hour extraction
         │   └─→ Session ID mapping
         │
         └─→ [Market Conditions]
             ├─→ Spread measurement
             └─→ Candle compression
                      ↓
         [14-D Feature Vector]
```

### 3. Risk Management Flow

```
[Trade Request]
      ↓
[Session Trade Count] ─NO─→ [Reject: Max trades reached]
      ↓ OK
[Spread Check] ─NO─→ [Reject: Spread too wide]
      ↓ OK
[Daily Loss Check] ─NO─→ [Reject: Daily limit reached]
      ↓ OK
[Cooldown Check] ─NO─→ [Reject: In cooldown period]
      ↓ OK
[Volatility Check] ─NO─→ [Reject: Excessive volatility]
      ↓ OK
[Drawdown Check] ─NO─→ [Reject: Max drawdown exceeded]
      ↓ OK
[APPROVE TRADE]
      ↓
[Execute with Fixed 0.01 Lot]
```

## Python Training Pipeline

```
[Historical USDJPY M15 Data]
         │
         ├─→ [Feature Engineering]
         │   └─→ feature_engineering.py
         │       └─→ Mirrors MQL5 calculations
         │
         ├─→ [Label Generation]
         │   └─→ label_generator.py
         │       └─→ 30-pip continuation within 10 candles
         │
         └─→ [Model Training]
             └─→ train_model.py
                 ├─→ Walk-forward validation (5 splits)
                 ├─→ LightGBM/XGBoost training
                 ├─→ Hyperparameter tuning
                 ├─→ Feature importance analysis
                 └─→ Session performance analytics
                      ↓
         [Trained Model + Scaler]
                      ↓
         [ONNX Export] (export_onnx.py)
                      ↓
         [Deploy to MT5]
```

## Key Design Principles

### 1. Separation of Concerns
- **Feature Engineering:** Isolated in dedicated module
- **ML Inference:** Separate ONNX runner
- **Risk Management:** Independent validation layer
- **UI:** Non-blocking, separate from trading logic

### 2. Fail-Safe Architecture
- EA can run without ML model (Ichimoku-only mode)
- Risk engine provides multiple safety layers
- Fixed lot size prevents scaling disasters
- Graceful degradation on component failure

### 3. Institutional Standards
- No martingale or grid trading
- No dynamic lot sizing
- Conservative risk parameters
- Professional UI design
- Comprehensive logging

### 4. Time-Series Integrity
- Walk-forward validation (no lookahead bias)
- Expanding window training
- Session-aware feature engineering
- Proper train/test splitting

### 5. Production Readiness
- Complete error handling
- Resource cleanup (OnDeinit)
- Memory management (object limits)
- Performance monitoring

## Component Interactions

### OnInit() Sequence
```
1. chart_setup.SetupChart() → Validate symbol/timeframe
2. feature_builder.Initialize() → Create indicator handles
3. onnx_runner.LoadModel() → Load ML model (optional)
4. risk_engine.Initialize() → Setup risk parameters
5. dashboard_ui.Initialize() → Create UI panels
6. telemetry_panel.Initialize() → Setup metrics display
7. ai_overlay.Initialize() → Prepare chart overlays
```

### OnTick() Sequence
```
1. Check for new candle
   ├─ YES → risk_engine.OnNewCandle()
   └─ Continue
2. Update dashboard (every tick)
3. Manage open positions
   ├─ Trailing stop logic
   └─ Position monitoring
4. On new candle only:
   └─ CheckForTradingSignals()
      ├─ Build features
      ├─ Get ML prediction
      ├─ Check Ichimoku bias
      ├─ Validate with risk engine
      └─ Execute if all pass
```

### OnDeinit() Sequence
```
1. feature_builder.Deinitialize() → Release indicators
2. onnx_runner.UnloadModel() → Free model memory
3. risk_engine.Deinitialize() → Cleanup resources
4. dashboard_ui.Destroy() → Remove UI objects
5. telemetry_panel.Destroy() → Remove telemetry
6. ai_overlay.Destroy() → Remove overlays
7. chart_setup.CleanupIndicators() → Remove chart indicators
```

## Performance Considerations

### Memory Management
- Indicator buffers: Managed by MT5
- Feature arrays: Stack allocation (14 doubles)
- ONNX model: Loaded once, reused
- UI objects: Limited to ~50 per panel

### Computation Efficiency
- Feature calculation: ~1ms per tick
- ONNX inference: ~5-10ms per prediction
- UI updates: ~2ms per tick
- Total overhead: <20ms per tick

### Network Requirements
- No external API calls
- All computation local
- No internet dependency
- Offline operation capable

## Security Considerations

1. **No Secret Hardcoding:** Magic number configurable
2. **Input Validation:** All parameters validated
3. **Error Handling:** Comprehensive try-catch equivalents
4. **Resource Limits:** Max object counts enforced
5. **Safe Math:** Division by zero checks throughout

## Scalability

### Single Instance
- Designed for: 1 symbol (USDJPY), 1 timeframe (M15)
- Can run: Multiple instances on different charts
- Resource usage: Low (suitable for VPS)

### Multi-Symbol Support
- Not recommended (system is USDJPY-optimized)
- Would require: Symbol-specific models
- Better approach: Deploy separate instances

---

**Version:** 10.0  
**Last Updated:** 2024  
**Document Type:** Technical Architecture Specification
