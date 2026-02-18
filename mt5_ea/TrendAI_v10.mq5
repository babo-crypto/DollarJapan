//+------------------------------------------------------------------+
//|                                                  TrendAI_v10.mq5 |
//|                                      TrendAI v10 PRO Expert Advisor |
//|                           Institutional-Grade Trading System     |
//+------------------------------------------------------------------+
//| EA: TrendAI v10 USDJPY M15 Professional                          |
//| Architecture: Ichimoku + ONNX ML + Risk Engine + Dashboard       |
//| Symbol: USDJPY ONLY                                               |
//| Timeframe: M15 ONLY                                               |
//| Version: 10.0                                                     |
//| Author: TrendAI Development Team                                  |
//+------------------------------------------------------------------+

#property copyright "TrendAI Development Team"
#property link      "https://github.com/babo-crypto/DollarJapan"
#property version   "10.0"
#property description "Professional institutional trading system"
#property description "Ichimoku directional bias + ONNX ML timing + Risk management"
#property description "USDJPY M15 ONLY - Fixed lot 0.01"
#property strict

// Include all modules
#include "feature_builder.mqh"
#include "onnx_runner.mqh"
#include "risk_engine.mqh"
#include "dashboard_ui.mqh"
#include "telemetry_panel.mqh"
#include "ai_overlay.mqh"
#include "chart_setup.mqh"

//+------------------------------------------------------------------+
//| AI Confidence Level Enumeration (v11)                            |
//+------------------------------------------------------------------+
enum CONFIDENCE_LEVEL {
   CONFIDENCE_NONE,
   CONFIDENCE_LOW,
   CONFIDENCE_MEDIUM,
   CONFIDENCE_HIGH
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

// === Risk Management Parameters ===
input group "=== RISK MANAGEMENT ==="
input double   InpFixedLotSize = 0.01;                   // Fixed Lot Size (DO NOT CHANGE)
input int      InpMaxTradesPerSession = 3;               // Max Trades Per Session
input double   InpDailyLossLimitPct = 3.0;               // Daily Loss Limit (%)
input double   InpMaxSpreadPips = 3.0;                   // Max Spread (pips)
input int      InpCooldownCandles = 4;                   // Cooldown After Loss (candles)
input double   InpMaxDrawdownPct = 8.0;                  // Max Drawdown (%)
input double   InpVolatilityMultiplier = 2.0;            // Volatility Filter (ATR multiplier)

// === ML Model Parameters ===
input group "=== ML MODEL ==="
input string   InpModelPath = "models/trendai_v10.onnx"; // ONNX Model Path
input string   InpScalerPath = "models/scaler.json";     // Scaler Path
input double   InpMinProbability = 0.72;                 // Min Probability Threshold

// === AI Confidence Parameters (v11) ===
input group "=== AI CONFIDENCE ==="
input double   InpMinConfidenceLow    = 0.72;   // Minimum confidence (skip below)
input double   InpConfidenceMedium    = 0.80;   // Medium confidence threshold
input double   InpConfidenceHigh      = 0.90;   // High confidence threshold

// === Trading Parameters ===
input group "=== TRADING LOGIC ==="
input double   InpSLMultiplier = 1.5;                    // Stop Loss (ATR multiplier)
input double   InpTPRatio = 1.5;                         // Take Profit Ratio (vs SL)
input bool     InpUseTrailingStop = true;                // Use Trailing Stop (Kijun)
input int      InpMagicNumber = 100710;                  // Magic Number

// === UI Parameters ===
input group "=== DASHBOARD ==="
input bool     InpShowDashboard = true;                  // Show Dashboard
input bool     InpShowTelemetry = true;                  // Show Telemetry Panel
input bool     InpShowAIOverlay = true;                  // Show AI Overlays
input int      InpDashboardX = 20;                       // Dashboard X Position
input int      InpDashboardY = 50;                       // Dashboard Y Position

// === Session Parameters ===
input group "=== SESSION FILTERS ==="
input bool     InpTradeAsia = true;                      // Trade Asia Session
input bool     InpTradeLondon = true;                    // Trade London Session
input bool     InpTradeNewYork = true;                   // Trade New York Session

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+

// Module instances
CFeatureBuilder   g_FeatureBuilder;
CONNXRunner       g_ONNXRunner;
CRiskEngine       g_RiskEngine;
CDashboardUI      g_Dashboard;
CTelemetryPanel   g_Telemetry;
CAIOverlay        g_AIOverlay;
CChartSetup       g_ChartSetup;

// State tracking
datetime          g_last_bar_time = 0;
bool              g_initialization_success = false;
int               g_total_wins = 0;
int               g_total_losses = 0;
double            g_total_profit = 0.0;

// Trade tracking
ulong             g_current_ticket = 0;
datetime          g_trade_open_time = 0;

// AI Confidence tracking (v11)
CONFIDENCE_LEVEL  g_current_confidence = CONFIDENCE_NONE;
double            g_current_probability = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("==========================================================");
   Print("          TrendAI v10 PRO - Initialization Start         ");
   Print("==========================================================");
   
