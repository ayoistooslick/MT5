Development Rules

1. Primary Objective

Implement the requirements in "SPEC.md".

"SPEC.md" is the source of truth for functionality.

"ARCHITECTURE.md" describes the preferred implementation structure.

Do not silently remove or weaken requirements.

---

2. Build From Scratch

There is no existing EA source code.

Do not expect an existing implementation.

Create the project from scratch.

---

3. MQL5 Only

The trading EA itself must be written in valid MQL5.

Do not generate:

- Python trading logic
- MQL4 code
- MT4-specific APIs
- Pseudo-code presented as finished implementation

The final deliverable must be compilable as an MT5 Expert Advisor.

---

4. Deterministic Rules

The EA cannot understand subjective human descriptions.

Every requirement must be translated into measurable logic.

For example:

Bad:

Detect a strong bullish market.

Good:

Detect a higher high and higher low using a defined swing lookback.

If a requirement is ambiguous, choose a sensible deterministic implementation and document the assumption in "README.md".

Do not silently invent completely unrelated strategy rules.

---

5. Closed Candle Confirmation

Entry confirmation must use closed candles.

Do not use an unfinished candle as the final confirmation.

Be careful with MQL5 bar indexing.

---

6. Indicator Handles

Create indicator handles efficiently.

Do not repeatedly call indicator creation functions on every tick.

Release handles correctly during deinitialization.

---

7. Multi-Timeframe Data

Always request data from the correct timeframe.

Do not assume:

Period()

is the strategy timeframe.

Use explicit timeframe constants.

---

8. No Lookahead Bias

Backtesting logic must not use future candles.

Do not reference information that would not have been available at the moment the signal was generated.

This is especially important for:

- Market structure
- Pullbacks
- Confirmation candles
- MTF calculations

---

9. Duplicate Trade Prevention

The same signal must not trigger repeatedly on every tick.

Use:

- New-bar detection
- Signal state
- Position checks
- Appropriate identifiers

---

10. Risk Calculations

Risk-based position sizing must use actual symbol properties.

Consider:

- Tick size
- Tick value
- Contract specifications
- Volume step
- Minimum volume
- Maximum volume
- Account equity/balance

Normalize volume correctly.

Never blindly assume every broker uses the same symbol specifications.

---

11. Stop Loss

Never open a trade without a valid SL.

Validate broker minimum stop distance before sending the order.

If the calculated SL is invalid:

"NO TRADE"

Do not simply remove the SL to force execution.

---

12. Trade Execution

Check every order result.

Handle:

- Requotes/rejections where applicable
- Invalid volume
- Invalid stops
- Insufficient margin
- Market closed
- Trading disabled
- Other broker errors

Provide useful logs.

---

13. Trading ON/OFF

The master trading switch must only disable new entries.

Existing positions must continue receiving normal management unless the specification explicitly changes this behavior.

---

14. Daily Loss Protection

Daily loss protection must prevent new entries once the configured limit is reached.

It must not accidentally reset every tick.

The daily reset must use a reliable trading-day calculation.

---

15. Testing Order

After implementation:

Stage 1

Compile in MetaEditor.

Fix every compilation error.

Stage 2

Resolve warnings that could affect correctness.

Stage 3

Run Strategy Tester.

Test:

- M1 mode
- M5 mode
- M15 mode
- Auto mode

Stage 4

Test:

- Trading ON
- Trading OFF
- Spread rejection
- Daily loss protection
- Maximum trade limits
- Invalid lot sizes
- Insufficient margin
- Duplicate signals
- Existing position management

Stage 5

Test different symbols and broker specifications where possible.

---

16. Do Not Optimize for Profit During Initial Development

First prove that the EA correctly implements the strategy.

Do not manipulate parameters simply to produce attractive backtest results.

Do not introduce curve-fitting or future-data leakage.

Correctness comes before optimization.

---

17. Logging

Logs should explain why signals are rejected.

Examples:

M1 BUY rejected: M15 trend not bullish
M1 BUY rejected: score 87 < 90
M5 SELL rejected: spread above maximum
M15 BUY rejected: ATR below minimum
Trade opened: M5 BUY
Trading disabled: no new entries
Daily loss limit reached

Avoid printing the same message hundreds of times per second.

---

18. Documentation

Create/update "README.md" with:

- Installation
- Compilation
- Inputs
- Trading modes
- Strategy explanation
- Risk controls
- ON/OFF button
- Backtesting instructions
- Known assumptions
- Limitations

Do not claim guaranteed profitability.

---

19. Agent Behavior

Before modifying code:

1. Read "SPEC.md".
2. Read "ARCHITECTURE.md".
3. Inspect the repository.
4. Identify missing components.
5. Implement incrementally.
6. Compile/check after major changes.
7. Fix errors before moving forward.

Do not replace working code unnecessarily.

Do not create fake test results.

Do not claim the EA compiles unless compilation has actually been verified.

Do not claim profitable backtests unless actual tests demonstrate it.

---

20. Final Requirement

The finished result must be a real MT5 Expert Advisor that can be opened in MetaEditor and compiled.

It must prioritize:

1. Correctness
2. Risk control
3. Deterministic strategy logic
4. Maintainability
5. Testability

Profitability is NOT guaranteed.