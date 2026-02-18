//+------------------------------------------------------------------+
//|                                                  risk_engine.mqh |
//|                                      TrendAI_v10 Risk Management |
//|                           Institutional-Grade Capital Protection |
//+------------------------------------------------------------------+
//| Module: Risk Management Engine                                   |
//| Purpose: Capital protection and trade filtering                  |
//| Version: 10.0                                                     |
//| Author: TrendAI Development Team                                  |
//+------------------------------------------------------------------+

#property copyright "TrendAI Development Team"
#property version   "10.0"
#property strict

//+------------------------------------------------------------------+
//| Risk State Enumeration                                            |
//+------------------------------------------------------------------+
enum ENUM_RISK_STATE
{
   RISK_STATE_ACTIVE = 0,          // Normal trading allowed
   RISK_STATE_LOCKED = 1,          // Daily loss limit reached
   RISK_STATE_COOLDOWN = 2,        // Cooldown period after loss
   RISK_STATE_DRAWDOWN = 3,        // Maximum drawdown exceeded
   RISK_STATE_VOLATILITY = 4,      // Excessive volatility detected
   RISK_STATE_LOCKED_ONNX_FAIL = 5,     // ONNX model failure
   RISK_STATE_LOCKED_SPREAD_SPIKE = 6,  // Spread too high
   RISK_STATE_LOCKED_LATENCY = 7,       // AI inference too slow
   RISK_STATE_LOCKED_LOSS_STREAK = 8    // Too many consecutive losses
};

//+------------------------------------------------------------------+
//| Risk Engine Class                                                 |
//+------------------------------------------------------------------+
class CRiskEngine
{
private:
   // Configuration parameters
   double   m_fixed_lot_size;
   int      m_max_trades_per_session;
   double   m_daily_loss_limit_pct;
   double   m_max_spread_pips;
   int      m_cooldown_candles;
   double   m_max_drawdown_pct;
   double   m_volatility_multiplier;
   
   // State tracking
   ENUM_RISK_STATE m_current_state;
   datetime m_last_trade_time;
   datetime m_last_loss_time;
   int      m_cooldown_remaining;
   double   m_session_peak_equity;
   double   m_daily_start_balance;
   datetime m_current_trading_day;
   
   // Session trade counting
   int      m_asia_trade_count;
   int      m_london_trade_count;
   int      m_newyork_trade_count;
   
   // Performance tracking
   double   m_today_pnl;
   int      m_today_trade_count;
   datetime m_last_reset_date;
   
   // ATR handles for volatility check
   int      m_atr_handle;
   int      m_atr_slow_handle;
   
   // Kill-switch parameters (v11)
   int      m_consecutive_losses;
   int      m_max_consecutive_losses;
   double   m_max_allowed_spread;
   double   m_max_inference_latency_ms;
   double   m_max_daily_loss_usd;
   
   //--- Private methods
   void     UpdateDailyTracking();
   void     UpdateCooldown();
   bool     CheckDailyLossLimit();
   bool     CheckDrawdownLimit();
   bool     CheckVolatilityFilter();
   void     ResetDailyCounters();
   int      GetSessionTradeCount(int session_id);
   void     IncrementSessionTradeCount(int session_id);
   
public:
   //--- Constructor / Destructor
   CRiskEngine();
   ~CRiskEngine();
   
   //--- Initialization
   bool     Initialize(string symbol, ENUM_TIMEFRAMES timeframe);
   void     Deinitialize();
   
   //--- Configuration setters
   void     SetFixedLotSize(double lot_size) { m_fixed_lot_size = lot_size; }
   void     SetMaxTradesPerSession(int max_trades) { m_max_trades_per_session = max_trades; }
   void     SetDailyLossLimit(double pct) { m_daily_loss_limit_pct = pct; }
   void     SetMaxSpread(double pips) { m_max_spread_pips = pips; }
   void     SetCooldownCandles(int candles) { m_cooldown_candles = candles; }
   void     SetMaxDrawdown(double pct) { m_max_drawdown_pct = pct; }
   void     SetVolatilityMultiplier(double multiplier) { m_volatility_multiplier = multiplier; }
   
