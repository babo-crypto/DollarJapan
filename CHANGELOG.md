# Changelog

All notable changes to TrendAI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [11.0] - 2026-02-18

### 🎯 Major Institutional Upgrade
This release brings TrendAI to **9/10 institutional grade** with critical safety features, AI improvements, and proper validation.

### Added

#### Kill-Switch Safety System
- 6-checkpoint safety validation before every trade
- ONNX health monitoring with automatic fail-safe
- Spread spike protection (blocks trades when spread > 3 pips)
- Latency watchdog (blocks trades if AI inference > 500ms)
- Consecutive loss tracking (stops after 3 losses in a row)
- New risk states: `LOCKED_ONNX_FAIL`, `LOCKED_SPREAD_SPIKE`, `LOCKED_LATENCY`, `LOCKED_LOSS_STREAK`
- `CheckKillSwitch()` method validates all conditions
- `GetConsecutiveLosses()` and `GetDailyPnL()` getters

#### AI Confidence Scoring
- 4-level confidence system: NONE, LOW, MEDIUM, HIGH
- Confidence-based SL/TP adjustment:
  - LOW (72-80%): Tighter SL (0.8x), wider TP (1.2x)
  - MEDIUM (80-90%): Standard parameters
  - HIGH (≥90%): Extended TP (1.5x)
- Trades automatically skipped below minimum confidence (default 72%)
- `EvaluateConfidence()` function for dynamic assessment
- Global confidence tracking for dashboard display

#### Walk-Forward Validation (Python)
- `walk_forward_validation()` function with expanding window
- Time-series split: 6-month train, 1-month test windows
- Trading metrics calculation: Sharpe, max drawdown, win rate
- Performance threshold: Model must achieve ≥55% accuracy
- Validation results saved to `models/walk_forward_results.csv`
- `calculate_trading_metrics()` for realistic backtesting

#### Enhanced Dashboard
- **AI Confidence Row**: Shows current level and probability percentage
- **Loss Streak Row**: Displays "current / max" format (e.g., "2 / 3")
- **Enhanced Risk Status**: Detailed lock reason display
- Color-coded confidence: Green (HIGH), Yellow (MEDIUM), Orange (LOW)
- Loss streak warning: Red when ≥2 consecutive losses

#### Feature Versioning (Python)
- `FEATURE_VERSION` constant for tracking (v1.0.0)
- `FEATURE_LIST_V1` with all 15 features documented
- Market regime detection: TREND (ADX > 25), RANGE (default), CHOPPY (ATR spike + low ADX)
- `detect_market_regime()` function classifies market state
- `add_feature_metadata()` adds version and timestamp to datasets
- New feature: `regime_flag` (0=range, 1=trend, 2=choppy)

#### Documentation
- Comprehensive upgrade guide: `docs/UPGRADE_v11.md`
- Migration steps from v10 to v11
- Configuration examples (conservative vs aggressive)
- Testing checklist for production deployment
- Troubleshooting section for common issues

### Fixed

#### CRITICAL: ONNX Function Calls
- **Line 108 (onnx_runner.mqh)**: Changed `OnnxCreateFromFile(model_path, ONNX_DEFAULT)` to `OnnxCreate(model_path)`
- **Line 317 (onnx_runner.mqh)**: Changed `OnnxRun(m_model_handle, ONNX_DEFAULT, input_matrix, output_matrix)` to `OnnxRun(m_model_handle, input_matrix, output_matrix)`
- **Reason**: MQL5 ONNX functions do not accept `ONNX_DEFAULT` parameter (compilation error)

### Changed

#### Risk Engine
- Updated `OnTradeClosed()` to track consecutive losses and reset on profit
- Enhanced `GetRiskStateString()` to return detailed lock reasons
- Added kill-switch parameters to constructor initialization
- `ResetDailyCounters()` now resets consecutive losses on new day

