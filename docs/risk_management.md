# TrendAI v10 Risk Management Specification

## Philosophy

TrendAI v10 implements **institutional-grade risk management** with multiple independent safety layers. The system prioritizes capital preservation over profit maximization, operating under the principle that **surviving to trade another day is more important than any single trade**.

## Core Principles

### 1. Fixed Position Sizing
**ABSOLUTELY NO dynamic lot calculation, martingale, or scaling.**

```cpp
Fixed Lot Size: 0.01
Account: ~$500 USD
Risk per Trade: ~1% (with 1.5 ATR stop)
```

**Rationale:**
- Predictable risk exposure
- No compounding losses
- Simple to audit and understand
- Prevents emotional scaling decisions
- Protects against implementation bugs

### 2. Multi-Layer Defense
Risk validation occurs at multiple checkpoints:
1. Session-level limits
2. Daily loss limits
3. Spread filtering
4. Cooldown periods
5. Volatility filtering
6. Drawdown monitoring

Each layer is independent and fail-safe.

### 3. Conservative Parameters
All defaults err on the side of caution:
- Low trade frequency (3 per session)
- Tight loss limits (3% daily)
- Strict spread requirements (≤3 pips)
- Mandatory cooldown (4 candles after loss)

## Risk Parameters

### Configuration Matrix

| Parameter | Default | Range | Purpose |
|-----------|---------|-------|---------|
| `InpFixedLotSize` | 0.01 | 0.01 only | Position size (DO NOT CHANGE) |
| `InpMaxTradesPerSession` | 3 | 1-5 | Limit overtrading |
| `InpDailyLossLimitPct` | 3.0% | 1-5% | Circuit breaker |
| `InpMaxSpreadPips` | 3.0 | 1-5 | Execution quality |
| `InpCooldownCandles` | 4 | 2-10 | Loss recovery time |
| `InpMaxDrawdownPct` | 8.0% | 5-15% | Peak-to-valley limit |
| `InpVolatilityMultiplier` | 2.0 | 1.5-3.0 | ATR spike threshold |

### Parameter Selection Rationale

#### Fixed Lot Size: 0.01
```
Account: $500
Lot Size: 0.01
Average SL: 1.5 ATR ≈ 0.15 JPY ≈ 15 pips
Risk per Trade: ~$1.50 (0.3%)
```
- Well within 1% risk guideline
- Allows 20+ consecutive losses before account trouble
- Suitable for prop firm evaluations

#### Max Trades Per Session: 3
```
3 trades/session × 3 sessions/day = 9 max trades/day
At 0.3% risk each = 2.7% max daily risk
```
- Prevents overtrading exhaustion
- Limits exposure to single session conditions
- Allows strategy to play out without flooding

#### Daily Loss Limit: 3%
```
$500 × 3% = $15 maximum daily loss
Equivalent to ~10 losing trades at 0.3% each
```
- Circuit breaker activates before serious damage
- Protects against algorithm failure
- Psychological fresh start next day

#### Max Spread: 3.0 pips
```
USDJPY typical spread: 1.5-2.5 pips
3.0 pip threshold = ~2-3 STD above mean
```
- Filters news events and low liquidity
- Ensures quality execution
- Protects against slippage

#### Cooldown: 4 candles (1 hour on M15)
```
4 × 15 minutes = 60 minutes cooldown
```
- Prevents revenge trading
- Allows market conditions to normalize
- Reduces correlation between consecutive trades

#### Max Drawdown: 8%
```
$500 × 8% = $40 drawdown threshold
~27 consecutive losses at 0.3% risk each
```
- Protects against strategy degradation
- Forces review before continuing
- Common prop firm rule

#### Volatility Multiplier: 2.0
```
If ATR(14) > 2.0 × ATR(20), skip trade
```
- Avoids news spikes and flash crashes
- Protects model from out-of-distribution data
- Reduces whipsaw risk

## Risk Engine State Machine

### States