   //--- Trade permission checks
   bool     AllowTrade(int session_id, double current_spread_pips);
   bool     CanTradeInSession(int session_id);
   bool     IsSpreadAcceptable(double spread_pips);
   
   //--- State management
   void     OnTradeOpened(int session_id, double open_price);
   void     OnTradeClosed(double profit_loss);
   void     OnNewCandle();
   
   //--- Getters
   ENUM_RISK_STATE GetRiskState() { return m_current_state; }
   string   GetRiskStateString();
   double   GetFixedLotSize() { return m_fixed_lot_size; }
   int      GetTodayTradeCount() { return m_today_trade_count; }
   double   GetTodayPnL() { return m_today_pnl; }
   int      GetCooldownRemaining() { return m_cooldown_remaining; }
   double   GetCurrentDrawdown();
   double   GetDailyPnL() { return m_today_pnl; }
   double   GetCurrentDrawdownPercent() { return GetCurrentDrawdown(); }
   int      GetConsecutiveLosses() { return m_consecutive_losses; }
   
   //--- Kill-switch system (v11)
   bool     CheckKillSwitch();
   void     SetMaxConsecutiveLosses(int max_losses) { m_max_consecutive_losses = max_losses; }
   void     SetMaxAllowedSpread(double max_spread) { m_max_allowed_spread = max_spread; }
   void     SetMaxInferenceLatency(double max_latency_ms) { m_max_inference_latency_ms = max_latency_ms; }
   void     SetMaxDailyLossUSD(double max_loss_usd) { m_max_daily_loss_usd = max_loss_usd; }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRiskEngine::CRiskEngine()
{
   // Default configuration (institutional conservative settings)
   m_fixed_lot_size = 0.01;
   m_max_trades_per_session = 3;
   m_daily_loss_limit_pct = 3.0;
   m_max_spread_pips = 3.0;
   m_cooldown_candles = 4;
   m_max_drawdown_pct = 8.0;
   m_volatility_multiplier = 2.0;
   
   // Initialize state
   m_current_state = RISK_STATE_ACTIVE;
   m_last_trade_time = 0;
   m_last_loss_time = 0;
   m_cooldown_remaining = 0;
   m_session_peak_equity = 0;
   m_daily_start_balance = 0;
   m_current_trading_day = 0;
   
   // Reset counters
   m_asia_trade_count = 0;
   m_london_trade_count = 0;
   m_newyork_trade_count = 0;
   m_today_pnl = 0;
   m_today_trade_count = 0;
   m_last_reset_date = 0;
   
   m_atr_handle = INVALID_HANDLE;
   m_atr_slow_handle = INVALID_HANDLE;
   
   // Initialize kill-switch parameters (v11)
   m_consecutive_losses = 0;
   m_max_consecutive_losses = 3;          // Stop after 3 losses in a row
   m_max_allowed_spread = 3.0;            // 3 pips for USDJPY
   m_max_inference_latency_ms = 500.0;    // 500ms max AI response time
   m_max_daily_loss_usd = 100.0;          // $100 max daily loss
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CRiskEngine::~CRiskEngine()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize risk engine                                            |
//+------------------------------------------------------------------+
bool CRiskEngine::Initialize(string symbol, ENUM_TIMEFRAMES timeframe)
{
   // Create ATR indicators for volatility filtering
   m_atr_handle = iATR(symbol, timeframe, 14);
   if(m_atr_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ATR indicator for risk engine");
      return false;
   }
   
   m_atr_slow_handle = iATR(symbol, timeframe, 20);
   if(m_atr_slow_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create slow ATR indicator for risk engine");
      return false;
   }
   
   // Initialize daily tracking
   m_daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_session_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_current_trading_day = TimeCurrent();
   m_last_reset_date = TimeCurrent();
   
   Print("Risk Engine initialized successfully");
   Print("Fixed Lot Size: ", m_fixed_lot_size);
   Print("Max Trades Per Session: ", m_max_trades_per_session);
   Print("Daily Loss Limit: ", m_daily_loss_limit_pct, "%");
   Print("Max Spread: ", m_max_spread_pips, " pips");
   
   return true;
}

//+------------------------------------------------------------------+
//| Release resources                                                 |
//+------------------------------------------------------------------+
void CRiskEngine::Deinitialize()
{
   if(m_atr_handle != INVALID_HANDLE)
      IndicatorRelease(m_atr_handle);
   if(m_atr_slow_handle != INVALID_HANDLE)
      IndicatorRelease(m_atr_slow_handle);
}

//+------------------------------------------------------------------+
//| Main trade permission check                                      |
//+------------------------------------------------------------------+
bool CRiskEngine::AllowTrade(int session_id, double current_spread_pips)
{
   // Update daily tracking
   UpdateDailyTracking();
   
   // Update cooldown counter
   UpdateCooldown();
   
   // Check risk state
   if(m_current_state != RISK_STATE_ACTIVE)
   {
      return false;
   }
   
   // Check session trade count
   if(!CanTradeInSession(session_id))
   {
      return false;
   }
   
   // Check spread
   if(!IsSpreadAcceptable(current_spread_pips))
   {
      return false;
   }
   
   // Check daily loss limit
   if(!CheckDailyLossLimit())
   {
      m_current_state = RISK_STATE_LOCKED;
      Print("RISK ALERT: Daily loss limit reached. Trading locked for today.");
      return false;
   }
   
   // Check drawdown limit
   if(!CheckDrawdownLimit())
   {
      m_current_state = RISK_STATE_DRAWDOWN;
      Print("RISK ALERT: Maximum drawdown exceeded. Trading suspended.");
      return false;
   }
   
   // Check volatility filter
   if(!CheckVolatilityFilter())
   {
      m_current_state = RISK_STATE_VOLATILITY;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if can trade in specific session                           |
//+------------------------------------------------------------------+
bool CRiskEngine::CanTradeInSession(int session_id)
{
   int session_count = GetSessionTradeCount(session_id);
   
   if(session_count >= m_max_trades_per_session)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                    |
//+------------------------------------------------------------------+
bool CRiskEngine::IsSpreadAcceptable(double spread_pips)
{
   return (spread_pips <= m_max_spread_pips);
}

//+------------------------------------------------------------------+
//| Called when a trade is opened                                    |
//+------------------------------------------------------------------+
void CRiskEngine::OnTradeOpened(int session_id, double open_price)
{
   m_last_trade_time = TimeCurrent();
   m_today_trade_count++;
   
   IncrementSessionTradeCount(session_id);
   
   Print("Trade opened. Today's trade count: ", m_today_trade_count);
}

//+------------------------------------------------------------------+
//| Called when a trade is closed                                    |
//+------------------------------------------------------------------+
void CRiskEngine::OnTradeClosed(double profit_loss)
{
   m_today_pnl += profit_loss;
   
   // Track consecutive losses (v11)
   if(profit_loss < 0)
   {
      m_consecutive_losses++;
   }
   else if(profit_loss > 0)
   {
      m_consecutive_losses = 0;  // Reset on profit
   }
   
   // If loss, start cooldown
   if(profit_loss < 0)
   {
      m_last_loss_time = TimeCurrent();
      m_cooldown_remaining = m_cooldown_candles;
      m_current_state = RISK_STATE_COOLDOWN;
      
      Print("Trade closed with loss: ", profit_loss, ". Cooldown started: ", m_cooldown_candles, " candles");
      Print("Consecutive losses: ", m_consecutive_losses);
   }
   else
   {
      Print("Trade closed with profit: ", profit_loss);
   }
   
   // Update peak equity
   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(current_equity > m_session_peak_equity)
      m_session_peak_equity = current_equity;
}

//+------------------------------------------------------------------+
//| Called on new candle                                             |
//+------------------------------------------------------------------+
void CRiskEngine::OnNewCandle()
{
   UpdateCooldown();
   UpdateDailyTracking();
}

//+------------------------------------------------------------------+
//| Update daily tracking                                             |
//+------------------------------------------------------------------+
void CRiskEngine::UpdateDailyTracking()
{
   MqlDateTime current_dt, last_dt;
   TimeToStruct(TimeCurrent(), current_dt);
   TimeToStruct(m_last_reset_date, last_dt);
   
   // Check if new day
   if(current_dt.day != last_dt.day || current_dt.mon != last_dt.mon || current_dt.year != last_dt.year)
   {
      ResetDailyCounters();
   }
}

//+------------------------------------------------------------------+
//| Reset daily counters                                              |
//+------------------------------------------------------------------+
void CRiskEngine::ResetDailyCounters()
{
   Print("New trading day detected. Resetting daily counters.");
   
   m_asia_trade_count = 0;
   m_london_trade_count = 0;
   m_newyork_trade_count = 0;
   m_today_pnl = 0;
   m_today_trade_count = 0;
   m_cooldown_remaining = 0;
   
   m_daily_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_session_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_last_reset_date = TimeCurrent();
   
   // Reset risk state if it was daily locked
   if(m_current_state == RISK_STATE_LOCKED)
      m_current_state = RISK_STATE_ACTIVE;
   
   // Reset consecutive losses on new day (v11)
   m_consecutive_losses = 0;
}

//+------------------------------------------------------------------+
//| Update cooldown counter                                           |
//+------------------------------------------------------------------+
void CRiskEngine::UpdateCooldown()
{
   if(m_cooldown_remaining > 0)
   {
      m_cooldown_remaining--;
      
      if(m_cooldown_remaining <= 0)
      {
         m_current_state = RISK_STATE_ACTIVE;
         Print("Cooldown period ended. Trading re-enabled.");
      }
   }
}

//+------------------------------------------------------------------+
//| Check daily loss limit                                           |
//+------------------------------------------------------------------+
bool CRiskEngine::CheckDailyLossLimit()
{
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double daily_loss = m_daily_start_balance - current_balance;
   
   double loss_pct = (daily_loss / m_daily_start_balance) * 100.0;
   
   return (loss_pct < m_daily_loss_limit_pct);
}

//+------------------------------------------------------------------+
//| Check drawdown limit                                              |
//+------------------------------------------------------------------+
bool CRiskEngine::CheckDrawdownLimit()
{
   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = m_session_peak_equity - current_equity;
   
   if(m_session_peak_equity == 0)
      return true;
   
   double drawdown_pct = (drawdown / m_session_peak_equity) * 100.0;
   
   return (drawdown_pct < m_max_drawdown_pct);
}

//+------------------------------------------------------------------+
//| Check volatility filter                                          |
//+------------------------------------------------------------------+
bool CRiskEngine::CheckVolatilityFilter()
{
   double atr_current[];
   double atr_slow[];
   
   ArraySetAsSeries(atr_current, true);
   ArraySetAsSeries(atr_slow, true);
   
   if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_current) <= 0)
      return true; // Allow trade if can't check
   
   if(CopyBuffer(m_atr_slow_handle, 0, 0, 1, atr_slow) <= 0)
      return true;
   
   // Check if current ATR is too high compared to average
   double atr_ratio = atr_current[0] / (atr_slow[0] + 0.00001);
   
   if(atr_ratio > m_volatility_multiplier)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get session trade count                                          |
//+------------------------------------------------------------------+
int CRiskEngine::GetSessionTradeCount(int session_id)
{
   switch(session_id)
   {
      case 0: return m_asia_trade_count;
      case 1: return m_london_trade_count;
      case 2: return m_newyork_trade_count;
      default: return 0;
   }
}

//+------------------------------------------------------------------+
//| Increment session trade count                                    |
//+------------------------------------------------------------------+
void CRiskEngine::IncrementSessionTradeCount(int session_id)
{
   switch(session_id)
   {
      case 0: m_asia_trade_count++; break;
      case 1: m_london_trade_count++; break;
      case 2: m_newyork_trade_count++; break;
   }
}

//+------------------------------------------------------------------+
//| Get risk state as string                                         |
//+------------------------------------------------------------------+
string CRiskEngine::GetRiskStateString()
{
   switch(m_current_state)
   {
      case RISK_STATE_ACTIVE:              return "Active";
      case RISK_STATE_LOCKED:              return "Locked: Daily Loss";
      case RISK_STATE_COOLDOWN:            return "Cooldown";
      case RISK_STATE_DRAWDOWN:            return "Locked: Drawdown";
      case RISK_STATE_VOLATILITY:          return "High Volatility";
      case RISK_STATE_LOCKED_ONNX_FAIL:    return "Locked: ONNX Fail";
      case RISK_STATE_LOCKED_SPREAD_SPIKE: return "Locked: Spread Spike";
      case RISK_STATE_LOCKED_LATENCY:      return "Locked: High Latency";
      case RISK_STATE_LOCKED_LOSS_STREAK:  return "Locked: Loss Streak";
      default:                             return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Get current drawdown percentage                                  |
//+------------------------------------------------------------------+
double CRiskEngine::GetCurrentDrawdown()
{
   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = m_session_peak_equity - current_equity;
   
   if(m_session_peak_equity == 0)
      return 0.0;
   
   return (drawdown / m_session_peak_equity) * 100.0;
}

//+------------------------------------------------------------------+
//| Check kill-switch conditions (v11)                               |
//+------------------------------------------------------------------+
bool CRiskEngine::CheckKillSwitch()
{
   // 1. ONNX health check
   if(!g_ONNXRunner.IsModelLoaded())
   {
      Alert("🚨 KILL-SWITCH: ONNX model failed to load!");
      m_current_state = RISK_STATE_LOCKED_ONNX_FAIL;
      return false;
   }
   
   // 2. Spread spike protection
   double spread_points = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   
   if(spread_points > m_max_allowed_spread * 10.0)  // Convert pips to points
   {
      Print("🚨 KILL-SWITCH: Spread too high: ", DoubleToString(spread_points / 10.0, 1), " pips");
      m_current_state = RISK_STATE_LOCKED_SPREAD_SPIKE;
      return false;
   }
   
   // 3. Latency watchdog
   double avg_latency = g_ONNXRunner.GetAvgInferenceTime();
   if(avg_latency > m_max_inference_latency_ms)
   {
      Alert("🚨 KILL-SWITCH: AI inference too slow: ", DoubleToString(avg_latency, 1), "ms");
      m_current_state = RISK_STATE_LOCKED_LATENCY;
      return false;
   }
   
   // 4. Daily loss lock
   if(GetDailyPnL() <= -m_max_daily_loss_usd)
   {
      Alert("🚨 KILL-SWITCH: Daily loss limit reached!");
      m_current_state = RISK_STATE_LOCKED;
      return false;
   }
   
   // 5. Drawdown protection
   double current_dd = GetCurrentDrawdownPercent();
   if(current_dd >= m_max_drawdown_pct)
   {
      Alert("🚨 KILL-SWITCH: Max drawdown reached: ", DoubleToString(current_dd, 2), "%");
      m_current_state = RISK_STATE_DRAWDOWN;
      return false;
   }
   
   // 6. Loss streak protection
   if(m_consecutive_losses >= m_max_consecutive_losses)
   {
      Alert("🚨 KILL-SWITCH: Too many consecutive losses: ", m_consecutive_losses);
      m_current_state = RISK_STATE_LOCKED_LOSS_STREAK;
      return false;
   }
   
   m_current_state = RISK_STATE_ACTIVE;
   return true;
}
//+------------------------------------------------------------------+
