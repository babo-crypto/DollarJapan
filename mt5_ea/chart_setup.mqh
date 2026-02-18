//+------------------------------------------------------------------+
//|                                                 chart_setup.mqh  |
//|                                      TrendAI_v10 Chart Controller|
//|                           Institutional-Grade Chart Auto-Setup   |
//+------------------------------------------------------------------+
//| Module: Chart Setup and Configuration                            |
//| Purpose: Auto-configure chart appearance and indicators          |
//| Version: 10.0                                                     |
//| Author: TrendAI Development Team                                  |
//+------------------------------------------------------------------+

#property copyright "TrendAI Development Team"
#property version   "10.0"
#property strict

//+------------------------------------------------------------------+
//| Chart Setup Class                                                 |
//+------------------------------------------------------------------+
class CChartSetup
{
private:
   string   m_target_symbol;
   ENUM_TIMEFRAMES m_target_timeframe;
   
   // Indicator handles for chart display
   int      m_ichimoku_handle;
   int      m_atr_handle;
   int      m_adx_handle;
   
   //--- Private methods
   bool     ValidateSymbolAndTimeframe();
   bool     AttachIndicators();
   void     ConfigureChartAppearance();
   
public:
   //--- Constructor / Destructor
   CChartSetup();
   ~CChartSetup();
   
   //--- Initialization
   bool     SetupChart(string target_symbol, ENUM_TIMEFRAMES target_tf);
   void     CleanupIndicators();
   
