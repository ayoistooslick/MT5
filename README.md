# Multi-Timeframe MT5 Expert Advisor

This Expert Advisor (EA) is a production-quality trading system for MetaTrader 5, built from scratch based on strict deterministic rules and professional risk management principles.

## Features

- **Multi-Timeframe Support:** Individual strategies for M1, M5, and M15 timeframes.
- **Auto Mode:** Automatically selects the strongest signal across all supported timeframes.
- **Deterministic Scoring:** A centralized scoring engine (0-100) ensures only high-probability setups are taken.
- **Advanced Risk Management:**
  - Risk-based lot sizing (Account % or Fixed).
  - Daily loss protection.
  - Maximum trade and position limits.
  - Spread and margin protection.
- **Trade Management:**
  - Break-even and Trailing Stop.
  - Maximum holding time per timeframe mode.
  - ATR-based stop-loss and take-profit calculations.
- **User Interface:** Simple on-chart ON/OFF button to control new trade entries.

## Installation

1. Open your MetaTrader 5 Terminal.
2. Go to `File` -> `Open Data Folder`.
3. Navigate to `MQL5/Experts`.
4. Create a folder named `MTF_EA` and copy `EA.mq5` and the `Include` folder into it.
5. Restart MetaTrader 5 or right-click `Experts` in the Navigator and select `Refresh`.
6. Drag the EA onto a chart.

## Configuration

The EA provides extensive inputs grouped logically:

- **General Settings:** Trading mode, master switch, magic number.
- **Strategy Settings (M1, M5, M15):** Minimum scores, risk percentages, trade limits, TP ratios, max holding times.
- **Indicator Settings:** EMA periods, RSI, and ATR configuration.
- **Risk & Protection:** Max spread, daily loss limits, simultaneous position limits.
- **Trade Management:** Break-even and Trailing stop parameters.

## Deterministic Rules & Assumptions

To ensure the EA operates without subjective bias, the following measurable rules were implemented:

### 1. Market Structure
- **Bullish:** Detected when the highest high within the last 20 bars is more recent than the lowest low, and price is currently above the midpoint of that range.
- **Bearish:** Detected when the lowest low within the last 20 bars is more recent than the highest high, and price is currently below the midpoint of that range.

### 2. Pullback Detection
- **M1/M5:** Price must retrace into the zone between the 9 EMA and 21 EMA.
- **M15:** Price must retrace toward the 9/21 EMA or the 50 EMA area.

### 3. Confirmation Candle
- A trade is only triggered after a **closed** candle confirms the direction (Bullish candle for BUY, Bearish candle for SELL).

### 4. Signal Scoring (Weighted)
- **Base (Criticals):** 40 points (Must pass EMA trend, EMA cross, Market Structure, and Confirmation).
- **HTF Alignment:** 20 points.
- **RSI Momentum:** 15 points.
- **Pullback Quality:** 15 points.
- **Volatility (ATR):** 10 points.

## Trading Modes

1. **M1 Scalping:** Strictest mode. Requires alignment with M15 and M5 trends. Minimum score: 90.
2. **M5 Scalping:** Primary mode. Requires alignment with M15 trend. Minimum score: 85.
3. **M15 Swing:** Long-term mode. Uses EMA 50/200 cross and structural support. Minimum score: 80.
4. **MTF Auto:** Evaluates all three modes and executes only the one with the highest valid score.

## Safety & Protections

- **Stop Loss:** Mandatory for every trade. Calculated as 2x ATR (default).
- **Daily Loss Limit:** Stops new entries if the account loses a configured percentage of balance in a single day.
- **Spread Protection:** Rejects trades if the current spread exceeds the maximum allowed points.
- **Duplicate Protection:** Only one trade per bar is allowed to prevent rapid-fire entries.

## Limitations

- This EA is a tool for automated strategy execution. It does **not** guarantee profits.
- Performance depends heavily on broker execution, spreads, and market conditions.
- Backtesting is highly recommended before live deployment.

## Disclaimer

Trading involves significant risk. This EA is provided "as is" for educational and automated execution purposes. Always test on a demo account first.
