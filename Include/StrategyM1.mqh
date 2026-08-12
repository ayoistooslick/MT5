//+------------------------------------------------------------------+
//|                                                   StrategyM1.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "Config.mqh"
#include "Indicators.mqh"
#include "MarketStructure.mqh"
#include "SignalScoring.mqh"

//+------------------------------------------------------------------+
//| Evaluate M1 Strategy Setup                                       |
//+------------------------------------------------------------------+
SignalResult EvaluateM1(bool bullish)
{
   SignalResult result;
   result.score = 0;
   result.isValid = false;
   result.criticalPassed = false;
   result.reason = "";

   ENUM_TIMEFRAMES tf = PERIOD_M1;

   // 1. Trend Alignment (Higher Timeframes)
   double ema200_m15 = GetIndicatorValue(hEMA200_M15, 1);
   double ema200_m5 = GetIndicatorValue(hEMA200_M5, 1);
   double close_m15 = iClose(_Symbol, PERIOD_M15, 1);
   double close_m5 = iClose(_Symbol, PERIOD_M5, 1);

   bool m15_trend = bullish ? (close_m15 > ema200_m15) : (close_m15 < ema200_m15);
   bool m5_trend = bullish ? (close_m5 > ema200_m5) : (close_m5 < ema200_m5);

   if(!m15_trend || !m5_trend)
   {
      result.reason = "HTF Trend mismatch (M15/M5)";
      return result;
   }

   // 2. Local M1 Conditions
   double ema9 = GetIndicatorValue(hEMA9_M1, 1);
   double ema21 = GetIndicatorValue(hEMA21_M1, 1);
   double ema200 = GetIndicatorValue(hEMA200_M1, 1);
   double rsi = GetIndicatorValue(hRSI_M1, 1);
   double atr = GetIndicatorValue(hATR_M1, 1);

   bool structure = bullish ? IsBullishStructure(tf) : IsBearishStructure(tf);
   bool pullback = IsPriceInPullbackZone(tf, ema9, ema21, bullish);
   
   // Confirmation Candle (Closed bar 1)
   double close1 = iClose(_Symbol, tf, 1);
   double open1 = iOpen(_Symbol, tf, 1);
   bool confirmation = bullish ? (close1 > open1) : (close1 < open1);

   // 3. Scoring
   result = CalculateScore(tf, bullish, ema9, ema21, ema200, rsi, atr, structure, pullback, confirmation);

   if(result.isValid && result.score < InpM1MinScore)
   {
      result.isValid = false;
      result.reason = "Score below M1 threshold";
   }

   return result;
}
