MT5 EA Architecture

Goal

Build the EA as maintainable, modular MQL5 code rather than one giant procedural file.

The project must remain understandable enough that another developer can modify the strategy later.

---

1. Suggested Structure

Use a structure similar to:

MT5-EA/
├── EA.mq5
├── SPEC.md
├── ARCHITECTURE.md
├── DEVELOPMENT.md
└── README.md

If MQL5 include files are useful, use:

MT5-EA/
├── EA.mq5
├── Include/
│   ├── Config.mqh
│   ├── Indicators.mqh
│   ├── MarketStructure.mqh
│   ├── SignalScoring.mqh
│   ├── RiskManager.mqh
│   ├── TradeManager.mqh
│   ├── StrategyM1.mqh
│   ├── StrategyM5.mqh
│   ├── StrategyM15.mqh
│   └── UI.mqh
├── SPEC.md
├── ARCHITECTURE.md
├── DEVELOPMENT.md
└── README.md

Do not create unnecessary abstraction merely for the sake of having many files.

---

2. Core Components

Configuration

Responsible for:

- EA inputs
- Mode settings
- Indicator settings
- Risk settings
- Trade management settings
- Protection settings

---

Indicator Engine

Responsible for:

- EMA values
- RSI
- ATR
- Multi-timeframe indicator access

Use proper MQL5 indicator handles.

Avoid repeatedly creating indicator handles on every tick.

Create handles during initialization and release them during deinitialization.

---

Market Structure Engine

Responsible for detecting:

Bullish

- Higher High
- Higher Low

Bearish

- Lower High
- Lower Low

The logic must be deterministic.

Document the lookback and swing-detection method.

---

Pullback Engine

Responsible for determining whether price has retraced toward:

- EMA 9
- EMA 21
- EMA/support area

The implementation must be deterministic.

---

Confirmation Engine

Responsible for:

- Bullish confirmation candle
- Bearish confirmation candle

Only closed candles should be used.

---

Trend Engine

Responsible for determining:

- M15 trend
- M5 trend
- M1 trend

Trend determination should use the strategy requirements in SPEC.md.

---

Signal Scoring Engine

Create a reusable scoring function.

Example conceptual structure:

CalculateSignalScore(
    timeframe,
    direction
)

Return:

score
criticalConditionsPassed
signalValid

The exact scoring weights should be documented.

---

Strategy Engines

Create separate strategy logic for:

M1Strategy
M5Strategy
M15Strategy

Each strategy should:

1. Check market conditions.
2. Check trend.
3. Check pullback.
4. Check structure.
5. Check RSI.
6. Check ATR.
7. Check confirmation candle.
8. Calculate score.
9. Check minimum score.
10. Return a signal or NO TRADE.

---

3. Auto Mode

Auto mode should call the individual strategy engines.

Conceptually:

M1 signal
M5 signal
M15 signal
        ↓
validate
        ↓
rank valid setups
        ↓
select strongest setup
        ↓
risk checks
        ↓
execute at most permitted position(s)

Do not let each strategy independently execute trades in Auto mode.

Auto mode must have one central execution decision.

---

4. Risk Manager

Responsible for:

- Risk percentage
- Lot calculation
- Daily loss protection
- Maximum trades
- Maximum positions
- Margin checks

Position sizing should account for broker-specific:

- Volume minimum
- Volume maximum
- Volume step
- Tick size
- Tick value

---

5. Trade Manager

Responsible for:

- Opening positions
- SL
- TP
- Break-even
- Trailing stop
- Maximum holding time
- Existing position management

Existing positions should continue to be managed even when new trading is disabled.

---

6. Execution Safety

Before opening a position:

Trading enabled?
        ↓
Daily loss limit okay?
        ↓
Trade limit okay?
        ↓
Signal valid?
        ↓
Minimum score reached?
        ↓
Spread okay?
        ↓
Margin okay?
        ↓
Lot size valid?
        ↓
SL valid?
        ↓
TP valid?
        ↓
Execute

Any failed check must result in:

"NO TRADE"

---

7. New-Bar Processing

Avoid calculating expensive strategy logic on every tick unnecessarily.

Use new-bar detection for signal generation.

Trade management such as trailing stops may still run on every tick where necessary.

Do not enter multiple times from the same candle.

---

8. Timeframe Data

Use MQL5 timeframe constants:

- PERIOD_M1
- PERIOD_M5
- PERIOD_M15

Do not assume the chart timeframe is the strategy timeframe.

The EA should request the required timeframe data directly.

---

9. Position Identification

Use:

- Magic Number
- Symbol
- Position type

Do not accidentally manage unrelated manual trades or other EAs.

---

10. Chart UI

Provide a simple trading status control.

Example:

[ TRADING ON ]

or:

[ TRADING OFF ]

Clicking it should toggle new-entry permission.

Do not make the UI unnecessarily complex.

---

11. Error Handling

Every important trading operation should check its return value.

Log:

- Error code
- Operation
- Symbol
- Relevant parameters

Do not silently ignore trade failures.

---

12. Code Quality

Prefer:

- Small functions
- Clear names
- Enums
- Structs where useful
- Constants for fixed values
- Centralized configuration
- Reusable indicator functions

Avoid:

- Global spaghetti state
- Copy-pasted strategy logic
- Magic numbers scattered throughout the code
- Recreating indicator handles every tick
- Unnecessary dependencies

The final EA must compile cleanly in MetaEditor.