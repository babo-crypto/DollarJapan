//+------------------------------------------------------------------+
//|                                              feature_builder.mqh |
//|                                      TrendAI_v10 Feature Engine  |
//|                           Institutional-Grade Feature Calculator |
//+------------------------------------------------------------------+
//| Module: Feature Engineering Layer                                 |
//| Purpose: Calculate all ML features for ONNX inference            |
//| Version: 10.0                                                     |
//| Author: TrendAI Development Team                                  |
//+------------------------------------------------------------------+

#property copyright "TrendAI Development Team"
#property version   "10.0"
#property strict

//+------------------------------------------------------------------+
//| Session Enumeration                                               |
//+------------------------------------------------------------------+
enum ENUM_SESSION_ID
{
   SESSION_ASIA = 0,      // Asian session (00:00-08:00 GMT+9)
   SESSION_LONDON = 1,    // London session (08:00-16:00 GMT+9)
   SESSION_NEWYORK = 2,   // New York session (16:00-24:00 GMT+9)
   SESSION_OFF_HOURS = 3  // Off-hours / Overlap
};

//+------------------------------------------------------------------+
//| Feature Builder Class                                             |
//+------------------------------------------------------------------+
class CFeatureBuilder
{
private:
   int      m_atr_handle;
   int      m_adx_handle;
   int      m_ichimoku_handle;
   
   // Feature buffer storage
   double   m_features[14];
   
   // Ichimoku parameters
   int      m_tenkan_period;
   int      m_kijun_period;
   int      m_senkou_span_b_period;
   
   // ATR for volatility normalization
   double   m_atr_current;
   
   //--- Private calculation methods
   double   CalculateSlope(const double &buffer[], int lookback);
   double   CalculateTickVolumeSpike(int bars_back);
   double   CalculateCandleCompression(int bars_back);
   ENUM_SESSION_ID DeterminSessionID(int broker_hour);
   
public:
   //--- Constructor / Destructor
   CFeatureBuilder();
   ~CFeatureBuilder();
   
   //--- Initialization
   bool     Initialize(string symbol, ENUM_TIMEFRAMES timeframe);
   void     Deinitialize();
   
   //--- Feature calculation
   bool     BuildFeatures(double &features[]);
   int      GetFeatureCount() { return 14; }
   
