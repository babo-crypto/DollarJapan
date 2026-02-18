# TrendAI v10 Model Generation Guide

## Overview

This directory contains the machine learning model files for the TrendAI v10 trading system. The ONNX model file (`trendai_v10.onnx`) is a binary file that must be generated using the Python training scripts.

## Prerequisites

Before generating the model, ensure you have the following installed:

```bash
pip install pandas numpy scikit-learn lightgbm xgboost onnx onnxmltools skl2onnx MetaTrader5
```

## Step-by-Step Model Generation

### Step 1: Collect Historical Data

The model requires historical USDJPY M15 data. You can collect this using MetaTrader 5:

```python
import MetaTrader5 as mt5
import pandas as pd
from datetime import datetime, timedelta

# Initialize MT5
mt5.initialize()

# Get historical data
symbol = "USDJPY"
timeframe = mt5.TIMEFRAME_M15
start_date = datetime.now() - timedelta(days=365)  # 1 year of data

rates = mt5.copy_rates_from(symbol, timeframe, start_date, 50000)

# Convert to DataFrame
df = pd.DataFrame(rates)
df['timestamp'] = pd.to_datetime(df['time'], unit='s')

# Save to CSV
df.to_csv('usdjpy_m15_historical.csv', index=False)

mt5.shutdown()
```

### Step 2: Train the Model

Navigate to the `python/` directory and run the training script:

```bash
cd python/
python train_model.py
```

This will:
- Load historical data
- Calculate all 14 features (Ichimoku, ATR, ADX, volume, session, etc.)
- Generate binary continuation labels (30-pip target within 10 candles)
- Train LightGBM model with walk-forward validation
- Save the trained model as `trendai_v10_lgb.pkl`
- Save scaler parameters to `scaler.json`
- Display training metrics and feature importance

Expected output:
```
Walk-Forward Validation Training (5 splits)
...
Average Validation Metrics:
  accuracy      : 0.6234
  precision     : 0.6543
  recall        : 0.5876
  f1_score      : 0.6192
  roc_auc       : 0.6789
```

### Step 3: Export to ONNX Format

Convert the trained model to ONNX format for MT5:

```bash
python export_onnx.py
```

This will generate:
- `models/trendai_v10.onnx` - The ONNX model file
- `models/scaler.json` - Feature normalization parameters
- `models/session_config.json` - Trading session configuration

### Step 4: Deploy to MT5

Copy the generated files to your MT5 data directory:

**Windows:**
```
C:\Users\[YourUsername]\AppData\Roaming\MetaQuotes\Terminal\[InstanceID]\MQL5\Files\models\
```

**Mac/Linux:**
```
~/.wine/drive_c/users/[username]/AppData/Roaming/MetaQuotes/Terminal/[InstanceID]/MQL5/Files/models/
```

Or use MT5's File Manager:
1. Open MT5
2. File → Open Data Folder
3. Navigate to MQL5\Files\
4. Create `models` folder if it doesn't exist
5. Copy the three files into this folder

### Step 5: Verify Model Loading

1. Open MT5 and load USDJPY M15 chart
2. Attach TrendAI_v10.mq5 EA to the chart
3. Check the Experts tab for these messages:
   ```
   TrendAI v10 PRO - Initialization Start
   ...
   ✓ ONNX Model loaded successfully
   ✓ Scaler loaded successfully
   ...
   Initialization Complete ✓
   ```

## Model Architecture

**Input Features (14):**
1. Tenkan slope
2. Kijun slope
3. Cloud thickness (normalized)
4. Price-Kumo distance (normalized)
5. Chikou relative position
6. ATR normalized (basis points)
7. ADX (trend strength)
8. Tick volume spike ratio
9. Broker hour (0-23)
10. Session ID (0=Asia, 1=London, 2=NY)
11. Spread (pips)
12. Candle compression ratio
13. Momentum strength (derived)
14. Relative Kumo strength (derived)

**Output:**
- Single probability value [0.0, 1.0]
- Represents likelihood of 30-pip continuation within 10 candles

**Model Type:**
- Primary: LightGBM (Gradient Boosting Decision Tree)
- Alternative: XGBoost
- Both models are optimized for time-series financial data

## Training Parameters

Default configuration in `train_model.py`:

```python
# LightGBM parameters
params = {
    'objective': 'binary',
    'metric': 'binary_logloss',
    'num_leaves': 31,
    'learning_rate': 0.05,
    'feature_fraction': 0.8,
    'max_depth': 7,
    'min_data_in_leaf': 20
}

# Label generation
continuation_pips = 30.0
lookforward_candles = 10

# Validation
n_splits = 5  # Walk-forward validation
```

## Performance Expectations

A well-trained model on 1 year of quality data should achieve:

- **Training Accuracy:** 60-65%
- **Validation Accuracy:** 58-62%
- **ROC AUC:** 0.65-0.72
- **Precision:** 60-68%
- **Recall:** 55-65%

*Note: These are continuation prediction metrics, not final trading P&L. The risk engine and Ichimoku filters provide additional layers of protection.*

## Troubleshooting

### Model fails to load in MT5

**Error:** "ONNX model file not found"
- **Solution:** Verify files are in correct MQL5\Files\models\ directory
- Check file permissions

**Error:** "Failed to load ONNX model"
- **Solution:** Regenerate model with `export_onnx.py`
- Ensure ONNX format is compatible (target_opset=12)

### Low model accuracy

**Issue:** Validation accuracy < 55%
- **Solutions:**
  - Collect more historical data (recommend 1+ years)
  - Adjust continuation_pips and lookforward_candles
  - Try different session filters (London/NY only)
  - Experiment with feature engineering

### Model not updating predictions

**Issue:** Same probability value every tick
- **Solutions:**
  - Check that features are being calculated correctly
  - Verify scaler parameters are loaded
  - Enable verbose logging in feature_builder.mqh

## Retraining Schedule

Recommended retraining frequency:
- **Monthly:** For active market conditions
- **Quarterly:** For stable market conditions
- **After major events:** Central bank policy changes, economic crises

Always perform walk-forward validation before deploying new models.

## Support and Debugging

Enable debug output in training scripts:

```python
# In train_model.py
import logging
logging.basicConfig(level=logging.DEBUG)
```

Check MT5 logs:
- Open MT5
- View → Toolbox → Experts tab
- Look for TrendAI messages

For issues, verify:
1. Feature calculations match between Python and MQL5
2. Scaler parameters are correctly exported
3. ONNX model version compatibility
4. Sufficient historical data quality

## Advanced: Custom Model Training

To modify the model architecture or training process:

1. Edit `feature_engineering.py` to add/modify features
2. Update `train_model.py` hyperparameters
3. Adjust `label_generator.py` for different targets
4. Retrain and export with updated parameters
5. Update feature count in `onnx_runner.mqh` if feature count changes

**Important:** If you change the number or order of features, you must update:
- `feature_builder.mqh` (MQL5 side)
- `onnx_runner.mqh` (update `m_num_features`)
- Re-export scaler with correct dimensions

---

**Version:** 10.0  
**Last Updated:** 2024  
**License:** Proprietary - For authorized use only
