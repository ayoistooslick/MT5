//+------------------------------------------------------------------+
//|                                              MarketStructure.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "Config.mqh"

//--- A swing is confirmed by two closed bars on each side.
#define STRUCTURE_SWING_STRENGTH 2

//+------------------------------------------------------------------+
//| Detect one confirmed swing high or low                           |
//+------------------------------------------------------------------+
bool IsSwingPoint(ENUM_TIMEFRAMES tf, int shift, bool highPoint)
{
   if(shift <= STRUCTURE_SWING_STRENGTH) return false;

   double pivot = highPoint ? iHigh(_Symbol, tf, shift) : iLow(_Symbol, tf, shift);
   if(pivot <= 0) return false;

   for(int offset = 1; offset <= STRUCTURE_SWING_STRENGTH; offset++)
   {
      double newer = highPoint ? iHigh(_Symbol, tf, shift - offset) : iLow(_Symbol, tf, shift - offset);
      double older = highPoint ? iHigh(_Symbol, tf, shift + offset) : iLow(_Symbol, tf, shift + offset);
      if(newer <= 0 || older <= 0) return false;

      if(highPoint && (pivot <= newer || pivot <= older)) return false;
      if(!highPoint && (pivot >= newer || pivot >= older)) return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Get the two most recent confirmed swings in the lookback          |
//+------------------------------------------------------------------+
bool GetRecentSwingPair(ENUM_TIMEFRAMES tf, int lookback, bool highPoint,
                        double &recent, double &previous)
{
   recent = 0;
   previous = 0;
   if(lookback <= STRUCTURE_SWING_STRENGTH) return false;

   int found = 0;
   for(int shift = STRUCTURE_SWING_STRENGTH + 1; shift <= lookback; shift++)
   {
      if(!IsSwingPoint(tf, shift, highPoint)) continue;

      if(found == 0)
      {
         recent = highPoint ? iHigh(_Symbol, tf, shift) : iLow(_Symbol, tf, shift);
         found++;
      }
      else
      {
         previous = highPoint ? iHigh(_Symbol, tf, shift) : iLow(_Symbol, tf, shift);
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Detect bullish higher-high / higher-low structure                |
//| Two confirmed swings are required for both highs and lows.       |
//+------------------------------------------------------------------+
bool IsBullishStructure(ENUM_TIMEFRAMES tf, int lookback = 20)
{
   double recentHigh, previousHigh, recentLow, previousLow;
   if(!GetRecentSwingPair(tf, lookback, true, recentHigh, previousHigh) ||
      !GetRecentSwingPair(tf, lookback, false, recentLow, previousLow))
      return false;

   double close = iClose(_Symbol, tf, 1);
   return close > 0 && close > recentLow &&
          recentHigh > previousHigh && recentLow > previousLow;
}

//+------------------------------------------------------------------+
//| Detect bearish lower-high / lower-low structure                  |
//| Two confirmed swings are required for both highs and lows.       |
//+------------------------------------------------------------------+
bool IsBearishStructure(ENUM_TIMEFRAMES tf, int lookback = 20)
{
   double recentHigh, previousHigh, recentLow, previousLow;
   if(!GetRecentSwingPair(tf, lookback, true, recentHigh, previousHigh) ||
      !GetRecentSwingPair(tf, lookback, false, recentLow, previousLow))
      return false;

   double close = iClose(_Symbol, tf, 1);
   return close > 0 && close < recentHigh &&
          recentHigh < previousHigh && recentLow < previousLow;
}

//+------------------------------------------------------------------+
//| Check for valid pullback to EMA zone                             |
//+------------------------------------------------------------------+
bool IsPriceInPullbackZone(ENUM_TIMEFRAMES tf, double ema_short, double ema_medium, bool bullish)
{
   double close = iClose(_Symbol, tf, 1);
   if(close <= 0 || ema_short <= 0 || ema_medium <= 0) return false;
   
   if(bullish)
   {
      // Pullback toward 9/21 EMA zone
      return (close <= ema_short && close >= ema_medium * 0.999); 
   }
   else
   {
      // Pullback toward 9/21 EMA zone
      return (close >= ema_short && close <= ema_medium * 1.001);
   }
}

//+------------------------------------------------------------------+
//| M15 pullback to the 9/21 zone or 50 EMA support/resistance       |
//+------------------------------------------------------------------+
bool IsPriceInM15PullbackZone(ENUM_TIMEFRAMES tf, double ema_short,
                              double ema_medium, double ema_support, bool bullish)
{
   if(ema_support <= 0) return false;
   double close = iClose(_Symbol, tf, 1);
   if(close <= 0) return false;

   bool emaZone = IsPriceInPullbackZone(tf, ema_short, ema_medium, bullish);
   bool supportZone = close >= ema_support * 0.999 && close <= ema_support * 1.001;
   return emaZone || supportZone;
}
