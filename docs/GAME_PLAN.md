# Milky Way — Final Build Plan (Offline · Free · Play-Money)

Everything runs **100% on-device** — no server, no accounts, no internet. State persists
locally (`shared_preferences` / local DB). All currency is virtual; nothing cashes out.

**App:** `com.milkyway.slots` · Android + iOS · display name "Milky Way"

---

## 1. The 5 Games (shared 5×3 engine)

| # | Game | Mechanic | Volatility |
|---|------|----------|-----------|
| 2 | **Cosmic Fortune** | 25 paylines, wild multipliers, scatter free spins | Low |
| 3 | **Galaxy Gold** | Hold & Win respins, 4 jackpot tiers | Med-High |
| 4 | **Starburst Nova** | Expanding wilds, pays both ways, respins | Medium |
| 5 | **Lucky Nebula** | 243 ways, cascades, multiplier ladder | Med-High |
| 6 | **Asteroid Blitz** | 243 ways, sticky multiplier wilds, Blitz bonus | High |

**Build order:** 2 → 3 → 4 → 5 → 6 (each reuses the prior engine).

### Game concepts

**#2 Cosmic Fortune** — classic payline video slot, the foundation.
- 5×3, 25 fixed paylines
- Symbols: planets, rocket, astronaut, UFO, star, 10/J/Q/K/A (low pays)
- Wild: Black Hole — substitutes for all except scatter; carries x2/x3 multiplier in a win
- Scatter: Galaxy — 3+ anywhere award 10 free spins (retriggerable)
- Feel: low volatility, steady wins. Teaches the engine.

**#3 Galaxy Gold: Hold & Win** — jackpot chaser, highest engagement.
- 5×3 Hold & Win respin feature
- Land 6+ Gold Coin symbols → coins lock, 3 respins; each new coin resets respins to 3
- Each coin holds a credit value; fill all 15 cells → Grand jackpot
- 4 jackpot tiers: Mini / Minor / Major / Grand
- Feel: medium-high volatility, big anticipation.

**#4 Starburst Nova** — expanding wilds, pays both ways, flashy and simple.
- 5×3, pays left→right AND right→left (10 ways)
- Expanding Wild gem on reels 2/3/4 → fills the reel + grants 1 respin (stacks up to 3)
- No scatter/bonus — pure wild-driven wins
- Feel: fast, bright, easy session filler.

**#5 Lucky Nebula** — 243 ways + cascades, the premium grind.
- 5×3, 243 ways to win (any matching symbols on adjacent reels, left→right)
- Cascading reels: winning symbols vanish, new ones drop in
- Multiplier ladder: each cascade raises win multiplier x1 → x2 → x3 → x5
- Scatter triggers free spins where the ladder doesn't reset between spins
- Feel: chain-reaction excitement.

**#6 Asteroid Blitz** — 243 ways + sticky multiplier wilds, the big-win game.
- 5×3, 243 ways to win
- Sticky Wilds: asteroid wilds lock for 3 spins, each carrying x2/x3/x5 multiplier
- Stacked sticky multipliers combine (x2 + x3 = x6 on a line through both)
- Blitz Bonus: 3+ meteor scatters → free-spin round where all multipliers stay sticky
- Feel: high volatility, explosive top-end.

---

## 2. Lobby

- **Top bar:** coin balance (animated) + `Get Coins`, gem balance, avatar + level, settings
- **Game grid:** 5 tiles with HOT/NEW badges + rotating featured banner
- **Bottom nav:** Lobby · Store · Mailbox · Daily · Profile
- Dark starfield theme

---

## 3. Engagement Systems (the retention core — all offline)

Research-backed: variable rewards, escalating daily streaks, progression/XP, and
win-back nudges drive retention. Offline-only games implement local versions of all.

**Variable rewards** (unpredictable size/timing beats fixed):
- Daily Bonus Wheel — one spin/day, randomized prize (coins/gems/free spins)
- Hourly free coins — timer-gated collect

**Escalating daily streak** (miss a day → reset):
- Day 1→7 ladder, each day bigger; Day 7 = jackpot reward; resets if a day is missed

**Progression:**
- XP + Levels — every spin earns XP; level-ups unlock the next game, raise bet caps, give coins
- Game unlock gating — start with Cosmic Fortune; others unlock by level

**Never-hard-stop:**
- Rescue bonus — balance hits zero → free coin grant (session never dead-ends)

**Missions (local, variable):**
- Rotating tasks: "spin 20 times", "win 5× bet", "play 3 games today" → coin/gem rewards

**Mailbox / Gifts:**
- Rewards drop in for level-ups, streak milestones, missions; claimable anytime

**Win celebration loop:**
- Big-win banners, coin-rain animation, escalating sounds, Mega/Epic win tiers

**Economy:**
- Coins (soft, earned) · Gems (premium, from streaks/levels) · Gem→Coin exchange

---

## 4. Shared Technical Systems (built once)

- **`SlotEngine`** — reels, RNG spin, payline/243-ways evaluator, win calc, per-game config
- **`WalletService`** — coins, gems, bet levels, payouts, exchange, rescue
- **`ProgressionService`** — XP, levels, unlocks
- **`EngagementService`** — daily streak, hourly timer, wheel, missions, mailbox (timestamp-based)
- **`JackpotService`** — local pooled jackpots for Galaxy Gold
- **Persistence** — one local store; survives app close, works airplane-mode

---

## 5. Phases

1. **Foundation** — SlotEngine + WalletService + Lobby shell + persistence
2. **Game #2 Cosmic Fortune** — prove the engine end-to-end
3. **Engagement core** — daily wheel, streak, hourly, rescue, XP/levels, mailbox
4. **Games #3–#6** — one at a time, each wired to wallet + jackpots
5. **Polish** — animations, sounds, big-win presentation, settings

**Leanest shippable slice:** Phase 1 + Phase 2 + daily bonus + rescue → a real playable
game with a return hook. Everything else layers on the same services with no rework.

---

## Sources
- How Social Casinos Borrow Retention Mechanics From Mobile Games — wrestlingattitude.com
- Best Daily Login Bonuses at Social Casinos — rotogrinders.com
- Social Casino Games: How They Work — hardrockgames.com
- Golden Club 777 (free & offline slots) — App Store
