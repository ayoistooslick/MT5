//+------------------------------------------------------------------+
//|                                                  StrategyM15.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "Config.mqh"
#include "Indicators.mqh"
#include "MarketStructure.mqh"
#include "SignalScoring.mqh"

//+------------------------------------------------------------------+
//| Evaluate M15 Strategy Setup                                      |
//+------------------------------------------------------------------+
SignalResult EvaluateM15(bool bullish)
{
   SignalResult result;
   result.score = 0;
   result.isValid = false;
   result.criticalPassed = false;
   result.reason = "";

   ENUM_TIMEFRAMES tf = PERIOD_M15;

   // 1. M15 Trend Logic
   double ema200 = GetIndicatorValue(hEMA200_M15, 1);
   double ema50 = GetIndicatorValue(hEMA50_M15, 1);
   double close1 = iClose(_Symbol, tf, 1);
   double open1 = iOpen(_Symbol, tf, 1);

   if(!IsIndicatorReady(hEMA200_M15) || !IsIndicatorReady(hEMA50_M15) ||
      close1 <= 0 || open1 <= 0)
   {
      result.reason = "M15 trend data not ready";
      return result;
   }

   bool trend_ok = bullish ? (close1 > ema200 && ema50 > ema200) : (close1 < ema200 && ema50 < ema200);

   if(!trend_ok)
   {
      result.reason = "M15 Trend EMA condition failed";
      return result;
   }

   // 2. Other Conditions
   double ema9 = GetIndicatorValue(hEMA9_M15, 1);
   double ema21 = GetIndicatorValue(hEMA21_M15, 1);
   double rsi = GetIndicatorValue(hRSI_M15, 1);
   double atr = GetIndicatorValue(hATR_M15, 1);

   if(!IsIndicatorReady(hEMA9_M15) || !IsIndicatorReady(hEMA21_M15) ||
      !IsIndicatorReady(hRSI_M15) || !IsIndicatorReady(hATR_M15))
   {
      result.reason = "M15 indicator data not ready";
      return result;
   }

   bool structure = bullish ? IsBullishStructure(tf) : IsBearishStructure(tf);
   bool pullback = IsPriceInPullbackZone(tf, ema9, ema21, bullish);
   bool confirmation = bullish ? (close1 > open1) : (close1 < open1);

   // 3. Scoring
   result = CalculateScore(tf, bullish, ema9, ema21, ema200, rsi, atr, structure, pullback, confirmation);

   if(result.isValid && result.score < InpM15MinScore)
   {
      result.isValid = false;
      result.reason = "Score below M15 threshold";
   }

   return result;
}
