//+------------------------------------------------------------------+
//|                                                 dashboard_ui.mqh |
//|                                      TrendAI_v10 Dashboard Panel |
//|                           Institutional-Grade Visual Intelligence |
//+------------------------------------------------------------------+
//| Module: Dashboard UI Layer                                       |
//| Purpose: Professional trading dashboard display                  |
//| Version: 10.0                                                     |
//| Author: TrendAI Development Team                                  |
//+------------------------------------------------------------------+

#property copyright "TrendAI Development Team"
#property version   "10.0"
#property strict

//+------------------------------------------------------------------+
//| Dashboard UI Class                                                |
//+------------------------------------------------------------------+
class CDashboardUI
{
private:
   // Panel configuration
   int      m_panel_x;
   int      m_panel_y;
   int      m_panel_width;
   int      m_panel_height;
   color    m_bg_color;
   color    m_text_color;
   color    m_bullish_color;
   color    m_bearish_color;
   color    m_neutral_color;
   
   // Object name prefix
   string   m_prefix;
   
   // Display data
   string   m_symbol;
   string   m_timeframe;
   string   m_session_name;
   double   m_onnx_probability;
   string   m_ai_confidence;
   double   m_spread;
   double   m_adx;
   string   m_cloud_status;
   bool     m_trading_window_open;
   int      m_daily_trade_count;
   string   m_risk_status;
   
   //--- Private methods
   void     CreateBackground();
   void     CreateLabel(string name, int x, int y, string text, color clr, int font_size = 9);
   void     UpdateLabel(string name, string text, color clr);
   string   GetConfidenceLevel(double probability);
   color    GetProbabilityColor(double probability);
   
public:
   //--- Constructor / Destructor
   CDashboardUI();
   ~CDashboardUI();
   
   //--- Initialization
   bool     Initialize(int x, int y, int width, int height);
   void     Destroy();
   
   //--- Update methods
   void     Update(string symbol, string timeframe, string session, 
                   double probability, double spread, double adx,
                   string cloud_status, bool trading_window, 
                   int trade_count, string risk_status);
   
