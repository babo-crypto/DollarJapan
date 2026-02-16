//+------------------------------------------------------------------+
//|                                                   ai_overlay.mqh |
//|                                      TrendAI_v10 Visual AI Layer |
//|                           Institutional-Grade AI Visualization   |
//+------------------------------------------------------------------+
//| Module: AI Visual Overlay                                        |
//| Purpose: Display AI signals and probability overlays on chart    |
//| Version: 10.0                                                     |
//| Author: TrendAI Development Team                                  |
//+------------------------------------------------------------------+

#property copyright "TrendAI Development Team"
#property version   "10.0"
#property strict

//+------------------------------------------------------------------+
//| AI Overlay Class                                                  |
//+------------------------------------------------------------------+
class CAIOverlay
{
private:
   string   m_prefix;
   
   // Session background colors
   color    m_asia_color;
   color    m_london_color;
   color    m_newyork_color;
   
   // Signal arrow codes
   int      m_buy_arrow_code;
   int      m_sell_arrow_code;
   
   // Last drawn objects tracking
   datetime m_last_signal_time;
   datetime m_last_heatbar_time;
   
   //--- Private methods
   color    GetProbabilityColor(double probability);
   void     DrawSessionBackground(datetime time, int session_id);
   void     CleanupOldObjects(int max_objects = 500);
   
public:
   //--- Constructor / Destructor
   CAIOverlay();
   ~CAIOverlay();
   
   //--- Initialization
   void     Initialize();
   void     Destroy();
   
   //--- Drawing methods
   void     DrawProbabilityHeatbar(datetime time, double price, double probability, int bar_shift = 0);
   void     DrawBuySignal(datetime time, double price, double probability);
   void     DrawSellSignal(datetime time, double price, double probability);
   void     UpdateSessionBackground(int session_id);
   void     DrawKumoStrengthIndicator(datetime time, double cloud_thickness);
   
   //--- Cleanup
   void     RemoveAllOverlays();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CAIOverlay::CAIOverlay()
{
   m_prefix = "TrendAI_Overlay_";
   
   // Professional session colors (subtle, not garish)
   m_asia_color = C'40,45,70';        // Dark blue tint
   m_london_color = C'70,50,30';      // Dark orange tint
   m_newyork_color = C'70,35,40';     // Dark red tint
   
   // Arrow codes (MT5 standard arrows)
   m_buy_arrow_code = 233;   // Up arrow
   m_sell_arrow_code = 234;  // Down arrow
   
   m_last_signal_time = 0;
   m_last_heatbar_time = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CAIOverlay::~CAIOverlay()
{
   Destroy();
}

//+------------------------------------------------------------------+
//| Initialize overlay system                                         |
//+------------------------------------------------------------------+
void CAIOverlay::Initialize()
{
   Print("AI Overlay system initialized");
}

//+------------------------------------------------------------------+
//| Destroy all overlay objects                                      |
//+------------------------------------------------------------------+
void CAIOverlay::Destroy()
{
   RemoveAllOverlays();
}

//+------------------------------------------------------------------+
//| Draw probability heatbar beside current price                    |
//+------------------------------------------------------------------+
void CAIOverlay::DrawProbabilityHeatbar(datetime time, double price, double probability, int bar_shift = 0)
{
   // Only draw if time has changed
   if(time == m_last_heatbar_time)
      return;
   
   m_last_heatbar_time = time;
   
   // Create unique object name
   string obj_name = m_prefix + "Heatbar_" + TimeToString(time);
   
   // Get color based on probability
   color bar_color = GetProbabilityColor(probability);
   
   // Calculate bar height (scaled by probability)
   double bar_height = 0.0001 * probability * 1000; // Adjust based on USDJPY scale
   
   // Draw rectangle trend line
   if(ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, time, price, time + PeriodSeconds(), price + bar_height))
   {
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, bar_color);
      ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
   }
   
   // Add probability text label
   string label_name = m_prefix + "HeatLabel_" + TimeToString(time);
   if(ObjectCreate(0, label_name, OBJ_TEXT, 0, time, price + bar_height))
   {
      ObjectSetString(0, label_name, OBJPROP_TEXT, StringFormat("%.0f%%", probability * 100));
      ObjectSetInteger(0, label_name, OBJPROP_COLOR, bar_color);
      ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 7);
      ObjectSetString(0, label_name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Draw buy signal arrow                                            |
//+------------------------------------------------------------------+
void CAIOverlay::DrawBuySignal(datetime time, double price, double probability)
{
   // Don't draw duplicate signals
   if(time == m_last_signal_time)
      return;
   
   m_last_signal_time = time;
   
   string obj_name = m_prefix + "BuySignal_" + TimeToString(time);
   
   // Draw arrow below the candle
   double arrow_price = price - 0.05; // Offset below
   
   if(ObjectCreate(0, obj_name, OBJ_ARROW, 0, time, arrow_price))
   {
      ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, m_buy_arrow_code);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, C'46,204,113'); // Green
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
      
      // Add tooltip
      string tooltip = StringFormat("BUY Signal\nProb: %.1f%%\nTime: %s", 
                                    probability * 100, TimeToString(time));
      ObjectSetString(0, obj_name, OBJPROP_TOOLTIP, tooltip);
   }
   