```cpp
enum ENUM_RISK_STATE {
    RISK_STATE_ACTIVE = 0,     // Normal trading
    RISK_STATE_LOCKED = 1,     // Daily loss limit hit
    RISK_STATE_COOLDOWN = 2,   // Post-loss recovery
    RISK_STATE_DRAWDOWN = 3,   // Max drawdown exceeded
    RISK_STATE_VOLATILITY = 4  // High volatility detected
};
```

### State Transitions

```
                    ┌──────────────────────┐
                    │   ACTIVE (Normal)    │
                    └──────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   [Loss Trade]        [Daily Loss >= 3%]    [Drawdown > 8%]
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  COOLDOWN    │      │   LOCKED     │      │  DRAWDOWN    │
└──────────────┘      └──────────────┘      └──────────────┘
        │                     │                     │
   [4 candles]           [New day]            [Manual reset]
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                              ▼
                    ┌──────────────────────┐
                    │       ACTIVE         │
                    └──────────────────────┘
```

## Trade Validation Flow

### Pre-Trade Checklist

Every trade must pass ALL checks:

```
1. ✓ Position Check
   └─ No existing position on symbol

2. ✓ Model Check
   └─ ML probability >= 0.72 (or Ichimoku-only mode)

3. ✓ Session Check
   └─ Current session enabled in parameters
   └─ Session trade count < max allowed

4. ✓ Spread Check
   └─ Current spread <= max threshold

5. ✓ Risk State Check
   └─ State == ACTIVE

6. ✓ Daily Loss Check
   └─ Today's loss < daily limit

7. ✓ Cooldown Check
   └─ Cooldown counter == 0

8. ✓ Volatility Check
   └─ ATR(14) < 2.0 × ATR(20)

9. ✓ Drawdown Check
   └─ Current DD% < max threshold

10. ✓ Ichimoku Check
    └─ Clear directional bias present
```

If ANY check fails → Trade REJECTED

## Stop Loss & Take Profit

### Stop Loss Calculation

```cpp
// Buy trade example
double entry_price = Ask;
double atr = GetATRNormalized() * entry_price / 10000.0;
double sl_distance = atr * InpSLMultiplier;  // Default: 1.5
double stop_loss = entry_price - sl_distance;
```

**Characteristics:**
- Based on market volatility (ATR)
- Automatically adjusts to conditions
- 1.5x multiplier provides breathing room
- Typical: 15-25 pips for USDJPY

### Take Profit Calculation

```cpp
double tp_distance = sl_distance * InpTPRatio;  // Default: 1.5
double take_profit = entry_price + tp_distance;
```

**Risk-Reward Ratio:**
```
Default: 1:1.5
$1 risked → $1.50 target
Break-even winrate: 40%
```

### Trailing Stop (Optional)

```cpp
// Kijun-sen trailing
if (InpUseTrailingStop) {
    double current_kijun = GetKijunValue();
    
    // For buy trade
    if (current_kijun > current_sl) {
        ModifyStopLoss(current_kijun);
    }
}
```

**Benefits:**
- Locks in profits during strong trends
- Uses Ichimoku's natural support/resistance
- Only moves in favorable direction

## Session-Based Risk Management

### Session Trade Limits

```
ASIA Session:    Max 3 trades
LONDON Session:  Max 3 trades
NEWYORK Session: Max 3 trades
──────────────────────────────
Daily Maximum:   9 trades
```

**Per-Session Tracking:**
```cpp
int m_asia_trade_count;
int m_london_trade_count;
int m_newyork_trade_count;
```

Reset daily at midnight broker time.

### Session Filtering

```cpp
// User can disable specific sessions
InpTradeAsia    = true;   // 00:00-08:00
InpTradeLondon  = true;   // 08:00-16:00
InpTradeNewYork = true;   // 16:00-24:00
```

**Recommendation:**
- Disable ASIA (lower liquidity)
- Enable LONDON + NEWYORK (higher quality)

## Daily Loss Lock

### Mechanism

