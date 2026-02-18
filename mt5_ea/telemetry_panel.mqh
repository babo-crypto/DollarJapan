//+------------------------------------------------------------------+
//|                                             telemetry_panel.mqh |
//|                                      TrendAI_v10 Performance Metrics |
//|                           Institutional-Grade Telemetry Display  |
//+------------------------------------------------------------------+
//| Module: Telemetry Panel                                          |
//| Purpose: Display real-time performance statistics                |
//| Version: 10.0                                                     |
//| Author: TrendAI Development Team                                  |
//+------------------------------------------------------------------+

#property copyright "TrendAI Development Team"
#property version   "10.0"
#property strict

//+------------------------------------------------------------------+
//| Telemetry Panel Class                                             |
//+------------------------------------------------------------------+
class CTelemetryPanel
{
private:
   // Panel configuration
   int      m_panel_x;
   int      m_panel_y;
   int      m_panel_width;
   int      m_panel_height;
   color    m_bg_color;
   color    m_text_color;
   color    m_positive_color;
   color    m_negative_color;
   
   // Object name prefix
   string   m_prefix;
   
   // Performance tracking
   double   m_today_pnl;
   double   m_today_pnl_pct;
   double   m_rolling_winrate;
   double   m_session_winrate;
   double   m_avg_trade_duration_minutes;
   double   m_ai_accuracy_pct;
   double   m_current_drawdown_pct;
   
   // Trade history for calculations
   int      m_total_trades;
   int      m_winning_trades;
   int      m_losing_trades;
   double   m_total_duration_minutes;
   
   // AI accuracy tracking (last 20 trades)
   bool     m_ai_predictions[20];
   bool     m_ai_actuals[20];
   int      m_ai_prediction_index;
   
   //--- Private methods
   void     CreateBackground();
   void     CreateLabel(string name, int x, int y, string text, color clr, int font_size = 9);
   void     UpdateLabel(string name, string text, color clr);
   double   CalculateAIAccuracy();
   
public:
   //--- Constructor / Destructor
   CTelemetryPanel();
   ~CTelemetryPanel();
   
   //--- Initialization
   bool     Initialize(int x, int y, int width, int height);
   void     Destroy();
   
   //--- Update methods
   void     UpdateTodayPnL(double pnl, double balance);
   void     UpdateWinrate(int wins, int losses);
   void     UpdateAvgTradeDuration(double duration_minutes);
   void     UpdateDrawdown(double drawdown_pct);
   void     RecordTrade(bool is_win, double duration_minutes);
   void     RecordAIPrediction(bool predicted_win, bool actual_win);
   void     Refresh();
   