   //--- Individual feature getters (for debugging)
   double   GetTenkanSlope();
   double   GetKijunSlope();
   double   GetCloudThickness();
   double   GetPriceKumoDistance();
   double   GetChikouRelativePosition();
   double   GetATRNormalized();
   double   GetADX();
   double   GetTickVolumeSpike();
   int      GetBrokerHour();
   ENUM_SESSION_ID GetSessionID();
   double   GetSpread();
   double   GetCandleCompression();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CFeatureBuilder::CFeatureBuilder()
{
   m_atr_handle = INVALID_HANDLE;
   m_adx_handle = INVALID_HANDLE;
   m_ichimoku_handle = INVALID_HANDLE;
   
   m_tenkan_period = 9;
   m_kijun_period = 26;
   m_senkou_span_b_period = 52;
   
   m_atr_current = 0.0;
   
   ArrayInitialize(m_features, 0.0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CFeatureBuilder::~CFeatureBuilder()
{
   Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize indicators                                             |
//+------------------------------------------------------------------+
bool CFeatureBuilder::Initialize(string symbol, ENUM_TIMEFRAMES timeframe)
{
   // Create ATR indicator
   m_atr_handle = iATR(symbol, timeframe, 14);
   if(m_atr_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ATR indicator");
      return false;
   }
   
   // Create ADX indicator
   m_adx_handle = iADX(symbol, timeframe, 14);
   if(m_adx_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ADX indicator");
      return false;
   }
   
   // Create Ichimoku indicator
   m_ichimoku_handle = iIchimoku(symbol, timeframe, 
                                  m_tenkan_period, 
                                  m_kijun_period, 
                                  m_senkou_span_b_period);
   if(m_ichimoku_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create Ichimoku indicator");
      return false;
   }
   
   Print("Feature Builder initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Release indicator handles                                         |
//+------------------------------------------------------------------+
void CFeatureBuilder::Deinitialize()
{
   if(m_atr_handle != INVALID_HANDLE)
      IndicatorRelease(m_atr_handle);
   if(m_adx_handle != INVALID_HANDLE)
      IndicatorRelease(m_adx_handle);
   if(m_ichimoku_handle != INVALID_HANDLE)
      IndicatorRelease(m_ichimoku_handle);
}

//+------------------------------------------------------------------+
//| Build complete feature vector                                     |
//+------------------------------------------------------------------+
bool CFeatureBuilder::BuildFeatures(double &features[])
{
   // Ensure we have enough data
   if(Bars(_Symbol, _Period) < 100)
   {
      Print("ERROR: Not enough bars for feature calculation");
      return false;
   }
   
   // Resize output array
   ArrayResize(features, 14);
   ArrayInitialize(features, 0.0);
   
   // Calculate all features
   features[0] = GetTenkanSlope();
   features[1] = GetKijunSlope();
   features[2] = GetCloudThickness();
   features[3] = GetPriceKumoDistance();
   features[4] = GetChikouRelativePosition();
   features[5] = GetATRNormalized();
   features[6] = GetADX();
   features[7] = GetTickVolumeSpike();
   features[8] = (double)GetBrokerHour();
   features[9] = (double)GetSessionID();
   features[10] = GetSpread();
   features[11] = GetCandleCompression();
   
   // Additional derived features for robustness
   features[12] = features[0] * features[6]; // Tenkan slope * ADX (momentum strength)
   features[13] = features[2] / (features[5] + 0.0001); // Cloud thickness / ATR (relative kumo strength)
   
   // Store internally
   ArrayCopy(m_features, features);
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Tenkan-sen slope                                       |
//+------------------------------------------------------------------+
double CFeatureBuilder::GetTenkanSlope()
{
   double tenkan[];
   ArraySetAsSeries(tenkan, true);
   
   if(CopyBuffer(m_ichimoku_handle, 0, 0, 5, tenkan) <= 0)
      return 0.0;
   
   // Calculate slope over last 3 periods
   return CalculateSlope(tenkan, 3);
}

//+------------------------------------------------------------------+
//| Calculate Kijun-sen slope                                        |
//+------------------------------------------------------------------+
double CFeatureBuilder::GetKijunSlope()
{
   double kijun[];
   ArraySetAsSeries(kijun, true);
   
   if(CopyBuffer(m_ichimoku_handle, 1, 0, 5, kijun) <= 0)
      return 0.0;
   
   return CalculateSlope(kijun, 3);
}

//+------------------------------------------------------------------+
//| Calculate cloud thickness (Senkou Span A - Senkou Span B)       |
//+------------------------------------------------------------------+
double CFeatureBuilder::GetCloudThickness()
{
   double senkou_a[], senkou_b[];
   ArraySetAsSeries(senkou_a, true);
   ArraySetAsSeries(senkou_b, true);
   
   if(CopyBuffer(m_ichimoku_handle, 2, 0, 1, senkou_a) <= 0)
      return 0.0;
   if(CopyBuffer(m_ichimoku_handle, 3, 0, 1, senkou_b) <= 0)
      return 0.0;
   
   // Return signed thickness (positive = bullish cloud, negative = bearish cloud)
   double thickness = senkou_a[0] - senkou_b[0];
   
   // Normalize by ATR
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(m_atr_handle, 0, 0, 1, atr) > 0)
      thickness = thickness / (atr[0] + 0.00001);
   
   return thickness;
}

//+------------------------------------------------------------------+
//| Calculate price distance from Kumo (cloud)                       |
//+------------------------------------------------------------------+
double CFeatureBuilder::GetPriceKumoDistance()
{
   double senkou_a[], senkou_b[];
   ArraySetAsSeries(senkou_a, true);
   ArraySetAsSeries(senkou_b, true);
   
   if(CopyBuffer(m_ichimoku_handle, 2, 0, 1, senkou_a) <= 0)
      return 0.0;
   if(CopyBuffer(m_ichimoku_handle, 3, 0, 1, senkou_b) <= 0)
      return 0.0;
   
   double close = iClose(_Symbol, _Period, 0);
   double kumo_top = MathMax(senkou_a[0], senkou_b[0]);
   double kumo_bottom = MathMin(senkou_a[0], senkou_b[0]);
   
   double distance = 0.0;
   
   // Above cloud
   if(close > kumo_top)
      distance = close - kumo_top;
   // Below cloud
   else if(close < kumo_bottom)
      distance = close - kumo_bottom; // negative value
   // Inside cloud
   else
      distance = 0.0;
   
   // Normalize by ATR
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(m_atr_handle, 0, 0, 1, atr) > 0)
   {
      m_atr_current = atr[0];
      distance = distance / (atr[0] + 0.00001);
   }
   
   return distance;
}

//+------------------------------------------------------------------+
//| Calculate Chikou Span relative position                          |
//+------------------------------------------------------------------+
double CFeatureBuilder::GetChikouRelativePosition()
{
   double chikou[];
   ArraySetAsSeries(chikou, true);
   
   if(CopyBuffer(m_ichimoku_handle, 4, 0, 1, chikou) <= 0)
      return 0.0;
   
   // Compare Chikou with price 26 periods ago
   double price_26 = iClose(_Symbol, _Period, 26);
   
   if(price_26 == 0.0)
      return 0.0;
   
   // Relative position: positive = Chikou above price, negative = below
   double relative_pos = (chikou[0] - price_26) / price_26;
   
   return relative_pos * 1000.0; // Scale for better ML model sensitivity
}

//+------------------------------------------------------------------+
//| Get normalized ATR                                               |
//+------------------------------------------------------------------+
double CFeatureBuilder::GetATRNormalized()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(m_atr_handle, 0, 0, 1, atr) <= 0)
      return 0.0;
   
   m_atr_current = atr[0];
   
   // Normalize by current price
   double close = iClose(_Symbol, _Period, 0);
   if(close == 0.0)
      return 0.0;
   
   return (atr[0] / close) * 10000.0; // Convert to basis points
}

//+------------------------------------------------------------------+
//| Get ADX value                                                     |
//+------------------------------------------------------------------+
double CFeatureBuilder::GetADX()
{
   double adx[];
   ArraySetAsSeries(adx, true);
   
   if(CopyBuffer(m_adx_handle, 0, 0, 1, adx) <= 0)
      return 0.0;
   
   return adx[0];
}

//+------------------------------------------------------------------+
//| Calculate tick volume spike ratio                                |
//+------------------------------------------------------------------+
double CFeatureBuilder::GetTickVolumeSpike()
{
   return CalculateTickVolumeSpike(20);
}

//+------------------------------------------------------------------+
//| Get current broker hour (0-23)                                   |
//+------------------------------------------------------------------+
int CFeatureBuilder::GetBrokerHour()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   return dt.hour;
}

//+------------------------------------------------------------------+
//| Determine current session                                         |
//+------------------------------------------------------------------+
ENUM_SESSION_ID CFeatureBuilder::GetSessionID()
{
   int hour = GetBrokerHour();
   return DeterminSessionID(hour);
}

//+------------------------------------------------------------------+
//| Get current spread in pips                                        |
//+------------------------------------------------------------------+
double CFeatureBuilder::GetSpread()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   // Convert to pips (for USDJPY: 3 digits = 0.001 = 0.1 pip, so multiply by 10)
   double pip_multiplier = (digits == 3 || digits == 5) ? 10.0 : 1.0;
   
   return ((ask - bid) / point) / pip_multiplier;
}

//+------------------------------------------------------------------+
//| Calculate candle range compression                               |
//+------------------------------------------------------------------+
double CFeatureBuilder::GetCandleCompression()
{
   return CalculateCandleCompression(20);
}

//+------------------------------------------------------------------+
//| Calculate slope of a buffer                                      |
//+------------------------------------------------------------------+
double CFeatureBuilder::CalculateSlope(const double &buffer[], int lookback)
{
   if(ArraySize(buffer) < lookback)
      return 0.0;
   
   // Simple linear slope: (current - old) / lookback
   double slope = (buffer[0] - buffer[lookback-1]) / (double)lookback;
   
   // Normalize by current price
   double close = iClose(_Symbol, _Period, 0);
   if(close > 0)
      slope = (slope / close) * 100000.0; // Scale for ML sensitivity
   
   return slope;
}

//+------------------------------------------------------------------+
//| Calculate tick volume spike ratio                                |
//+------------------------------------------------------------------+
double CFeatureBuilder::CalculateTickVolumeSpike(int bars_back)
{
   long current_volume = iVolume(_Symbol, _Period, 0);
   
   // Calculate average volume
   long sum = 0;
   for(int i = 1; i <= bars_back; i++)
   {
      sum += iVolume(_Symbol, _Period, i);
   }
   
   double avg_volume = (double)sum / (double)bars_back;
   
   if(avg_volume == 0.0)
      return 1.0;
   
   // Return ratio: current / average
   return (double)current_volume / avg_volume;
}

//+------------------------------------------------------------------+
//| Calculate candle range compression                               |
//+------------------------------------------------------------------+
double CFeatureBuilder::CalculateCandleCompression(int bars_back)
{
   double current_range = iHigh(_Symbol, _Period, 0) - iLow(_Symbol, _Period, 0);
   
   // Calculate average range
   double sum = 0.0;
   for(int i = 1; i <= bars_back; i++)
   {
      sum += iHigh(_Symbol, _Period, i) - iLow(_Symbol, _Period, i);
   }
   
   double avg_range = sum / (double)bars_back;
   
   if(avg_range == 0.0)
      return 1.0;
   
   // Return ratio: current / average (< 1.0 = compression, > 1.0 = expansion)
   return current_range / avg_range;
}

//+------------------------------------------------------------------+
//| Determine session ID based on broker hour                        |
//+------------------------------------------------------------------+
ENUM_SESSION_ID CFeatureBuilder::DeterminSessionID(int broker_hour)
{
   // Assuming broker time is GMT+2/+3 (typical for MT5 brokers)
   // Adjust these ranges based on actual broker timezone
   
   // Asia: 00:00 - 08:00 broker time
   if(broker_hour >= 0 && broker_hour < 8)
      return SESSION_ASIA;
   
   // London: 08:00 - 16:00 broker time
   if(broker_hour >= 8 && broker_hour < 16)
      return SESSION_LONDON;
   
   // New York: 16:00 - 24:00 broker time
   if(broker_hour >= 16 && broker_hour < 24)
      return SESSION_NEWYORK;
   
   return SESSION_OFF_HOURS;
}
//+------------------------------------------------------------------+