   // Setup chart first
   if(!g_ChartSetup.SetupChart("USDJPY", PERIOD_M15))
   {
      Alert("CRITICAL: Chart setup failed. EA will not trade.");
      return INIT_FAILED;
   }
   
   // Initialize feature builder
   if(!g_FeatureBuilder.Initialize(_Symbol, _Period))
   {
      Print("ERROR: Feature builder initialization failed");
      return INIT_FAILED;
   }
   Print("✓ Feature Builder initialized");
   
   // Initialize ONNX runner
   if(!g_ONNXRunner.LoadModel(InpModelPath, InpScalerPath))
   {
      Print("WARNING: ONNX model not loaded. EA will run without ML predictions.");
      Print("To enable ML predictions, run Python training scripts to generate the model.");
      // Continue without ML - can still use Ichimoku signals
   }
   else
   {
      Print("✓ ONNX Model loaded successfully");
   }
   
   // Initialize risk engine
   if(!g_RiskEngine.Initialize(_Symbol, _Period))
   {
      Print("ERROR: Risk engine initialization failed");
      return INIT_FAILED;
   }
   
   // Configure risk engine
   g_RiskEngine.SetFixedLotSize(InpFixedLotSize);
   g_RiskEngine.SetMaxTradesPerSession(InpMaxTradesPerSession);
   g_RiskEngine.SetDailyLossLimit(InpDailyLossLimitPct);
   g_RiskEngine.SetMaxSpread(InpMaxSpreadPips);
   g_RiskEngine.SetCooldownCandles(InpCooldownCandles);
   g_RiskEngine.SetMaxDrawdown(InpMaxDrawdownPct);
   g_RiskEngine.SetVolatilityMultiplier(InpVolatilityMultiplier);
   Print("✓ Risk Engine configured");
   
   // Initialize UI components
   if(InpShowDashboard)
   {
      g_Dashboard.Initialize(InpDashboardX, InpDashboardY, 280, 320);
      Print("✓ Dashboard initialized");
   }
   
   if(InpShowTelemetry)
   {
      g_Telemetry.Initialize(InpDashboardX, InpDashboardY + 340, 280, 220);
      Print("✓ Telemetry panel initialized");
   }
   
   if(InpShowAIOverlay)
   {
      g_AIOverlay.Initialize();
      Print("✓ AI Overlay initialized");
   }
   
   g_initialization_success = true;
   g_last_bar_time = iTime(_Symbol, _Period, 0);
   
   Print("==========================================================");
   Print("     TrendAI v10 PRO - Initialization Complete ✓         ");
   Print("     System Status: ACTIVE                               ");
   Print("     Symbol: ", _Symbol, " | Timeframe: M15              ");
   Print("     Fixed Lot: ", InpFixedLotSize, " | Magic: ", InpMagicNumber);
   Print("==========================================================");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("TrendAI v10 - Deinitialization");
   
   // Cleanup modules
   g_FeatureBuilder.Deinitialize();
   g_ONNXRunner.UnloadModel();
   g_RiskEngine.Deinitialize();
   g_Dashboard.Destroy();
   g_Telemetry.Destroy();
   g_AIOverlay.Destroy();
   g_ChartSetup.CleanupIndicators();
   
