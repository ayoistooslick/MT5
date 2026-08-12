//+------------------------------------------------------------------+
//|                                                   Indicators.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "Config.mqh"

//--- Global handles
int hEMA9_M1, hEMA21_M1, hEMA200_M1, hRSI_M1, hATR_M1;
int hEMA9_M5, hEMA21_M5, hEMA200_M5, hRSI_M5, hATR_M5;
int hEMA9_M15, hEMA21_M15, hEMA50_M15, hEMA200_M15, hRSI_M15, hATR_M15;

//+------------------------------------------------------------------+
//| Initialize all required indicator handles                        |
//+------------------------------------------------------------------+
bool InitIndicators()
{
   // M1 Handles
   hEMA9_M1 = iMA(_Symbol, PERIOD_M1, InpEMA_Short, 0, MODE_EMA, PRICE_CLOSE);
   hEMA21_M1 = iMA(_Symbol, PERIOD_M1, InpEMA_Medium, 0, MODE_EMA, PRICE_CLOSE);
   hEMA200_M1 = iMA(_Symbol, PERIOD_M1, InpEMA_Trend, 0, MODE_EMA, PRICE_CLOSE);
   hRSI_M1 = iRSI(_Symbol, PERIOD_M1, InpRSI_Period, PRICE_CLOSE);
   hATR_M1 = iATR(_Symbol, PERIOD_M1, InpATR_Period);

   // M5 Handles
   hEMA9_M5 = iMA(_Symbol, PERIOD_M5, InpEMA_Short, 0, MODE_EMA, PRICE_CLOSE);
   hEMA21_M5 = iMA(_Symbol, PERIOD_M5, InpEMA_Medium, 0, MODE_EMA, PRICE_CLOSE);
   hEMA200_M5 = iMA(_Symbol, PERIOD_M5, InpEMA_Trend, 0, MODE_EMA, PRICE_CLOSE);
   hRSI_M5 = iRSI(_Symbol, PERIOD_M5, InpRSI_Period, PRICE_CLOSE);
   hATR_M5 = iATR(_Symbol, PERIOD_M5, InpATR_Period);

   // M15 Handles
   hEMA9_M15 = iMA(_Symbol, PERIOD_M15, InpEMA_Short, 0, MODE_EMA, PRICE_CLOSE);
   hEMA21_M15 = iMA(_Symbol, PERIOD_M15, InpEMA_Medium, 0, MODE_EMA, PRICE_CLOSE);
   hEMA50_M15 = iMA(_Symbol, PERIOD_M15, InpEMA_Long, 0, MODE_EMA, PRICE_CLOSE);
   hEMA200_M15 = iMA(_Symbol, PERIOD_M15, InpEMA_Trend, 0, MODE_EMA, PRICE_CLOSE);
   hRSI_M15 = iRSI(_Symbol, PERIOD_M15, InpRSI_Period, PRICE_CLOSE);
   hATR_M15 = iATR(_Symbol, PERIOD_M15, InpATR_Period);

   // Check if all handles were created successfully
   if(hEMA9_M1 == INVALID_HANDLE || hEMA21_M1 == INVALID_HANDLE || hEMA200_M1 == INVALID_HANDLE ||
      hRSI_M1 == INVALID_HANDLE || hATR_M1 == INVALID_HANDLE ||
      hEMA9_M5 == INVALID_HANDLE || hEMA21_M5 == INVALID_HANDLE || hEMA200_M5 == INVALID_HANDLE ||
      hRSI_M5 == INVALID_HANDLE || hATR_M5 == INVALID_HANDLE ||
      hEMA9_M15 == INVALID_HANDLE || hEMA21_M15 == INVALID_HANDLE || hEMA50_M15 == INVALID_HANDLE ||
      hEMA200_M15 == INVALID_HANDLE || hRSI_M15 == INVALID_HANDLE || hATR_M15 == INVALID_HANDLE)
   {
      Print(LOG_PREFIX, "Error creating indicator handles");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Release all indicator handles                                    |
//+------------------------------------------------------------------+
void DeinitIndicators()
{
   IndicatorRelease(hEMA9_M1); IndicatorRelease(hEMA21_M1); IndicatorRelease(hEMA200_M1); IndicatorRelease(hRSI_M1); IndicatorRelease(hATR_M1);
   IndicatorRelease(hEMA9_M5); IndicatorRelease(hEMA21_M5); IndicatorRelease(hEMA200_M5); IndicatorRelease(hRSI_M5); IndicatorRelease(hATR_M5);
   IndicatorRelease(hEMA9_M15); IndicatorRelease(hEMA21_M15); IndicatorRelease(hEMA50_M15); IndicatorRelease(hEMA200_M15); IndicatorRelease(hRSI_M15); IndicatorRelease(hATR_M15);
}

//+------------------------------------------------------------------+
//| Helper to get indicator value with data readiness check          |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int shift = 0)
{
   if(handle == INVALID_HANDLE) return 0;
   
   double buffer[];
   ArraySetAsSeries(buffer, true);
   
   // Check if data is calculated
   if(BarsCalculated(handle) < shift + 1) return 0;

   if(CopyBuffer(handle, 0, shift, 1, buffer) > 0)
      return buffer[0];
      
   return 0;
}
