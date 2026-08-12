//+------------------------------------------------------------------+
//|                                              MarketStructure.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "Config.mqh"

//+------------------------------------------------------------------+
//| Detect Bullish Market Structure (HH/HL)                          |
//+------------------------------------------------------------------+
bool IsBullishStructure(ENUM_TIMEFRAMES tf, int lookback = 20)
{
   int highest_bar = iHighest(_Symbol, tf, MODE_HIGH, lookback, 1);
   int lowest_bar = iLowest(_Symbol, tf, MODE_LOW, lookback, 1);
   
   if(highest_bar == -1 || lowest_bar == -1) return false;
   
   // A simple deterministic rule: 
   // Bullish if the highest high is more recent than the lowest low
   // and the current price is above the midpoint of the range.
   
   if(highest_bar < lowest_bar) // highest_bar is index, so smaller index means more recent
   {
      double high = iHigh(_Symbol, tf, highest_bar);
      double low = iLow(_Symbol, tf, lowest_bar);
      double close = iClose(_Symbol, tf, 1);
      
      if(close > (high + low) / 2.0)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect Bearish Market Structure (LH/LL)                          |
//+------------------------------------------------------------------+
bool IsBearishStructure(ENUM_TIMEFRAMES tf, int lookback = 20)
{
   int highest_bar = iHighest(_Symbol, tf, MODE_HIGH, lookback, 1);
   int lowest_bar = iLowest(_Symbol, tf, MODE_LOW, lookback, 1);
   
   if(highest_bar == -1 || lowest_bar == -1) return false;
   
   if(lowest_bar < highest_bar)
   {
      double high = iHigh(_Symbol, tf, highest_bar);
      double low = iLow(_Symbol, tf, lowest_bar);
      double close = iClose(_Symbol, tf, 1);
      
      if(close < (high + low) / 2.0)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for valid pullback to EMA zone                             |
//+------------------------------------------------------------------+
bool IsPriceInPullbackZone(ENUM_TIMEFRAMES tf, double ema_short, double ema_medium, bool bullish)
{
   double close = iClose(_Symbol, tf, 1);
   
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