   //--- Getters
   bool     IsCorrectSymbol() { return (_Symbol == m_target_symbol); }
   bool     IsCorrectTimeframe() { return (_Period == m_target_timeframe); }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CChartSetup::CChartSetup()
{
   m_target_symbol = "USDJPY";
   m_target_timeframe = PERIOD_M15;
   
   m_ichimoku_handle = INVALID_HANDLE;
   m_atr_handle = INVALID_HANDLE;
   m_adx_handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CChartSetup::~CChartSetup()
{
   CleanupIndicators();
}

//+------------------------------------------------------------------+
//| Setup chart with target symbol and timeframe                     |
//+------------------------------------------------------------------+
bool CChartSetup::SetupChart(string target_symbol, ENUM_TIMEFRAMES target_tf)
{
   m_target_symbol = target_symbol;
   m_target_timeframe = target_tf;
   
   Print("=== TrendAI v10 Chart Setup ===");
   Print("Target Symbol: ", m_target_symbol);
   Print("Target Timeframe: M15");
   
   // Validate current chart
   if(!ValidateSymbolAndTimeframe())
   {
      Alert("CHART SETUP ERROR: This EA must run on ", m_target_symbol, " M15 chart!");
      Print("Current chart: ", _Symbol, " ", EnumToString(_Period));
      Print("Please switch to the correct chart and reload the EA.");
      return false;
   }
   
   Print("Chart validation: OK");
   
   // Configure chart appearance
   ConfigureChartAppearance();
   Print("Chart appearance configured");
   
   // Attach indicators
   if(!AttachIndicators())
   {
      Print("WARNING: Some indicators could not be attached to chart");
      // Continue anyway - indicators will still work internally
   }
   else
   {
      Print("Indicators attached to chart successfully");
   }
   
   Print("=== Chart Setup Complete ===");
   return true;
}

//+------------------------------------------------------------------+
//| Validate symbol and timeframe                                    |
//+------------------------------------------------------------------+
bool CChartSetup::ValidateSymbolAndTimeframe()
{
   // Check symbol
   if(_Symbol != m_target_symbol)
   {
      Print("ERROR: Wrong symbol. Expected: ", m_target_symbol, ", Got: ", _Symbol);
      return false;
   }
   
   // Check timeframe
   if(_Period != m_target_timeframe)
   {
      Print("ERROR: Wrong timeframe. Expected: M15, Got: ", EnumToString(_Period));
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Attach indicators to chart window                                |
//+------------------------------------------------------------------+
bool CChartSetup::AttachIndicators()
{
   long chart_id = ChartID();
   bool all_success = true;
   
   // Attach Ichimoku indicator
   m_ichimoku_handle = iIchimoku(_Symbol, _Period, 9, 26, 52);
   if(m_ichimoku_handle != INVALID_HANDLE)
   {
      if(ChartIndicatorAdd(chart_id, 0, m_ichimoku_handle))
      {
         Print("Ichimoku indicator attached to chart");
      }
      else
      {
         Print("WARNING: Could not attach Ichimoku to chart window");
         all_success = false;
      }
   }
   
   // Attach ATR indicator to sub-window
   m_atr_handle = iATR(_Symbol, _Period, 14);
   if(m_atr_handle != INVALID_HANDLE)
   {
      if(ChartIndicatorAdd(chart_id, ChartWindowFind(chart_id, "ATR"), m_atr_handle))
      {
         Print("ATR indicator attached to chart");
      }
      else
      {
         // Try adding to new sub-window
         if(ChartIndicatorAdd(chart_id, 1, m_atr_handle))
            Print("ATR indicator attached to sub-window");
         else
         {
            Print("WARNING: Could not attach ATR to chart");
            all_success = false;
         }
      }
   }
   
   // Attach ADX indicator to sub-window
   m_adx_handle = iADX(_Symbol, _Period, 14);
   if(m_adx_handle != INVALID_HANDLE)
   {
      if(ChartIndicatorAdd(chart_id, ChartWindowFind(chart_id, "ADX"), m_adx_handle))
      {
         Print("ADX indicator attached to chart");
      }
      else
      {
         // Try adding to new sub-window
         if(ChartIndicatorAdd(chart_id, 2, m_adx_handle))
            Print("ADX indicator attached to sub-window");
         else
         {
            Print("WARNING: Could not attach ADX to chart");
            all_success = false;
         }
      }
   }
   
   ChartRedraw();
   return all_success;
}

//+------------------------------------------------------------------+
//| Configure chart appearance (dark professional theme)             |
//+------------------------------------------------------------------+
void CChartSetup::ConfigureChartAppearance()
{
   long chart_id = ChartID();
   
   // Set dark theme colors (institutional style)
   ChartSetInteger(chart_id, CHART_COLOR_BACKGROUND, C'20,22,28');       // Dark background
   ChartSetInteger(chart_id, CHART_COLOR_FOREGROUND, C'220,220,220');    // Light foreground
   ChartSetInteger(chart_id, CHART_COLOR_GRID, C'40,42,48');             // Subtle grid
   ChartSetInteger(chart_id, CHART_COLOR_CHART_UP, C'46,204,113');       // Bullish candles
   ChartSetInteger(chart_id, CHART_COLOR_CHART_DOWN, C'231,76,60');      // Bearish candles
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BULL, C'46,204,113');    
   ChartSetInteger(chart_id, CHART_COLOR_CANDLE_BEAR, C'231,76,60');     
   ChartSetInteger(chart_id, CHART_COLOR_CHART_LINE, C'220,220,220');    
   ChartSetInteger(chart_id, CHART_COLOR_VOLUME, C'100,100,100');        // Volume bars
   ChartSetInteger(chart_id, CHART_COLOR_BID, C'149,165,166');           
   ChartSetInteger(chart_id, CHART_COLOR_ASK, C'149,165,166');           
   
   // Set chart mode to candlesticks
   ChartSetInteger(chart_id, CHART_MODE, CHART_CANDLES);
   
   // Enable price grid
   ChartSetInteger(chart_id, CHART_SHOW_GRID, true);
   
   // Show OHLC values
   ChartSetInteger(chart_id, CHART_SHOW_OHLC, true);
   
   // Show period separators
   ChartSetInteger(chart_id, CHART_SHOW_PERIOD_SEP, true);
   
   // Enable autoscroll
   ChartSetInteger(chart_id, CHART_AUTOSCROLL, true);
   
   // Show trade levels
   ChartSetInteger(chart_id, CHART_SHOW_TRADE_LEVELS, true);
   
   // Enable one-click trading panel
   ChartSetInteger(chart_id, CHART_SHOW_ONE_CLICK, false); // Disabled for safety
   
   // Set shift to show some space on the right
   ChartSetInteger(chart_id, CHART_SHIFT, true);
   
   // Zoom level (0-5, where 0 is maximum zoom out)
   ChartSetInteger(chart_id, CHART_SCALE, 2);
   
   // Set chart to be on top when activated
   ChartSetInteger(chart_id, CHART_BRING_TO_TOP, true);
   
   Print("Chart appearance configured with professional dark theme");
}

//+------------------------------------------------------------------+
//| Cleanup indicator handles                                        |
//+------------------------------------------------------------------+
void CChartSetup::CleanupIndicators()
{
   if(m_ichimoku_handle != INVALID_HANDLE)
   {
      ChartIndicatorDelete(ChartID(), 0, ChartIndicatorName(ChartID(), 0, 0));
      IndicatorRelease(m_ichimoku_handle);
      m_ichimoku_handle = INVALID_HANDLE;
   }
   
   if(m_atr_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_atr_handle);
      m_atr_handle = INVALID_HANDLE;
   }
   
   if(m_adx_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_adx_handle);
      m_adx_handle = INVALID_HANDLE;
   }
}
//+------------------------------------------------------------------+
