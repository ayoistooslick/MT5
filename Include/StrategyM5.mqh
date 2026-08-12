//+------------------------------------------------------------------+
//|                                                   StrategyM5.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "Config.mqh"
#include "Indicators.mqh"
#include "MarketStructure.mqh"
#include "SignalScoring.mqh"

//+------------------------------------------------------------------+
//| Evaluate M5 Strategy Setup                                       |
//+------------------------------------------------------------------+
SignalResult EvaluateM5(bool bullish)
{
   SignalResult result;
   result.score = 0;
   result.isValid = false;
   result.criticalPassed = false;
   result.reason = "";

   ENUM_TIMEFRAMES tf = PERIOD_M5;

   // 1. Trend Alignment
   double ema200_m15 = GetIndicatorValue(hEMA200_M15, 1);
   double close_m15 = iClose(_Symbol, PERIOD_M15, 1);
   if(!IsIndicatorReady(hEMA200_M15) || close_m15 <= 0)
   {
      result.reason = "Higher timeframe data not ready";
      return result;
   }
   bool m15_trend = bullish ? (close_m15 > ema200_m15) : (close_m15 < ema200_m15);

   if(!m15_trend)
   {
      result.reason = "HTF Trend mismatch (M15)";
      return result;
   }

   // 2. Local M5 Conditions
   double ema9 = GetIndicatorValue(hEMA9_M5, 1);
   double ema21 = GetIndicatorValue(hEMA21_M5, 1);
   double ema200 = GetIndicatorValue(hEMA200_M5, 1);
   double rsi = GetIndicatorValue(hRSI_M5, 1);
   double atr = GetIndicatorValue(hATR_M5, 1);

   if(!IsIndicatorReady(hEMA9_M5) || !IsIndicatorReady(hEMA21_M5) ||
      !IsIndicatorReady(hEMA200_M5) || !IsIndicatorReady(hRSI_M5) ||
      !IsIndicatorReady(hATR_M5))
   {
      result.reason = "M5 indicator data not ready";
      return result;
   }

   bool structure = bullish ? IsBullishStructure(tf) : IsBearishStructure(tf);
   bool pullback = IsPriceInPullbackZone(tf, ema9, ema21, bullish);
   
   // Confirmation Candle
   double close1 = iClose(_Symbol, tf, 1);
   double open1 = iOpen(_Symbol, tf, 1);
   bool confirmation = bullish ? (close1 > open1) : (close1 < open1);

   // 3. Scoring
    result = CalculateScore(tf, bullish, ema9, ema21, ema200, rsi, atr, structure, pullback, confirmation, true);

   if(result.isValid && result.score < InpM5MinScore)
   {
      result.isValid = false;
      result.reason = "Score below M5 threshold";
   }

   return result;
}