   //--- Configuration
   void     SetPosition(int x, int y);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTelemetryPanel::CTelemetryPanel()
{
   m_panel_x = 20;
   m_panel_y = 400;
   m_panel_width = 280;
   m_panel_height = 220;
   
   // Professional dark theme matching main dashboard
   m_bg_color = C'20,22,28';
   m_text_color = C'220,220,220';
   m_positive_color = C'46,204,113';
   m_negative_color = C'231,76,60';
   
   m_prefix = "TrendAI_Telemetry_";
   
   // Initialize metrics
   m_today_pnl = 0.0;
   m_today_pnl_pct = 0.0;
   m_rolling_winrate = 0.0;
   m_session_winrate = 0.0;
   m_avg_trade_duration_minutes = 0.0;
   m_ai_accuracy_pct = 0.0;
   m_current_drawdown_pct = 0.0;
   
   m_total_trades = 0;
   m_winning_trades = 0;
   m_losing_trades = 0;
   m_total_duration_minutes = 0.0;
   
   ArrayInitialize(m_ai_predictions, false);
   ArrayInitialize(m_ai_actuals, false);
   m_ai_prediction_index = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTelemetryPanel::~CTelemetryPanel()
{
   Destroy();
}

//+------------------------------------------------------------------+
//| Initialize telemetry panel                                        |
//+------------------------------------------------------------------+
bool CTelemetryPanel::Initialize(int x, int y, int width, int height)
{
   m_panel_x = x;
   m_panel_y = y;
   m_panel_width = width;
   m_panel_height = height;
   
   // Create background panel
   CreateBackground();
   
   // Create header
   CreateLabel("Header", 10, 10, "PERFORMANCE TELEMETRY", clrWhite, 11);
   
   // Create metric labels
   int y_offset = 40;
   int line_height = 25;
   
   CreateLabel("PnLLabel", 10, y_offset, "Today P&L:", m_text_color, 9);
   CreateLabel("PnLValue", 150, y_offset, "$0.00 (0.0%)", m_text_color, 9);
   y_offset += line_height;
   
   CreateLabel("WinrateLabel", 10, y_offset, "Winrate (Rolling):", m_text_color, 9);
   CreateLabel("WinrateValue", 150, y_offset, "0.0%", m_text_color, 9);
   y_offset += line_height;
   
   CreateLabel("SessionWRLabel", 10, y_offset, "Session Winrate:", m_text_color, 9);
   CreateLabel("SessionWRValue", 150, y_offset, "0.0%", m_text_color, 9);
   y_offset += line_height;
   
   CreateLabel("AvgDurLabel", 10, y_offset, "Avg Trade Dur:", m_text_color, 9);
   CreateLabel("AvgDurValue", 150, y_offset, "0.0 min", m_text_color, 9);
   y_offset += line_height;
   
   CreateLabel("AIAccLabel", 10, y_offset, "AI Accuracy (20T):", m_text_color, 9);
   CreateLabel("AIAccValue", 150, y_offset, "0.0%", m_text_color, 9);
   y_offset += line_height;
   
   CreateLabel("DDLabel", 10, y_offset, "Current DD:", m_text_color, 9);
   CreateLabel("DDValue", 150, y_offset, "0.0%", m_text_color, 9);
   
   ChartRedraw();
   Print("Telemetry panel initialized at position (", x, ", ", y, ")");
   
   return true;
}

//+------------------------------------------------------------------+
//| Destroy all telemetry objects                                    |
//+------------------------------------------------------------------+
void CTelemetryPanel::Destroy()
{
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
void CTelemetryPanel::CreateBackground()
{
   string obj_name = m_prefix + "Background";
   
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
void CTelemetryPanel::CreateLabel(string name, int x, int y, string text, color clr, int font_size = 9)
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
void CTelemetryPanel::UpdateLabel(string name, string text, color clr)
{
   string obj_name = m_prefix + name;
   
   if(ObjectFind(0, obj_name) >= 0)
   {
      ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
   }
}

//+------------------------------------------------------------------+
//| Update today's P&L                                                |
//+------------------------------------------------------------------+
void CTelemetryPanel::UpdateTodayPnL(double pnl, double balance)
{
   m_today_pnl = pnl;
   
   if(balance > 0)
      m_today_pnl_pct = (pnl / balance) * 100.0;
   else
      m_today_pnl_pct = 0.0;
}

//+------------------------------------------------------------------+
//| Update winrate statistics                                         |
//+------------------------------------------------------------------+
void CTelemetryPanel::UpdateWinrate(int wins, int losses)
{
   m_winning_trades = wins;
   m_losing_trades = losses;
   m_total_trades = wins + losses;
   
   if(m_total_trades > 0)
   {
      m_rolling_winrate = ((double)wins / (double)m_total_trades) * 100.0;
      m_session_winrate = m_rolling_winrate; // Simplified for now
   }
   else
   {
      m_rolling_winrate = 0.0;
      m_session_winrate = 0.0;
   }
}

//+------------------------------------------------------------------+
//| Update average trade duration                                    |
//+------------------------------------------------------------------+
void CTelemetryPanel::UpdateAvgTradeDuration(double duration_minutes)
{
   m_avg_trade_duration_minutes = duration_minutes;
}

//+------------------------------------------------------------------+
//| Update current drawdown                                           |
//+------------------------------------------------------------------+
void CTelemetryPanel::UpdateDrawdown(double drawdown_pct)
{
   m_current_drawdown_pct = drawdown_pct;
}

//+------------------------------------------------------------------+
//| Record completed trade                                            |
//+------------------------------------------------------------------+
void CTelemetryPanel::RecordTrade(bool is_win, double duration_minutes)
{
   if(is_win)
      m_winning_trades++;
   else
      m_losing_trades++;
   
   m_total_trades++;
   m_total_duration_minutes += duration_minutes;
   
   // Recalculate averages
   if(m_total_trades > 0)
   {
      m_rolling_winrate = ((double)m_winning_trades / (double)m_total_trades) * 100.0;
      m_avg_trade_duration_minutes = m_total_duration_minutes / (double)m_total_trades;
   }
}

//+------------------------------------------------------------------+
//| Record AI prediction for accuracy tracking                       |
//+------------------------------------------------------------------+
void CTelemetryPanel::RecordAIPrediction(bool predicted_win, bool actual_win)
{
   // Store in circular buffer (last 20 predictions)
   m_ai_predictions[m_ai_prediction_index] = predicted_win;
   m_ai_actuals[m_ai_prediction_index] = actual_win;
   
   m_ai_prediction_index = (m_ai_prediction_index + 1) % 20;
   
   // Recalculate accuracy
   m_ai_accuracy_pct = CalculateAIAccuracy();
}

//+------------------------------------------------------------------+
//| Calculate AI accuracy over last 20 predictions                   |
//+------------------------------------------------------------------+
double CTelemetryPanel::CalculateAIAccuracy()
{
   int correct_predictions = 0;
   int total_predictions = 0;
   
   for(int i = 0; i < 20; i++)
   {
      // Only count if we have a prediction recorded
      if(m_ai_predictions[i] || m_ai_actuals[i])
      {
         if(m_ai_predictions[i] == m_ai_actuals[i])
            correct_predictions++;
         total_predictions++;
      }
   }
   
   if(total_predictions > 0)
      return ((double)correct_predictions / (double)total_predictions) * 100.0;
   else
      return 0.0;
}

//+------------------------------------------------------------------+
//| Refresh all displays                                              |
//+------------------------------------------------------------------+
void CTelemetryPanel::Refresh()
{
   // Update P&L display
   color pnl_color = (m_today_pnl >= 0) ? m_positive_color : m_negative_color;
   string pnl_text = StringFormat("$%.2f (%.2f%%)", m_today_pnl, m_today_pnl_pct);
   UpdateLabel("PnLValue", pnl_text, pnl_color);
   
   // Update rolling winrate
   color wr_color = (m_rolling_winrate >= 50.0) ? m_positive_color : m_negative_color;
   UpdateLabel("WinrateValue", StringFormat("%.1f%%", m_rolling_winrate), wr_color);
   
   // Update session winrate
   color swr_color = (m_session_winrate >= 50.0) ? m_positive_color : m_negative_color;
   UpdateLabel("SessionWRValue", StringFormat("%.1f%%", m_session_winrate), swr_color);
   
   // Update avg duration
   UpdateLabel("AvgDurValue", StringFormat("%.1f min", m_avg_trade_duration_minutes), m_text_color);
   
   // Update AI accuracy
   color ai_color = (m_ai_accuracy_pct >= 60.0) ? m_positive_color : m_negative_color;
   UpdateLabel("AIAccValue", StringFormat("%.1f%%", m_ai_accuracy_pct), ai_color);
   
   // Update drawdown
   color dd_color = (m_current_drawdown_pct <= 3.0) ? m_positive_color : m_negative_color;
   UpdateLabel("DDValue", StringFormat("%.2f%%", m_current_drawdown_pct), dd_color);
}

//+------------------------------------------------------------------+
//| Set panel position                                                |
//+------------------------------------------------------------------+
void CTelemetryPanel::SetPosition(int x, int y)
{
   m_panel_x = x;
   m_panel_y = y;
   
   Destroy();
   Initialize(x, y, m_panel_width, m_panel_height);
}
//+------------------------------------------------------------------+