```cpp
double m_daily_start_balance;  // Set at midnight
double current_balance = AccountBalance();
double daily_loss = m_daily_start_balance - current_balance;
double loss_pct = (daily_loss / m_daily_start_balance) * 100.0;

if (loss_pct >= InpDailyLossLimitPct) {
    m_current_state = RISK_STATE_LOCKED;
    Alert("Daily loss limit reached. Trading locked for today.");
}
```

### Recovery

- **Automatic:** Resets at midnight (new trading day)
- **Manual:** Requires EA restart on new day
- **Floating P&L:** Includes open position losses

### Notification

- Alert popup when triggered
- Dashboard shows "LOCKED" in red
- Expert log records event
- No trades accepted until reset

## Cooldown System

### Trigger

```cpp
void CRiskEngine::OnTradeClosed(double profit_loss) {
    if (profit_loss < 0) {
        m_cooldown_remaining = InpCooldownCandles;
        m_current_state = RISK_STATE_COOLDOWN;
    }
}
```

### Countdown

```cpp
void CRiskEngine::OnNewCandle() {
    if (m_cooldown_remaining > 0) {
        m_cooldown_remaining--;
        
        if (m_cooldown_remaining == 0) {
            m_current_state = RISK_STATE_ACTIVE;
        }
    }
}
```

### Display

Dashboard shows:
```
Risk Status: COOLDOWN (3 candles remaining)
```

### Purpose

- Prevents revenge trading
- Allows emotional reset
- Reduces correlation between consecutive losses
- Forces patience

## Volatility Filter

### ATR Spike Detection

```cpp
double atr_current = ATR(14);
double atr_slow = ATR(20);
double atr_ratio = atr_current / atr_slow;

if (atr_ratio > InpVolatilityMultiplier) {
    // Skip trade - too volatile
    m_current_state = RISK_STATE_VOLATILITY;
    return false;
}
```

### Typical Scenarios

- **News releases:** BOJ, Fed announcements
- **Market open gaps:** Sunday evening opens
- **Flash crashes:** Sudden liquidity events
- **Holiday thinness:** Christmas, New Year

### Benefits

- Protects ML model from outliers
- Reduces slippage risk
- Avoids erratic price action
- Preserves capital during chaos

## Drawdown Protection

### Peak Tracking

```cpp
double m_session_peak_equity;

void UpdatePeakEquity() {
    double current_equity = AccountEquity();
    if (current_equity > m_session_peak_equity) {
        m_session_peak_equity = current_equity;
    }
}
```

### Drawdown Calculation

```cpp
double current_equity = AccountEquity();
double drawdown = m_session_peak_equity - current_equity;
double drawdown_pct = (drawdown / m_session_peak_equity) * 100.0;

if (drawdown_pct >= InpMaxDrawdownPct) {
    m_current_state = RISK_STATE_DRAWDOWN;
}
```

### Recovery

- **Not automatic:** Requires manual review
- **Suggests:** Strategy may be failing
- **Action:** Investigate recent trades, market conditions
- **Resume:** Only after confirming system health

## Spread Filtering

### Real-Time Check

```cpp
double current_spread = GetCurrentSpreadPips();

if (current_spread > InpMaxSpreadPips) {
    return false;  // Skip trade
}
```

### Calculation

```cpp
double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
double spread_pips = (ask - bid) / _Point / 10.0;  // For 3-digit
```

### Thresholds

- **Normal:** 1.5-2.0 pips
- **Acceptable:** 2.0-3.0 pips
- **Reject:** >3.0 pips

## Account Sizing Examples

### $500 Account (Default)

```
Balance: $500
Lot Size: 0.01
Risk per Trade: ~0.3% ($1.50)
Daily Loss Limit: 3% ($15)
Max Drawdown: 8% ($40)
```

**Survival Analysis:**
- 10 consecutive losses: -3% (within limits)
- 20 consecutive losses: -6% (acceptable)
- 27 consecutive losses: -8.1% (drawdown lock)

