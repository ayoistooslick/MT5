Multi-Timeframe MT5 Expert Advisor

Project Overview

Build a professional MetaTrader 5 Expert Advisor (EA) from scratch.

The EA must support three individual trading modes plus an automatic multi-timeframe mode:

1. M1 Scalping
2. M5 Scalping
3. M15 Swing / Intraday
4. Multi-Timeframe Auto

The EA must prioritize selectivity, risk control and deterministic trading rules.

The EA must NEVER claim or assume that indicator agreement guarantees profitability.

Every trade must have:

- Stop Loss
- Take Profit
- Risk control
- Spread protection
- Margin protection
- Daily loss protection

If the required confirmation is insufficient, the EA must WAIT and open no trade.

---

1. Trading Mode

Create an input named:

"TradingMode"

Available options:

- M1 Scalping
- M5 Scalping
- M15 Swing
- Multi-Timeframe Auto

The user must be able to change the mode from MT5 EA inputs.

---

2. Master Trading ON/OFF

Add a master trading control.

Input:

"EnableTrading"

When disabled:

- Do not open new trades.
- Continue managing existing positions unless explicitly configured otherwise.
- Existing SL/TP, break-even and trailing management should continue functioning.

When enabled:

- Normal signal evaluation resumes.

The EA should also provide a visible ON/OFF control on the MT5 chart if practical.

The chart button must clearly show whether new trading is enabled or disabled.

---

3. MODE 1: M1 SCALPING

M1 is the strictest and most selective trading mode.

Minimum score:

"90/100"

M1 BUY

Require:

1. M15 trend is bullish.
2. M5 trend is bullish.
3. M1 price is above 200 EMA.
4. M1 9 EMA > 21 EMA.
5. Price pulls back toward the 9/21 EMA zone.
6. Bullish market structure remains intact.
7. RSI confirms bullish momentum.
8. A bullish confirmation candle CLOSES.
9. Spread is acceptable.
10. ATR shows sufficient volatility.
11. Signal score >= 90.

If any critical confirmation fails:

"NO TRADE"

M1 SELL

Opposite conditions:

1. M15 trend is bearish.
2. M5 trend is bearish.
3. M1 price is below 200 EMA.
4. M1 9 EMA < 21 EMA.
5. Price pulls back toward the 9/21 EMA zone.
6. Bearish market structure remains intact.
7. RSI confirms bearish momentum.
8. A bearish confirmation candle CLOSES.
9. Spread is acceptable.
10. ATR shows sufficient volatility.
11. Signal score >= 90.

M1 must use the strictest entry filter.

---

4. MODE 2: M5 SCALPING

M5 is the primary scalping timeframe.

Minimum score:

"85/100"

M5 BUY

Require:

1. M15 trend bullish.
2. M5 trend bullish.
3. M5 price above 200 EMA.
4. M5 9 EMA > 21 EMA.
5. Valid pullback.
6. Bullish market structure.
7. RSI > 50.
8. Bullish confirmation candle closes.
9. ATR confirms sufficient volatility.
10. Spread is within configured limit.
11. Signal score >= 85.

M5 SELL

Opposite bearish conditions.

---

5. MODE 3: M15 SWING / INTRADAY

M15 trades must NOT be treated like M1 scalps.

They should be allowed to remain open longer.

Minimum score:

"80/100"

M15 BUY

Require:

1. M15 price above 200 EMA.
2. 50 EMA > 200 EMA.
3. Clear higher-high / higher-low structure.
4. Price pulls back toward meaningful support or EMA area.
5. RSI confirms bullish momentum.
6. Bullish confirmation candle closes.
7. ATR supports reasonable stop-loss placement.
8. Spread is acceptable.
9. Signal score >= 80.

M15 SELL

Opposite bearish conditions.

M15 should use wider SL/TP and longer trade management than scalping modes.

---

6. MULTI-TIMEFRAME AUTO

When:

"TradingMode = Multi-Timeframe Auto"

The EA may evaluate M1, M5 and M15 setups.

It must NOT open multiple trades simply because multiple timeframes produce signals.

It should:

1. Evaluate available setups.
2. Calculate their signal scores.
3. Check risk and market conditions.
4. Select the strongest valid setup.
5. Open at most the configured number of positions allowed by risk/trade rules.

Preferred alignment:

M15 = overall trend
↓
M5 = setup
↓
M1 = precise entry
↓
BUY / SELL

Example:

M15 bullish
+
M5 bullish
+
M1 pullback
+
M1 confirmation

high-quality M1 BUY

For SELL:

M15 bearish
+
M5 bearish
+
M1 pullback
+
M1 confirmation

high-quality M1 SELL

If timeframes strongly disagree:

"NO TRADE"

Auto mode must prioritize setup quality rather than trading frequency.

---

7. SIGNAL SCORING

Create a centralized scoring system.

Score range:

"0-100"

Minimum scores:

- M1 = 90
- M5 = 85
- M15 = 80

The scoring engine must be configurable and clearly documented.

Important conditions may be marked as critical.

A setup must not trade merely because its numerical score passes the threshold if a critical safety/confirmation condition has failed.

The scoring logic must be deterministic.

Do NOT use subjective descriptions that cannot be calculated by an EA.

---

8. INDICATORS

The EA should support:

- EMA 9
- EMA 21
- EMA 50
- EMA 200
- RSI
- ATR

Indicator periods should preferably be configurable through EA inputs where appropriate.

Use closed candles for confirmation.

Avoid using the currently forming candle for entry confirmation unless explicitly required.

---

9. MARKET STRUCTURE

Market structure must be converted into deterministic rules.

Bullish structure should be based on measurable higher highs and higher lows.

Bearish structure should be based on measurable lower highs and lower lows.