   Print("Deinitialization complete. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initialization_success)
      return;
   
   // Check for new bar
   datetime current_bar_time = iTime(_Symbol, _Period, 0);
   bool new_bar = (current_bar_time != g_last_bar_time);
   
   if(new_bar)
   {
      g_last_bar_time = current_bar_time;
      g_RiskEngine.OnNewCandle();
   }
   
   // Update dashboard on every tick
   UpdateDashboard();
   
   // Update telemetry
   if(InpShowTelemetry)
      UpdateTelemetry();
   
   // Manage existing positions
   ManageOpenPositions();
   
   // Only check for new signals on new bar
   if(new_bar)
   {
      CheckForTradingSignals();
   }
}

//+------------------------------------------------------------------+
//| Check for trading signals                                         |
//+------------------------------------------------------------------+
void CheckForTradingSignals()
{
   // Don't open new trade if already in position
   if(PositionSelect(_Symbol))
      return;
   
   // Build feature vector
   double features[];
   if(!g_FeatureBuilder.BuildFeatures(features))
   {
      return;
   }
   
   // Get ONNX prediction
   double probability = 0.0;
   if(g_ONNXRunner.IsModelLoaded())
   {
      probability = g_ONNXRunner.Predict(features);
   }
   else
   {
      // Without ML model, use Ichimoku only with lower threshold
      probability = 0.75; // Default high confidence for Ichimoku-only signals
   }
   
   // Evaluate confidence (v11)
   CONFIDENCE_LEVEL confidence = EvaluateConfidence(probability);
   
   // Store for dashboard display
   g_current_confidence = confidence;
   g_current_probability = probability;
   
   // Decision logic - skip if confidence too low (v11)
   if(confidence == CONFIDENCE_NONE)
   {
      // Skip trade - confidence too low
      return;
   }
   
   // Get current market conditions
   double spread_pips = g_FeatureBuilder.GetSpread();
   int session_id = (int)g_FeatureBuilder.GetSessionID();
   
   // Check if session is allowed
   if(!IsSessionAllowed(session_id))
      return;
   
   // Check kill-switch before execution (v11)
   if(!g_RiskEngine.CheckKillSwitch(g_ONNXRunner))
   {
      Print("Trade blocked by kill-switch: ", g_RiskEngine.GetRiskStateString());
      return;
   }
   
   // Check risk engine permission
   if(!g_RiskEngine.AllowTrade(session_id, spread_pips))
      return;
   
   // Determine directional bias using Ichimoku
   int signal_direction = GetIchimokuBias();
   
   // Check ML probability threshold
   if(probability < InpMinProbability)
      return;
   
   // Execute trade based on signal with confidence-adjusted parameters (v11)
   if(signal_direction == 1) // Buy signal
   {
      ExecuteBuyOrder(probability, confidence);
   }
   else if(signal_direction == -1) // Sell signal
   {
      ExecuteSellOrder(probability, confidence);
   }
}

//+------------------------------------------------------------------+
//| Get Ichimoku directional bias                                    |
//+------------------------------------------------------------------+
int GetIchimokuBias()
{
   double close = iClose(_Symbol, _Period, 0);
   double price_kumo_dist = g_FeatureBuilder.GetPriceKumoDistance();
   double tenkan_slope = g_FeatureBuilder.GetTenkanSlope();
   double kijun_slope = g_FeatureBuilder.GetKijunSlope();
   
   // BUY: Price above cloud AND Tenkan > Kijun (both positive slopes)
   if(price_kumo_dist > 0.1 && tenkan_slope > kijun_slope && tenkan_slope > 0)
   {
      return 1; // Bullish
   }
   
   // SELL: Price below cloud AND Tenkan < Kijun (both negative slopes)
   if(price_kumo_dist < -0.1 && tenkan_slope < kijun_slope && tenkan_slope < 0)
   {
      return -1; // Bearish
   }
   
   return 0; // Neutral
}

//+------------------------------------------------------------------+
//| Execute buy order                                                 |
//+------------------------------------------------------------------+
void ExecuteBuyOrder(double probability, CONFIDENCE_LEVEL confidence)
{
   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr = g_FeatureBuilder.GetATRNormalized() * entry_price / 10000.0;
   
   // Confidence-based SL/TP adjustments (v11)
   double sl_multiplier = InpSLMultiplier;
   double tp_multiplier = InpTPRatio;
   
   if(confidence == CONFIDENCE_LOW)
   {
      sl_multiplier *= 0.8;  // Tighter SL
      tp_multiplier *= 1.2;  // Wider TP (better R:R required)
   }
   else if(confidence == CONFIDENCE_HIGH)
   {
      tp_multiplier *= 1.5;  // Let winners run
   }
   
   // Calculate SL and TP
   double sl = entry_price - (atr * sl_multiplier);
   double tp = entry_price + (atr * sl_multiplier * tp_multiplier);
   
   // Normalize prices
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = InpFixedLotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = entry_price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = InpMagicNumber;
   request.comment = StringFormat("TrendAI_BUY_P%.0f", probability * 100);
   
   // Send order
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         g_current_ticket = result.order;
         g_trade_open_time = TimeCurrent();
         
         int session_id = (int)g_FeatureBuilder.GetSessionID();
         g_RiskEngine.OnTradeOpened(session_id, entry_price);
         
         Print("✓ BUY order executed. Ticket: ", result.order, " | Probability: ", probability);
         
         // Draw AI signal
         if(InpShowAIOverlay)
         {
            g_AIOverlay.DrawBuySignal(iTime(_Symbol, _Period, 0), entry_price, probability);
         }
      }
      else
      {
         Print("Order failed. Return code: ", result.retcode);
      }
   }
}

