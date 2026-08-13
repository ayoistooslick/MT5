//+------------------------------------------------------------------+
//|                                                       Config.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaTrader 5 EA"
#property link      "https://www.mql5.com"
#property strict

//--- Enums
enum ENUM_TRADING_MODE
{
   MODE_M1,       // M1 Scalping
   MODE_M5,       // M5 Scalping
   MODE_M15,      // M15 Swing
   MODE_AUTO      // Multi-Timeframe Auto
};

//--- Inputs
input group "=== GENERAL SETTINGS ==="
input ENUM_TRADING_MODE InpTradingMode = MODE_AUTO; // Trading Mode
input bool InpEnableTrading = true;                 // Enable New Trading
input int InpMagicNumber = 123456;                 // Magic Number
input string InpEAComment = "MT5_MTF_EA";          // EA Comment

input group "=== BACKEND BRIDGE ==="
input string BackendURL = "";                      // Backend base URL
input string BackendAPIKey = "";                   // Backend API key

input group "=== M1 STRATEGY SETTINGS ==="
input int InpM1MinScore = 90;                      // M1 Minimum Score
input double InpM1RiskPercent = 1.0;               // M1 Risk Percent (%)
input int InpM1MaxTradesPerDay = 5;                // M1 Max Trades Per Day
input double InpM1TPRR = 1.5;                      // M1 Take Profit (R:R)
input int InpM1MaxHoldingTime = 60;                // M1 Max Holding Time (Minutes)

input group "=== M5 STRATEGY SETTINGS ==="
input int InpM5MinScore = 85;                      // M5 Minimum Score
input double InpM5RiskPercent = 1.5;               // M5 Risk Percent (%)
input int InpM5MaxTradesPerDay = 3;                // M5 Max Trades Per Day
input double InpM5TPRR = 2.0;                      // M5 Take Profit (R:R)
input int InpM5MaxHoldingTime = 240;               // M5 Max Holding Time (Minutes)

input group "=== M15 STRATEGY SETTINGS ==="
input int InpM15MinScore = 80;                     // M15 Minimum Score
input double InpM15RiskPercent = 2.0;              // M15 Risk Percent (%)
input int InpM15MaxTradesPerDay = 2;               // M15 Max Trades Per Day
input double InpM15TPRR = 3.0;                     // M15 Take Profit (R:R)
input int InpM15MaxHoldingTime = 1440;             // M15 Max Holding Time (Minutes)

input group "=== INDICATOR SETTINGS ==="
input int InpEMA_Short = 9;                        // Short EMA Period
input int InpEMA_Medium = 21;                       // Medium EMA Period
input int InpEMA_Long = 50;                         // Long EMA Period
input int InpEMA_Trend = 200;                       // Trend EMA Period
input int InpRSI_Period = 14;                       // RSI Period
input int InpATR_Period = 14;                       // ATR Period

input group "=== RISK & PROTECTION ==="
input double InpMaxSpread = 20;                    // Max Spread (Points)
input bool InpEnableDailyLossLimit = true;         // Enable Daily Loss Limit
input double InpMaxDailyLossPercent = 5.0;         // Max Daily Loss (%)
input double InpMaxDailyLossMoney = 0.0;           // Max Daily Loss (Money, 0 = disabled)
input int InpMaxSimultaneousPositions = 3;         // Max Simultaneous Positions
input bool InpOnePositionPerSymbol = true;         // One Position Per Symbol

input group "=== TRADE MANAGEMENT ==="
input bool InpEnableBreakEven = true;              // Enable Break-Even
input double InpBETriggerRR = 1.0;                 // BE Trigger (R:R)
input double InpBEOffsetPoints = 10;               // BE Offset (Points)
input bool InpEnableTrailingStop = true;           // Enable Trailing Stop
input double InpTrailingStartRR = 1.2;             // Trailing Start (R:R)
input double InpTrailingDistancePoints = 200;      // Trailing Distance (Points)

//--- Constants
#define EA_VERSION "1.00"
#define LOG_PREFIX "[MT5_MTF_EA] "

//--- Global Variables
bool GlobalTradingEnabled = true; // Controlled by UI and Input