The implementation must be documented.

Do not implement vague discretionary logic.

---

10. PULLBACK DETECTION

Pullbacks must be objectively detected.

For M1/M5:

- Price should retrace toward the 9/21 EMA zone.
- The pullback must not invalidate the broader trend structure.

For M15:

- Price may pull back toward a meaningful EMA/support area.

The exact mathematical implementation must be documented and exposed through sensible inputs where appropriate.

---

11. CONFIRMATION CANDLES

A confirmation candle must be CLOSED before entry.

Do not enter based solely on an unfinished candle.

Bullish confirmation and bearish confirmation rules must be deterministic.

Document the exact candle conditions used.

---

12. RSI

RSI must confirm directional momentum.

Default examples:

- Bullish momentum: RSI > 50
- Bearish momentum: RSI < 50

Mode-specific thresholds may be configurable.

Do not allow RSI alone to generate a trade.

---

13. ATR / VOLATILITY

ATR must be used to determine whether market volatility is sufficient.

ATR should also contribute to stop-loss placement.

Avoid trading when volatility is below the configured minimum.

All volatility thresholds should be configurable.

---

14. SPREAD PROTECTION

Before opening a position:

- Check current spread.
- Compare against configured maximum spread.
- Reject trade if spread is too high.

Spread limits should be configurable.

---

15. MARGIN PROTECTION

Before opening a trade:

- Verify sufficient free margin.
- Calculate the expected position size.
- Reject trade if margin requirements are unsafe.

Never blindly send an order.

---

16. RISK MANAGEMENT

Provide separate settings for each mode.

M1

- MinimumScore = 90
- RiskPercent = configurable
- MaxTradesPerDay = configurable

M5

- MinimumScore = 85
- RiskPercent = configurable
- MaxTradesPerDay = configurable

M15

- MinimumScore = 80
- RiskPercent = configurable
- MaxTradesPerDay = configurable

Position size should preferably be calculated from:

- Account equity/balance
- Risk percentage
- Stop-loss distance
- Symbol tick value
- Symbol tick size

Do not use arbitrary fixed lot sizes when risk-based sizing is enabled.

---

17. STOP LOSS

Provide separate SL settings for:

- M1
- M5
- M15

Support ATR-based stop placement.

M15 should generally use wider structural/ATR-based stops than scalping modes.

---

18. TAKE PROFIT

Provide separate TP settings for:

- M1
- M5
- M15

Use configurable Risk/Reward ratios.

Example:

"TakeProfitRR = 1.5"

The exact defaults can be sensible and configurable.

---

19. BREAK-EVEN

Provide separate settings for each mode.

Configurable:

- EnableBreakEven
- BreakEvenTrigger
- BreakEvenOffset

---

20. TRAILING STOP

Provide separate settings for each mode.

Configurable:

- EnableTrailingStop
- TrailingStart
- TrailingDistance
- Optional ATR-based trailing

M1 should use faster management.

M15 should use slower/wider management.

---

21. MAXIMUM HOLDING TIME

Provide separate maximum holding times:

- M1
- M5
- M15

M1 should generally have the shortest maximum holding period.

M15 should have a substantially longer maximum holding period.

Maximum holding time should be configurable.

---

22. DAILY LOSS PROTECTION

Implement daily loss protection.

Inputs should include:

- EnableDailyLossProtection
- MaxDailyLossPercent
- MaxDailyLossMoney

Once the daily loss limit is reached:

- Stop opening new trades.
- Continue managing existing positions.

Daily counters should reset correctly at the beginning of a new trading day.

---

23. TRADE LIMITS

Support:

- Maximum trades per day
- Maximum simultaneous positions
- Optional one-position-per-symbol protection
- Duplicate signal protection

The EA must not repeatedly enter the same signal on every tick.

Use new-bar/signal-state logic where appropriate.

---

24. TRADE EXECUTION

Use standard MQL5 trading APIs.

The EA must:

- Validate trade conditions before sending orders.
- Check broker symbol properties.
- Respect minimum lot.
- Respect maximum lot.
- Respect lot step.
- Respect minimum stop distance.
- Handle trade execution errors.
- Log meaningful errors.

Use a unique Magic Number.

---

25. MULTI-SYMBOL SUPPORT

The EA should work correctly on the symbol attached to the chart.

Avoid hardcoding a specific currency pair.

Symbol-specific properties must be obtained dynamically.

---

26. CONFIGURATION

Important settings should be exposed as MT5 inputs.

Group inputs logically:

- General
- Trading Mode
- M1 Settings
- M5 Settings
- M15 Settings
- Indicators
- Risk Management
- Stop Loss / Take Profit
- Break-Even
- Trailing Stop
- Daily Protection
- Spread Protection
- Execution

---

27. LOGGING

Provide useful logs for debugging.

Examples:

- Signal rejected: M15 trend bearish.
- Signal rejected: spread too high.
- Signal rejected: score 82 < required 90.
- Signal rejected: ATR too low.
- Trade opened.
- Trade management updated.
- Daily loss limit reached.
- Trading disabled.

Avoid flooding the Experts log on every tick.

---

28. SAFETY PRINCIPLES

The EA must NEVER:

- Guarantee profit.
- Open a trade without SL.
- Ignore risk settings.
- Ignore spread protection.
- Ignore margin requirements.
- Open duplicate positions because the same signal is detected repeatedly.
- Trade when required critical confirmation is missing.

When uncertain:

"NO TRADE"

Selectivity is preferred over unnecessary trading frequency.

---

29. IMPORTANT DISCLAIMER

This EA is an automated implementation of a trading strategy.

It must not claim that the strategy guarantees profits.

Backtesting and forward testing are required before live trading.

The EA must prioritize correct implementation and risk control over claims of profitability.