   Print("Buy signal drawn at ", TimeToString(time), " with probability: ", probability);
}

//+------------------------------------------------------------------+
//| Draw sell signal arrow                                           |
//+------------------------------------------------------------------+
void CAIOverlay::DrawSellSignal(datetime time, double price, double probability)
{
   // Don't draw duplicate signals
   if(time == m_last_signal_time)
      return;
   
   m_last_signal_time = time;
   
   string obj_name = m_prefix + "SellSignal_" + TimeToString(time);
   
   // Draw arrow above the candle
   double arrow_price = price + 0.05; // Offset above
   
   if(ObjectCreate(0, obj_name, OBJ_ARROW, 0, time, arrow_price))
   {
      ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, m_sell_arrow_code);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, C'231,76,60'); // Red
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
      
      // Add tooltip
      string tooltip = StringFormat("SELL Signal\nProb: %.1f%%\nTime: %s", 
                                    probability * 100, TimeToString(time));
      ObjectSetString(0, obj_name, OBJPROP_TOOLTIP, tooltip);
   }
   
   Print("Sell signal drawn at ", TimeToString(time), " with probability: ", probability);
}

//+------------------------------------------------------------------+
//| Update session background gradient                               |
//+------------------------------------------------------------------+
void CAIOverlay::UpdateSessionBackground(int session_id)
{
   string obj_name = m_prefix + "SessionBG";
   
   // Remove existing background
   if(ObjectFind(0, obj_name) >= 0)
      ObjectDelete(0, obj_name);
   
   // Determine color based on session
   color bg_color = clrNONE;
   
   switch(session_id)
   {
      case 0: bg_color = m_asia_color; break;
      case 1: bg_color = m_london_color; break;
      case 2: bg_color = m_newyork_color; break;
      default: return; // No background for off-hours
   }
   
   // Get current chart boundaries
   datetime time_start = (datetime)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   datetime time_end = TimeCurrent();
   
   double price_max = ChartGetDouble(0, CHART_PRICE_MAX);
   double price_min = ChartGetDouble(0, CHART_PRICE_MIN);
   
   // Create semi-transparent background rectangle
   if(ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, time_end - 7200, price_min, time_end, price_max))
   {
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, bg_color);
      ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 0);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
   }
}

//+------------------------------------------------------------------+
//| Draw Kumo strength indicator                                     |
//+------------------------------------------------------------------+
void CAIOverlay::DrawKumoStrengthIndicator(datetime time, double cloud_thickness)
{
   string obj_name = m_prefix + "KumoStrength_" + TimeToString(time);
   
   // Visual representation of cloud strength
   // Thicker cloud = more prominent visual
   int width = (int)(MathAbs(cloud_thickness) * 2) + 1;
   if(width > 5) width = 5; // Cap at max width
   
   color kumo_color = (cloud_thickness > 0) ? C'46,204,113' : C'231,76,60';
   
   // This is a conceptual indicator - in practice, Ichimoku's built-in cloud
   // already shows thickness visually
   // We could add a supplementary line or text indicator here if needed
}

//+------------------------------------------------------------------+
//| Get color based on probability value                             |
//+------------------------------------------------------------------+
color CAIOverlay::GetProbabilityColor(double probability)
{
   // Color gradient from red (low prob) to yellow (med) to green (high)
   
   if(probability >= 0.80)
      return C'46,204,113';      // Strong green
   else if(probability >= 0.70)
      return C'140,230,140';     // Light green
   else if(probability >= 0.60)
      return C'241,196,15';      // Yellow
   else if(probability >= 0.50)
      return C'243,156,18';      // Orange
   else
      return C'231,76,60';       // Red
}

//+------------------------------------------------------------------+
//| Clean up old objects to prevent memory issues                    |
//+------------------------------------------------------------------+
void CAIOverlay::CleanupOldObjects(int max_objects = 500)
{
   int total_objects = 0;
   
   // Count overlay objects
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string obj_name = ObjectName(0, i);
      if(StringFind(obj_name, m_prefix) >= 0)
         total_objects++;
   }
   
   // If too many objects, remove oldest ones
   if(total_objects > max_objects)
   {
      int to_remove = total_objects - max_objects;
      
      for(int i = ObjectsTotal(0) - 1; i >= 0 && to_remove > 0; i--)
      {
         string obj_name = ObjectName(0, i);
         if(StringFind(obj_name, m_prefix) >= 0)
         {
            ObjectDelete(0, obj_name);
            to_remove--;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Remove all overlay objects                                       |
//+------------------------------------------------------------------+
void CAIOverlay::RemoveAllOverlays()
{
   int total = ObjectsTotal(0);
   
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
