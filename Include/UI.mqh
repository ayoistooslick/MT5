//+------------------------------------------------------------------+
//|                                                           UI.mqh |
//|                                  Copyright 2026, MetaTrader 5 EA |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "Config.mqh"

#define BUTTON_NAME "MTF_EA_TRADE_BUTTON"

//+------------------------------------------------------------------+
//| Create the ON/OFF Button                                         |
//+------------------------------------------------------------------+
void CreateTradeButton()
{
   if(ObjectCreate(0, BUTTON_NAME, OBJ_BUTTON, 0, 0, 0))
   {
      ObjectSetInteger(0, BUTTON_NAME, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, BUTTON_NAME, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, BUTTON_NAME, OBJPROP_XSIZE, 120);
      ObjectSetInteger(0, BUTTON_NAME, OBJPROP_YSIZE, 30);
      ObjectSetInteger(0, BUTTON_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, BUTTON_NAME, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, BUTTON_NAME, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, BUTTON_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, BUTTON_NAME, OBJPROP_COLOR, clrWhite);
      
      UpdateTradeButton();
   }
}

//+------------------------------------------------------------------+
//| Update the Button appearance based on state                      |
//+------------------------------------------------------------------+
void UpdateTradeButton()
{
   if(GlobalTradingEnabled)
   {
      ObjectSetString(0, BUTTON_NAME, OBJPROP_TEXT, "TRADING ON");
      ObjectSetInteger(0, BUTTON_NAME, OBJPROP_BGCOLOR, clrGreen);
   }
   else
   {
      ObjectSetString(0, BUTTON_NAME, OBJPROP_TEXT, "TRADING OFF");
      ObjectSetInteger(0, BUTTON_NAME, OBJPROP_BGCOLOR, clrRed);
   }
}

//+------------------------------------------------------------------+
//| Handle Chart Events for the button                               |
//+------------------------------------------------------------------+
void OnChartEventUI(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BUTTON_NAME)
   {
      GlobalTradingEnabled = !GlobalTradingEnabled;
      UpdateTradeButton();
      Print(LOG_PREFIX, "Trading toggled: ", GlobalTradingEnabled ? "ON" : "OFF");
      
      // Reset button state
      ObjectSetInteger(0, BUTTON_NAME, OBJPROP_STATE, false);
   }
}

//+------------------------------------------------------------------+
//| Remove the Button                                                |
//+------------------------------------------------------------------+
void RemoveTradeButton()
{
   ObjectDelete(0, BUTTON_NAME);
}