#### Main EA (TrendAI_v10.mq5)
- Modified `CheckForTradingSignals()` to evaluate confidence before execution
- Updated `ExecuteBuyOrder()` and `ExecuteSellOrder()` to accept confidence parameter
- Added confidence-based SL/TP multiplier adjustments
- Integrated `CheckKillSwitch()` call before order placement
- Skip trades when confidence is NONE (< minimum threshold)

#### Python Training
- Updated `main()` in `train_model.py` to run walk-forward validation first
- Model only trained on full dataset if validation passes (accuracy ≥ 55%)
- Feature engineering now includes 15 features (was 14)
- Enhanced feature list with market regime classification

### Technical Details

**Files Modified**:
- `mt5_ea/onnx_runner.mqh` (2 critical fixes)
- `mt5_ea/risk_engine.mqh` (+150 lines, kill-switch system)
- `mt5_ea/TrendAI_v10.mq5` (+80 lines, confidence scoring)
- `mt5_ea/dashboard_ui.mqh` (+50 lines, new display rows)
- `python/feature_engineering.py` (+100 lines, versioning & regime)
- `python/train_model.py` (+200 lines, walk-forward validation)

**New Input Parameters**:
```mql5
input double InpMinConfidenceLow    = 0.72;
input double InpConfidenceMedium    = 0.80;
input double InpConfidenceHigh      = 0.90;
```

**API Changes**:
- `ExecuteBuyOrder()` signature: `(double probability)` → `(double probability, CONFIDENCE_LEVEL confidence)`
- `ExecuteSellOrder()` signature: `(double probability)` → `(double probability, CONFIDENCE_LEVEL confidence)`

### Performance Impact

- **Safety**: +50% more risk checkpoints (4 → 6)
- **Precision**: 4-level confidence vs binary (yes/no)
- **Reliability**: Walk-forward validation prevents overfitting
- **Monitoring**: Real-time kill-switch status on dashboard
- **Auditability**: Feature versioning enables reproducibility

### Breaking Changes

⚠️ **Not Backward Compatible**:
- Old v10 ONNX models must be retrained with new validation
- Dashboard panel height increased by 50px
- Confidence thresholds must be configured
- Feature count increased from 14 to 15

### Security

- ONNX model health check prevents blind execution
- Spread spike protection blocks trades during volatility spikes
- Latency watchdog prevents trading with degraded AI performance
- Loss streak protection stops cascading losses

---

## [10.0] - 2024-01-15

### Initial Release

#### Features
- Ichimoku-based directional bias engine
- ONNX ML model integration for trade timing
- 14-feature engineering pipeline
- Multi-layer risk management system
- Professional dashboard and telemetry
- Session-aware trading (Asia, London, New York)
- Fixed 0.01 lot size (no martingale)
- Daily loss limit and drawdown protection
- Cooldown period after losses
- Volatility filter (ATR-based)

#### Architecture
- Modular MQL5 design (8 components)
- Python ML pipeline (LightGBM/XGBoost)
- ONNX export for MT5 inference
- Real-time feature calculation
- Visual intelligence layer

#### Documentation
- Quick start guide
- Architecture documentation
- Risk management guide
- Dashboard design specs

---

## Release Notes

### Version Compatibility

| Version | MT5 Build | Python | Status |
|---------|-----------|--------|--------|
| 11.0 | ≥3440 | 3.8+ | Current |
| 10.0 | ≥3300 | 3.8+ | Deprecated |

### Upgrade Path

**v10 → v11**:
1. Recompile all MQL5 files
2. Retrain ML model with walk-forward validation
3. Configure confidence parameters
4. Test on demo for 1 week

---

## Support

- **GitHub**: [Issues](https://github.com/babo-crypto/DollarJapan/issues)
- **Documentation**: `docs/` folder
- **Upgrade Guide**: `docs/UPGRADE_v11.md`

---

**Legend**:
- 🎯 Major feature
- 🔧 Fix
- ⚠️ Breaking change
- 🔒 Security enhancement