   //--- Configuration
   void     SetPosition(int x, int y);
   void     SetColors(color bg, color text, color bullish, color bearish, color neutral);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CDashboardUI::CDashboardUI()
{
   m_panel_x = 20;
   m_panel_y = 50;
   m_panel_width = 280;
   m_panel_height = 320;
   
   // Professional dark theme colors
   m_bg_color = C'20,22,28';          // Dark charcoal
   m_text_color = C'220,220,220';     // Light gray text
   m_bullish_color = C'46,204,113';   // Professional green
   m_bearish_color = C'231,76,60';    // Professional red
   m_neutral_color = C'149,165,166';  // Gray
   
   m_prefix = "TrendAI_Dashboard_";
   
   m_symbol = "";
   m_timeframe = "";
   m_session_name = "OFF";
   m_onnx_probability = 0.0;
   m_ai_confidence = "LOW";
   m_spread = 0.0;
   m_adx = 0.0;
   m_cloud_status = "NEUTRAL";
   m_trading_window_open = false;
   m_daily_trade_count = 0;
   m_risk_status = "ACTIVE";
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CDashboardUI::~CDashboardUI()
{
   Destroy();
}

//+------------------------------------------------------------------+
//| Initialize dashboard                                              |
//+------------------------------------------------------------------+
bool CDashboardUI::Initialize(int x, int y, int width, int height)
{
   m_panel_x = x;
   m_panel_y = y;
   m_panel_width = width;
   m_panel_height = height;
   
   // Create background panel
   CreateBackground();
   
   // Create header
   CreateLabel("Header", 10, 10, "TrendAI v10 PRO", clrWhite, 12);
   CreateLabel("Subtitle", 10, 30, "INSTITUTIONAL TRADING SYSTEM", m_neutral_color, 8);
   
   // Create data labels
   int y_offset = 60;
   int line_height = 25;
   
   CreateLabel("SymbolLabel", 10, y_offset, "Symbol:", m_text_color, 9);
   CreateLabel("SymbolValue", 150, y_offset, "---", clrWhite, 9);
   y_offset += line_height;
   
   CreateLabel("SessionLabel", 10, y_offset, "Session:", m_text_color, 9);
   CreateLabel("SessionValue", 150, y_offset, "---", m_neutral_color, 9);
   y_offset += line_height;
   
   CreateLabel("ProbLabel", 10, y_offset, "AI Probability:", m_text_color, 9);
   CreateLabel("ProbValue", 150, y_offset, "0.0%", m_neutral_color, 10);
   y_offset += line_height;
   
   CreateLabel("ConfLabel", 10, y_offset, "Confidence:", m_text_color, 9);
   CreateLabel("ConfValue", 150, y_offset, "LOW", m_neutral_color, 9);
   y_offset += line_height;
   
   CreateLabel("SpreadLabel", 10, y_offset, "Spread:", m_text_color, 9);
   CreateLabel("SpreadValue", 150, y_offset, "0.0", m_neutral_color, 9);
   y_offset += line_height;
   
   CreateLabel("ADXLabel", 10, y_offset, "ADX Strength:", m_text_color, 9);
   CreateLabel("ADXValue", 150, y_offset, "0.0", m_neutral_color, 9);
   y_offset += line_height;
   
   CreateLabel("CloudLabel", 10, y_offset, "Cloud Status:", m_text_color, 9);
   CreateLabel("CloudValue", 150, y_offset, "NEUTRAL", m_neutral_color, 9);
   y_offset += line_height;
   
   CreateLabel("WindowLabel", 10, y_offset, "Trading Window:", m_text_color, 9);
   CreateLabel("WindowValue", 150, y_offset, "NO", m_bearish_color, 9);
   y_offset += line_height;
   
   CreateLabel("CountLabel", 10, y_offset, "Daily Trades:", m_text_color, 9);
   CreateLabel("CountValue", 150, y_offset, "0", m_neutral_color, 9);
   y_offset += line_height;
   
   CreateLabel("RiskLabel", 10, y_offset, "Risk Status:", m_text_color, 9);
   CreateLabel("RiskValue", 150, y_offset, "ACTIVE", m_bullish_color, 9);
   
   ChartRedraw();
   Print("Dashboard initialized at position (", x, ", ", y, ")");
   
   return true;
}

//+------------------------------------------------------------------+
//| Destroy all dashboard objects                                    |
//+------------------------------------------------------------------+
void CDashboardUI::Destroy()
{
   // Delete all objects with our prefix
   int total = ObjectsTotal(0, 0, OBJ_LABEL) + ObjectsTotal(0, 0, OBJ_RECTANGLE_LABEL);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string obj_name = ObjectName(0, i);
      if(StringFind(obj_name, m_prefix) >= 0)
      {
         ObjectDelete(0, obj_name);
      }
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create background panel                                           |
//+------------------------------------------------------------------+
void CDashboardUI::CreateBackground()
{
   string obj_name = m_prefix + "Background";
   
   // Create semi-transparent rectangle
   if(ObjectCreate(0, obj_name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, m_panel_x);
      ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, m_panel_y);
      ObjectSetInteger(0, obj_name, OBJPROP_XSIZE, m_panel_width);
      ObjectSetInteger(0, obj_name, OBJPROP_YSIZE, m_panel_height);
      ObjectSetInteger(0, obj_name, OBJPROP_BGCOLOR, m_bg_color);
      ObjectSetInteger(0, obj_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Create text label                                                 |
//+------------------------------------------------------------------+
void CDashboardUI::CreateLabel(string name, int x, int y, string text, color clr, int font_size = 9)
{
   string obj_name = m_prefix + name;
   
   if(ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, m_panel_x + x);
      ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, m_panel_y + y);
      ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, font_size);
      ObjectSetString(0, obj_name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Update existing label                                             |
//+------------------------------------------------------------------+
void CDashboardUI::UpdateLabel(string name, string text, color clr)
{
   string obj_name = m_prefix + name;
   
   if(ObjectFind(0, obj_name) >= 0)
   {
      ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
   }
}

//+------------------------------------------------------------------+
//| Update all dashboard data                                         |
//+------------------------------------------------------------------+
void CDashboardUI::Update(string symbol, string timeframe, string session,
                          double probability, double spread, double adx,
                          string cloud_status, bool trading_window,
                          int trade_count, string risk_status)
{
   // Update internal state
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_session_name = session;
   m_onnx_probability = probability;
   m_spread = spread;
   m_adx = adx;
   m_cloud_status = cloud_status;
   m_trading_window_open = trading_window;
   m_daily_trade_count = trade_count;
   m_risk_status = risk_status;
   
   // Derive confidence level
   m_ai_confidence = GetConfidenceLevel(probability);
   
   // Update UI elements
   UpdateLabel("SymbolValue", symbol + " / " + timeframe, clrWhite);
   
   // Session color coding
   color session_color = m_neutral_color;
   if(session == "ASIA") session_color = C'100,149,237'; // Cornflower blue
   else if(session == "LONDON") session_color = C'255,165,0'; // Orange
   else if(session == "NEWYORK") session_color = C'220,20,60'; // Crimson
   UpdateLabel("SessionValue", session, session_color);
   
   // Probability with color coding
   color prob_color = GetProbabilityColor(probability);
   UpdateLabel("ProbValue", StringFormat("%.1f%%", probability * 100), prob_color);
   
   // Confidence
   color conf_color = m_neutral_color;
   if(m_ai_confidence == "HIGH") conf_color = m_bullish_color;
   else if(m_ai_confidence == "MEDIUM") conf_color = C'241,196,15'; // Yellow
   UpdateLabel("ConfValue", m_ai_confidence, conf_color);
   
   // Spread
   color spread_color = (spread <= 3.0) ? m_bullish_color : m_bearish_color;
   UpdateLabel("SpreadValue", StringFormat("%.1f pips", spread), spread_color);
   
   // ADX
   color adx_color = m_neutral_color;
   if(adx > 25) adx_color = m_bullish_color;
   else if(adx < 20) adx_color = m_bearish_color;
   UpdateLabel("ADXValue", StringFormat("%.1f", adx), adx_color);
   
   // Cloud status
   color cloud_color = m_neutral_color;
   if(cloud_status == "ABOVE") cloud_color = m_bullish_color;
   else if(cloud_status == "BELOW") cloud_color = m_bearish_color;
   UpdateLabel("CloudValue", cloud_status, cloud_color);
   
   // Trading window
   color window_color = trading_window ? m_bullish_color : m_bearish_color;
   string window_text = trading_window ? "YES" : "NO";
   UpdateLabel("WindowValue", window_text, window_color);
   
   // Trade count
   UpdateLabel("CountValue", IntegerToString(trade_count), m_text_color);
   
   // Risk status
   color risk_color = m_bullish_color;
   if(risk_status == "LOCKED" || risk_status == "DRAWDOWN") risk_color = m_bearish_color;
   else if(risk_status == "COOLDOWN") risk_color = C'241,196,15';
   UpdateLabel("RiskValue", risk_status, risk_color);
}

//+------------------------------------------------------------------+
//| Get confidence level from probability                            |
//+------------------------------------------------------------------+
string CDashboardUI::GetConfidenceLevel(double probability)
{
   if(probability >= 0.80)
      return "HIGH";
   else if(probability >= 0.65)
      return "MEDIUM";
   else
      return "LOW";
}

//+------------------------------------------------------------------+
//| Get color for probability display                                |
//+------------------------------------------------------------------+
color CDashboardUI::GetProbabilityColor(double probability)
{
   if(probability >= 0.80)
      return m_bullish_color;
   else if(probability >= 0.65)
      return C'241,196,15'; // Yellow
   else if(probability >= 0.50)
      return m_neutral_color;
   else
      return m_bearish_color;
}

//+------------------------------------------------------------------+
//| Set panel position                                                |
//+------------------------------------------------------------------+
void CDashboardUI::SetPosition(int x, int y)
{
   m_panel_x = x;
   m_panel_y = y;
   
   // Reinitialize to apply new position
   Destroy();
   Initialize(x, y, m_panel_width, m_panel_height);
}

//+------------------------------------------------------------------+
//| Set color scheme                                                  |
//+------------------------------------------------------------------+
void CDashboardUI::SetColors(color bg, color text, color bullish, color bearish, color neutral)
{
   m_bg_color = bg;
   m_text_color = text;
   m_bullish_color = bullish;
   m_bearish_color = bearish;
   m_neutral_color = neutral;
}
//+------------------------------------------------------------------+
