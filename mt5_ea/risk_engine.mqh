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
   RISK_STATE_ACTIVE = 0,     // Normal trading allowed
   RISK_STATE_LOCKED = 1,     // Daily loss limit reached
   RISK_STATE_COOLDOWN = 2,   // Cooldown period after loss
   RISK_STATE_DRAWDOWN = 3,   // Maximum drawdown exceeded
   RISK_STATE_VOLATILITY = 4  // Excessive volatility detected
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
   
   // If loss, start cooldown
   if(profit_loss < 0)
   {
      m_last_loss_time = TimeCurrent();
      m_cooldown_remaining = m_cooldown_candles;
      m_current_state = RISK_STATE_COOLDOWN;
      
      Print("Trade closed with loss: ", profit_loss, ". Cooldown started: ", m_cooldown_candles, " candles");
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
      case RISK_STATE_ACTIVE:     return "Active";
      case RISK_STATE_LOCKED:     return "Locked";
      case RISK_STATE_COOLDOWN:   return "Cooldown";
      case RISK_STATE_DRAWDOWN:   return "Drawdown";
      case RISK_STATE_VOLATILITY: return "High Volatility";
      default:                    return "Unknown";
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