//+------------------------------------------------------------------+
//| Execute sell order                                                |
//+------------------------------------------------------------------+
void ExecuteSellOrder(double probability, CONFIDENCE_LEVEL confidence)
{
   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = g_FeatureBuilder.GetATRNormalized() * entry_price / 10000.0;
   
   // Confidence-based SL/TP adjustments (v11)
   double sl_multiplier = InpSLMultiplier;
   double tp_multiplier = InpTPRatio;
   
   if(confidence == CONFIDENCE_LOW)
   {
      sl_multiplier *= 0.8;  // Tighter SL
      tp_multiplier *= 1.2;  // Wider TP (better R:R required)
   }
   else if(confidence == CONFIDENCE_HIGH)
   {
      tp_multiplier *= 1.5;  // Let winners run
   }
   
   // Calculate SL and TP
   double sl = entry_price + (atr * sl_multiplier);
   double tp = entry_price - (atr * sl_multiplier * tp_multiplier);
   
   // Normalize prices
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = InpFixedLotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = entry_price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = InpMagicNumber;
   request.comment = StringFormat("TrendAI_SELL_P%.0f", probability * 100);
   
   // Send order
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         g_current_ticket = result.order;
         g_trade_open_time = TimeCurrent();
         
         int session_id = (int)g_FeatureBuilder.GetSessionID();
         g_RiskEngine.OnTradeOpened(session_id, entry_price);
         
         Print("✓ SELL order executed. Ticket: ", result.order, " | Probability: ", probability);
         
         // Draw AI signal
         if(InpShowAIOverlay)
         {
            g_AIOverlay.DrawSellSignal(iTime(_Symbol, _Period, 0), entry_price, probability);
         }
      }
      else
      {
         Print("Order failed. Return code: ", result.retcode);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage open positions                                             |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   if(!PositionSelect(_Symbol))
      return;
   
   // Get position info
   ulong ticket = PositionGetInteger(POSITION_TICKET);
   double profit = PositionGetDouble(POSITION_PROFIT);
   
   // Implement trailing stop using Kijun if enabled
   if(InpUseTrailingStop)
   {
      // Get position type
      long position_type = PositionGetInteger(POSITION_TYPE);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_price = (position_type == POSITION_TYPE_BUY) ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      // Get Kijun-sen value for trailing
      double kijun = 0.0;
      int handle = iIchimoku(_Symbol, _Period, 9, 26, 52);
      if(handle != INVALID_HANDLE)
      {
         double kijun_buffer[];
         ArraySetAsSeries(kijun_buffer, true);
         if(CopyBuffer(handle, 1, 0, 1, kijun_buffer) > 0)
         {
            kijun = kijun_buffer[0];
         }
         IndicatorRelease(handle);
      }
      
      // Apply trailing logic
      if(kijun > 0)
      {
         bool should_modify = false;
         double new_sl = current_sl;
         
         if(position_type == POSITION_TYPE_BUY)
         {
            // For buy: move SL up to Kijun if Kijun is above current SL
            if(kijun > current_sl && kijun < current_price)
            {
               new_sl = kijun;
               should_modify = true;
            }
         }
         else // SELL
         {
            // For sell: move SL down to Kijun if Kijun is below current SL
            if(kijun < current_sl && kijun > current_price)
            {
               new_sl = kijun;
               should_modify = true;
            }
         }
         
         // Modify stop loss if needed
         if(should_modify)
         {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_SLTP;
            request.symbol = _Symbol;
            request.position = ticket;
            request.sl = NormalizeDouble(new_sl, _Digits);
            request.tp = PositionGetDouble(POSITION_TP);
            
            if(OrderSend(request, result))
            {
               if(result.retcode == TRADE_RETCODE_DONE)
               {
                  Print("✓ Trailing stop updated to Kijun: ", new_sl);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if session is allowed for trading                          |
//+------------------------------------------------------------------+
bool IsSessionAllowed(int session_id)
{
   switch(session_id)
   {
      case 0: return InpTradeAsia;
      case 1: return InpTradeLondon;
      case 2: return InpTradeNewYork;
      default: return false;
   }
}

//+------------------------------------------------------------------+
//| Update dashboard                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!InpShowDashboard)
      return;
   
   // Get current feature data
   double probability = 0.0;
   if(g_ONNXRunner.IsModelLoaded())
   {
      double features[];
      if(g_FeatureBuilder.BuildFeatures(features))
      {
         probability = g_ONNXRunner.Predict(features);
      }
   }
   
   // Get market data
   string session_name = GetSessionName((int)g_FeatureBuilder.GetSessionID());
   double spread = g_FeatureBuilder.GetSpread();
   double adx = g_FeatureBuilder.GetADX();
   string cloud_status = GetCloudStatus();
   bool trading_window = IsSessionAllowed((int)g_FeatureBuilder.GetSessionID());
   int trade_count = g_RiskEngine.GetTodayTradeCount();
   string risk_status = g_RiskEngine.GetRiskStateString();
   
   // Update dashboard
   g_Dashboard.Update(_Symbol, "M15", session_name, probability, spread, adx,
                      cloud_status, trading_window, trade_count, risk_status,
                      g_current_confidence, g_current_probability, g_RiskEngine);
}

//+------------------------------------------------------------------+
//| Update telemetry panel                                            |
//+------------------------------------------------------------------+
void UpdateTelemetry()
{
   double today_pnl = g_RiskEngine.GetTodayPnL();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double drawdown = g_RiskEngine.GetCurrentDrawdown();
   
   g_Telemetry.UpdateTodayPnL(today_pnl, balance);
   g_Telemetry.UpdateWinrate(g_total_wins, g_total_losses);
   g_Telemetry.UpdateDrawdown(drawdown);
   g_Telemetry.Refresh();
}

//+------------------------------------------------------------------+
//| Get session name                                                  |
//+------------------------------------------------------------------+
string GetSessionName(int session_id)
{
   switch(session_id)
   {
      case 0: return "ASIA";
      case 1: return "LONDON";
      case 2: return "NEWYORK";
      default: return "OFF";
   }
}

//+------------------------------------------------------------------+
//| Get cloud status                                                  |
//+------------------------------------------------------------------+
string GetCloudStatus()
{
   double price_kumo_dist = g_FeatureBuilder.GetPriceKumoDistance();
   
   if(price_kumo_dist > 0.1)
      return "ABOVE";
   else if(price_kumo_dist < -0.1)
      return "BELOW";
   else
      return "INSIDE";
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                         |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Track closed trades for statistics
   if(HistorySelect(0, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      if(total > 0)
      {
         ulong ticket = HistoryDealGetTicket(total - 1);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            
            if(profit != 0)
            {
               g_RiskEngine.OnTradeClosed(profit);
               g_total_profit += profit;
               
               if(profit > 0)
                  g_total_wins++;
               else
                  g_total_losses++;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Evaluate AI confidence level (v11)                               |
//+------------------------------------------------------------------+
CONFIDENCE_LEVEL EvaluateConfidence(double probability)
{
   if(probability < InpMinConfidenceLow)
      return CONFIDENCE_NONE;
   else if(probability >= InpMinConfidenceLow && probability < InpConfidenceMedium)
      return CONFIDENCE_LOW;
   else if(probability >= InpConfidenceMedium && probability < InpConfidenceHigh)
      return CONFIDENCE_MEDIUM;
   else
      return CONFIDENCE_HIGH;
}
//+------------------------------------------------------------------+
