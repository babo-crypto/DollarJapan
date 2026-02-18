# TrendAI v10 PRO - USDJPY M15 Institutional Trading System

[![Version](https://img.shields.io/badge/version-10.0-blue.svg)](https://github.com/babo-crypto/DollarJapan)
[![MT5](https://img.shields.io/badge/platform-MetaTrader%205-green.svg)](https://www.metatrader5.com)
[![Symbol](https://img.shields.io/badge/symbol-USDJPY-orange.svg)](https://www.tradingview.com/symbols/USDJPY/)
[![Timeframe](https://img.shields.io/badge/timeframe-M15-red.svg)](https://github.com/babo-crypto/DollarJapan)
[![License](https://img.shields.io/badge/license-Proprietary-yellow.svg)](LICENSE)

> **Professional-grade algorithmic trading system combining Ichimoku technical analysis with machine learning for precise trade timing on USDJPY 15-minute charts.**

---

## 🎯 System Overview

TrendAI v10 is an **institutional-grade Expert Advisor** designed specifically for USDJPY M15 trading. It represents the convergence of three critical trading components:

1. **Directional Bias Engine** - Ichimoku Kinko Hyo for trend identification
2. **ML Timing Intelligence** - ONNX neural network for trade entry probability
3. **Capital Protection Layer** - Multi-layered risk management system

### Key Features

✅ **Fixed Position Sizing** - Consistent 0.01 lot (no martingale, no scaling)  
✅ **Walk-Forward Validated** - ML model trained with proper time-series validation  
✅ **Multi-Layer Risk Management** - Session limits, daily loss lock, drawdown protection  
✅ **Professional Dashboard** - Real-time visual intelligence and performance metrics  
✅ **Session-Aware Trading** - Optimized for London and New York sessions  
✅ **Institutional Standards** - Prop firm compatible, conservative parameters  

---

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   TrendAI v10 System Stack                       │
├─────────────────────────────────────────────────────────────────┤
│  Visual Layer          │ Dashboard + Telemetry + AI Overlays    │
│  Execution Layer       │ Order Management + Position Tracking   │
│  Risk Layer            │ Multi-Checkpoint Validation Engine     │
│  Intelligence Layer    │ Ichimoku (Bias) + ONNX ML (Timing)    │
│  Feature Layer         │ 14-Feature Engineering Pipeline        │
│  Data Layer            │ OHLC + Volume + Indicators             │
└─────────────────────────────────────────────────────────────────┘
```

### Technology Stack

**MetaTrader 5 (MQL5)**
- Core trading logic and execution
- Real-time feature calculation
- ONNX model inference
- UI rendering and monitoring

**Python Machine Learning**
- LightGBM/XGBoost model training
- Feature engineering pipeline
- Walk-forward validation
- ONNX export for MT5 integration

---

## 🚀 Quick Start

### Prerequisites

- **MetaTrader 5** terminal installed
- **USDJPY** symbol available from your broker
- **Python 3.8+** (for model training)
- **~$500 USD** trading account (minimum recommended)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/babo-crypto/DollarJapan.git
   cd DollarJapan
   ```

2. **Copy MQL5 files to MT5**
   ```
   Copy mt5_ea/* → MT5_DATA_FOLDER/MQL5/Experts/TrendAI_v10/
   ```

3. **Generate ML model** (Optional - can trade with Ichimoku only)
   ```bash
   cd python
   pip install -r requirements.txt
   python train_model.py        # Train model
   python export_onnx.py        # Export to ONNX
   ```

4. **Deploy model files**
   ```
   Copy models/* → MT5_DATA_FOLDER/MQL5/Files/models/
   ```

5. **Load EA on chart**
   - Open MT5
   - Open USDJPY M15 chart
   - Drag `TrendAI_v10.mq5` onto chart
   - Configure parameters (defaults are recommended)
   - Enable AutoTrading

### Verification

Check MT5 Experts tab for:
```
✓ TrendAI v10 PRO - Initialization Start
✓ Chart setup: USDJPY M15 validated
✓ Feature Builder initialized
✓ ONNX Model loaded successfully
✓ Risk Engine configured
✓ Dashboard initialized
✓ System Status: ACTIVE
```

---

## 📁 Repository Structure

```
DollarJapan/
├── mt5_ea/                     # MetaTrader 5 Expert Advisor
│   ├── TrendAI_v10.mq5        # Main EA file
│   ├── feature_builder.mqh    # Feature engineering module
│   ├── onnx_runner.mqh        # ML model inference
│   ├── risk_engine.mqh        # Risk management system
│   ├── dashboard_ui.mqh       # Main dashboard panel
│   ├── telemetry_panel.mqh    # Performance metrics display
│   ├── ai_overlay.mqh         # Chart overlays and signals
│   └── chart_setup.mqh        # Auto chart configuration
│
├── python/                     # Machine Learning Pipeline
│   ├── train_model.py         # Model training with walk-forward
│   ├── feature_engineering.py # Feature calculation (mirrors MQL5)
│   ├── label_generator.py     # 30-pip continuation labels
│   ├── broker_time_analysis.py# Session performance analytics
│   └── export_onnx.py         # ONNX conversion and export
│
├── models/                     # ML Model Files
│   ├── trendai_v10.onnx       # ONNX model (generated)
│   ├── scaler.json            # Feature normalization params
│   ├── session_config.json    # Trading session configuration
│   └── README.md              # Model generation guide
│
├── docs/                       # Documentation
│   ├── architecture.md        # System architecture and data flow
│   ├── dashboard_design.md    # UI specifications
│   └── risk_management.md     # Risk rules and parameters
│
└── README.md                   # This file
```

---

## 🎓 Feature Engineering

The system calculates **14 features** for each M15 candle:

### Ichimoku Components (5 features)
1. **Tenkan-sen slope** - Short-term momentum
2. **Kijun-sen slope** - Medium-term trend
3. **Cloud thickness** - Trend strength (normalized by ATR)
4. **Price-Kumo distance** - Position relative to cloud
5. **Chikou span position** - Lagging confirmation

### Market Conditions (7 features)
6. **ATR normalized** - Volatility in basis points
7. **ADX** - Trend strength indicator
8. **Tick volume spike** - Volume anomaly detection
9. **Broker hour** - Time of day (0-23)
10. **Session ID** - Asia/London/NY/Off-hours
11. **Spread** - Current bid-ask spread in pips
12. **Candle compression** - Range vs. average

### Derived Features (2 features)
13. **Momentum strength** - Tenkan slope × ADX
14. **Relative Kumo strength** - Cloud thickness / ATR

---

## 🤖 Machine Learning Model

### Model Architecture

- **Algorithm:** LightGBM (primary) / XGBoost (alternative)
- **Type:** Gradient Boosted Decision Trees
- **Task:** Binary classification (continuation prediction)
- **Input:** 14 features (normalized)
- **Output:** Probability [0.0, 1.0]

### Training Process

1. **Data Collection:** 1+ years of USDJPY M15 historical data
2. **Feature Engineering:** Calculate all 14 features
3. **Label Generation:** Binary labels (30-pip target within 10 candles)
4. **Walk-Forward Validation:** 5-split expanding window
5. **Hyperparameter Tuning:** Cross-validation optimization
6. **ONNX Export:** Convert to MT5-compatible format

### Performance Targets

- **Training Accuracy:** 60-65%
- **Validation Accuracy:** 58-62%
- **ROC AUC:** 0.65-0.72
- **Minimum Threshold:** 0.72 probability for trade execution

### Training the Model

```bash
cd python

# Install dependencies
pip install pandas numpy scikit-learn lightgbm xgboost onnx onnxmltools

# Collect historical data (requires MT5 Python package)
python -c "from feature_engineering import *; collect_mt5_data()"

# Train model
python train_model.py

# Export to ONNX
python export_onnx.py

# Deploy
cp ../models/*.{onnx,json} /path/to/MT5/MQL5/Files/models/
```

---

## 🛡️ Risk Management

### Core Principles

**FIXED LOT SIZE ONLY - NO SCALING, NO MARTINGALE, NO GRID**

### Risk Parameters (Default)

| Parameter | Default | Purpose |
|-----------|---------|---------|
| **Lot Size** | 0.01 | Fixed position size |
| **Daily Loss Limit** | 3% | Circuit breaker |
| **Max Drawdown** | 8% | Peak-to-valley limit |
| **Max Spread** | 3.0 pips | Execution quality filter |
| **Cooldown Period** | 4 candles | Post-loss recovery time |
| **Session Trade Limit** | 3 trades | Per-session maximum |
| **Volatility Filter** | 2.0x ATR | Spike detection threshold |

### Multi-Layer Protection

```
Trade Request
    ↓
[Layer 1] Session trade count check
    ↓
[Layer 2] Spread validation
    ↓
[Layer 3] Daily loss limit check
    ↓
[Layer 4] Cooldown period check
    ↓
[Layer 5] Volatility spike check
    ↓
[Layer 6] Drawdown limit check
    ↓
[Layer 7] Ichimoku directional bias
    ↓
[Layer 8] ML probability threshold
    ↓
✓ EXECUTE TRADE (if all pass)
```

### Account Sizing

**$500 Account Example:**
```
Balance: $500
Lot Size: 0.01
Risk per Trade: ~0.3% (~$1.50)
Daily Loss Limit: 3% ($15)
Max Drawdown: 8% ($40)

Survival: 27 consecutive losses before max DD
```

---

## 📺 Dashboard & UI

### Professional Dark Theme

The system features an institutional-grade visual interface with:

**Main Dashboard Panel:**
- Symbol/Timeframe display
- Current trading session (color-coded)
- ML probability percentage
- AI confidence level
- Real-time spread monitoring
- ADX trend strength
- Ichimoku cloud status
- Trading window status
- Daily trade count
- Risk engine state

**Telemetry Panel:**
- Today's P&L (monetary + percentage)
- Rolling winrate statistics
- Session-specific winrate
- Average trade duration
- AI prediction accuracy (20-trade window)
- Current drawdown percentage

**AI Chart Overlays:**
- Buy/Sell signal arrows
- Probability heatbars
- Session background gradients
- Kumo strength indicators

### Color Coding

- **Green** - Bullish signals, healthy metrics
- **Red** - Bearish signals, warning states
- **Yellow** - Medium confidence, caution
- **Gray** - Neutral, inactive states
- **Blue/Orange/Crimson** - Session backgrounds (Asia/London/NY)

---

## 📈 Trading Strategy

### Signal Generation

**BUY Signal Requirements:**
1. Price > Ichimoku cloud
2. Tenkan-sen > Kijun-sen
3. ML probability ≥ 0.72
4. All risk checks pass
5. Session filter enabled
6. Spread acceptable

**SELL Signal Requirements:**
1. Price < Ichimoku cloud
2. Tenkan-sen < Kijun-sen
3. ML probability ≥ 0.72
4. All risk checks pass
5. Session filter enabled
6. Spread acceptable

### Position Management

- **Stop Loss:** 1.5 × ATR from entry
- **Take Profit:** 1.5:1 risk-reward ratio
- **Trailing Stop:** Optional Kijun-sen trailing
- **Max Positions:** 1 at a time
- **Position Monitoring:** Every tick

### Session Filtering

**Recommended:**
- ✅ **LONDON** (08:00-16:00 broker time) - High liquidity, clear trends
- ✅ **NEW YORK** (16:00-24:00 broker time) - Strong momentum
- ⚠️ **ASIA** (00:00-08:00 broker time) - Lower volume (optional)

---

## 📊 Performance Expectations

### Realistic Targets

**Monthly Performance (Conservative):**
- Win Rate: 55-65%
- Profit Factor: 1.5-2.0
- Monthly Return: 2-5%
- Max Drawdown: <6%
- Trade Frequency: 30-60 trades/month

### Important Notes

⚠️ **Past performance does not guarantee future results**  
⚠️ **This is NOT a get-rich-quick system**  
⚠️ **Requires proper risk management and monitoring**  
⚠️ **Backtesting results may differ from live trading**  

### Backtesting

To backtest the system:
1. Use MT5 Strategy Tester
2. Mode: "Every tick based on real ticks"
3. Symbol: USDJPY
4. Period: M15
5. Date range: Minimum 1 year
6. Deposit: $500 (recommended)
7. Fixed lot: 0.01

---

## 🔧 Configuration

### Input Parameters

**Risk Management:**
```cpp
InpFixedLotSize = 0.01;           // Fixed lot size
InpMaxTradesPerSession = 3;        // Max trades per session
InpDailyLossLimitPct = 3.0;       // Daily loss limit %
InpMaxSpreadPips = 3.0;           // Max spread pips
InpCooldownCandles = 4;           // Cooldown after loss
InpMaxDrawdownPct = 8.0;          // Max drawdown %
```

**ML Model:**
```cpp
InpModelPath = "models/trendai_v10.onnx";  // ONNX model path
InpScalerPath = "models/scaler.json";       // Scaler path
InpMinProbability = 0.72;                   // Min probability threshold
```

**Trading Logic:**
```cpp
InpSLMultiplier = 1.5;            // SL as ATR multiplier
InpTPRatio = 1.5;                 // TP ratio vs SL
InpUseTrailingStop = true;        // Enable trailing stop
InpMagicNumber = 100710;          // Magic number
```

**Session Filters:**
```cpp
InpTradeAsia = true;              // Trade Asia session
InpTradeLondon = true;            // Trade London session
InpTradeNewYork = true;           // Trade New York session
```

---

## 🎓 Documentation

Comprehensive documentation available in `/docs`:

- **[architecture.md](docs/architecture.md)** - System design, data flow, module dependencies
- **[dashboard_design.md](docs/dashboard_design.md)** - UI specifications, color schemes, layout
- **[risk_management.md](docs/risk_management.md)** - Risk rules, parameters, best practices

---

## 🔍 Troubleshooting

### EA Not Loading

**Issue:** EA fails to initialize  
**Solution:** 
- Check symbol is exactly "USDJPY"
- Verify timeframe is M15
- Enable AutoTrading in MT5
- Check Experts tab for error messages

### Model Not Loading

**Issue:** "ONNX model file not found"  
**Solution:**
- Verify files in `MT5_DATA_FOLDER/MQL5/Files/models/`
- Check file permissions
- Regenerate model with `export_onnx.py`

### No Trades Opening

**Issue:** EA initialized but no trades  
**Solution:**
- Check Risk Status on dashboard
- Verify session filters enabled
- Check if cooldown period active
- Confirm ML probability exceeds threshold
- Check spread is within limits

### Dashboard Not Showing

**Issue:** No visual dashboard on chart  
**Solution:**
- Set `InpShowDashboard = true`
- Check chart has enough space
- Adjust position with `InpDashboardX/Y`
- Reload EA

---

## ⚠️ Important Disclaimers

### Trading Risk

**FOREX TRADING INVOLVES SUBSTANTIAL RISK OF LOSS**

- This EA does not guarantee profits
- Past performance is not indicative of future results
- You can lose all your invested capital
- Only trade with risk capital you can afford to lose
- This is NOT financial advice

### System Limitations

- Optimized specifically for **USDJPY M15** only
- Requires stable internet connection
- Performance depends on broker conditions
- ML model requires retraining periodically
- Does not account for fundamental news events

### Prop Firm Usage

This EA is designed to be compatible with prop firm rules, however:
- Always verify with your specific firm's policies
- Test thoroughly on demo accounts first
- Monitor compliance with daily loss limits
- Ensure lot sizing meets requirements

### No Warranty

THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND. USE AT YOUR OWN RISK.

---

## 🤝 Support & Community

### Getting Help

- **Issues:** Open an issue on GitHub
- **Documentation:** Check `/docs` directory
- **Updates:** Watch repository for new releases

### Contributing

This is a proprietary system. Contributions are not currently accepted.

### License

Proprietary - All rights reserved. See LICENSE file for details.

---

## 📝 Version History

### v10.0 (Current)
- Initial release
- Ichimoku + ONNX ML architecture
- Multi-layer risk management
- Professional dashboard UI
- Walk-forward validated ML model
- Session-aware trading logic
- Comprehensive documentation

---

## 🎯 Roadmap

Future enhancements under consideration:

- [ ] Multi-timeframe analysis integration
- [ ] Enhanced trailing stop strategies
- [ ] Additional ML model architectures
- [ ] Broker-specific optimizations
- [ ] Advanced session analytics
- [ ] Performance reporting dashboard

---

## 👨‍💻 About

**TrendAI v10** is a professional algorithmic trading system developed for serious traders who value:
- Capital preservation over aggressive gains
- Systematic approach over emotional trading
- Institutional-grade risk management
- Transparency and code quality

**Built with:** MetaTrader 5, MQL5, Python, LightGBM, ONNX

**Optimized for:** USDJPY, M15 timeframe, $500+ accounts

---

**⭐ If you find this system valuable, please star the repository!**

**📧 For inquiries:** Open an issue on GitHub

---

*Disclaimer: This is not financial advice. Trading involves risk. Always do your own research and never trade with money you cannot afford to lose.*