### $1000 Account (Scaling Up)

```
Balance: $1000
Lot Size: 0.02 (2x increase)
Risk per Trade: ~0.3% ($3.00)
Daily Loss Limit: 3% ($30)
Max Drawdown: 8% ($80)
```

**Still conservative:**
- Same percentage risk
- Same safety margins
- Simply scales linearly

### $10,000 Account (Professional)

```
Balance: $10,000
Lot Size: 0.20
Risk per Trade: ~0.3% ($30)
Daily Loss Limit: 3% ($300)
Max Drawdown: 8% ($800)
```

## Prop Firm Compatibility

TrendAI v10 is designed to pass prop firm evaluations:

### Common Prop Rules

| Rule | TrendAI v10 | Status |
|------|-------------|--------|
| Daily loss limit | 3% (configurable) | ✓ Compliant |
| Max drawdown | 8% (configurable) | ✓ Compliant |
| Fixed lot size | 0.01 (no scaling) | ✓ Compliant |
| No martingale | Fixed only | ✓ Compliant |
| Risk per trade | ~0.3% | ✓ Compliant |
| Max positions | 1 at a time | ✓ Compliant |

### Recommended Settings for Prop Evaluation

```cpp
// Conservative for challenge phase
InpFixedLotSize = 0.01;
InpMaxTradesPerSession = 2;      // Lower frequency
InpDailyLossLimitPct = 2.5;      // Tighter limit
InpMaxDrawdownPct = 6.0;         // Stricter control
InpMinProbability = 0.75;        // Higher threshold
```

## Risk Monitoring & Alerts

### Dashboard Indicators

```
Risk Status Colors:
  GREEN  (ACTIVE)      → All systems go
  YELLOW (COOLDOWN)    → Temporary pause
  RED    (LOCKED)      → Daily limit hit
  RED    (DRAWDOWN)    → Max DD exceeded
  YELLOW (VOLATILITY)  → High volatility detected
```

### Alert Conditions

```cpp
// Trigger popup alerts for:
- Daily loss limit reached
- Max drawdown exceeded
- Wrong symbol/timeframe detected
- Model loading failure (warning only)
```

### Logging

```cpp
// All risk events logged to Experts tab:
Print("RISK ALERT: Daily loss limit reached");
Print("Trade opened. Today's count: ", count);
Print("Cooldown started: ", candles, " candles");
Print("✓ All risk checks passed");
```

## Emergency Procedures

### If Daily Loss Limit Hit

1. **Automatic:** Trading stops immediately
2. **Manual:** Review trades in Experts tab
3. **Analysis:** Check if losses were systematic or random
4. **Next Day:** Fresh start with reset counter

### If Max Drawdown Hit

1. **Automatic:** Trading stops immediately
2. **Manual:** DO NOT simply restart
3. **Review Required:**
   - Check recent market conditions
   - Verify model is loading correctly
   - Review spread conditions
   - Analyze losing trade patterns
4. **Resume:** Only after confirming system health

### If Repeated Cooldowns

- **Pattern:** Multiple losses in short period
- **Action:** Review Ichimoku bias quality
- **Check:** ML model predictions vs. outcomes
- **Consider:** Temporarily increase probability threshold

## Best Practices

### Position Management

1. **Never modify** risk parameters mid-session
2. **Always close** positions before news events
3. **Monitor** spread widening around session changes
4. **Review** daily performance each evening

### Parameter Tuning

1. **Start conservative:** Use default parameters
2. **Only adjust** based on 1 month+ data
3. **One change** at a time
4. **Document** all changes and results

### Account Management

1. **Withdraw profits** regularly (keep risk base stable)
2. **Never add funds** after bad day (emotional decision)
3. **Scale slowly:** Only increase lot size after 3+ profitable months

---

**Version:** 10.0  
**Last Updated:** 2024  
**Document Type:** Risk Management Specification  
**Classification:** Institutional-Grade Trading System
