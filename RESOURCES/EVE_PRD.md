# EVE — Product Requirements Document

**Tagline:** The World Redesigned for Her
**Hackathon:** Hack26 (IEEE MACE)
**Doc status:** v1 — Draft for hackathon build

---

## 1. Problem Statement

Women's health apps today are fragmented and reactive. Period trackers only track periods. Fitness apps ignore hormonal cycles. Mental health apps don't connect mood to physiology. And almost none of them involve the people around her — partners are left out entirely, reduced to guessing why she's having a hard week.

The result: women manage their health across five disconnected apps, none of which adapt to *who they are* or *what stage of life they're in*, and the people who care about them have no way to meaningfully support them without being told, explicitly, every time.

**EVE reframes this as a single problem:** health tracking fails when it's transactional (log data → get a chart). It succeeds when it's relational — when something is paying attention, learning your patterns, and translating that into real support, for you and for the people around you.

---

## 2. Core Idea

EVE is an AI-powered adaptive life companion for women, built around a **Duolingo-style mascot** that acts as the single interface for health tracking, insight delivery, and partner connection.

Instead of a form-based tracker, the user *talks to* a pet/mascot. The mascot asks light, natural check-in questions, reacts emotionally to what she shares, and — over time — starts proactively surfacing insights ("you're in your luteal phase, heavy lifting may feel harder today"). The mascot is the face of the product; underneath it sits a cycle-aware AI health engine.

EVE also introduces **Partner Mode**: a linked, consent-gated view that lets a partner receive gentle, non-invasive nudges ("she's had a tough week, check in on her") instead of raw data — plus an in-app encrypted 1:1 chat so support happens inside the product, not as an afterthought.

---

## 3. Target Users

| User | Role |
|---|---|
| **Primary user (Her)** | Any woman tracking her cycle, symptoms, mood, fitness, or health journey — from adolescence through menopause. |
| **Secondary user (Partner)** | A spouse/partner opted in by the primary user to receive supportive nudges and share a private chat. |

---

## 4. Core Mechanic: The Mascot as Data Layer

The mascot is not decorative — it's the product's primary UX pattern, solving the #1 churn problem in health apps (tedious manual logging).

**Loop:**
1. Mascot initiates or responds to a check-in ("How are you feeling today?")
2. User replies conversationally or via quick-tap options (mood, pain, sleep, symptoms)
3. Mascot reacts with personality (concern, encouragement, celebration)
4. Response is silently parsed into structured health data
5. Mascot uses accumulated data + cycle phase to deliver a personalized insight or nudge
6. Streak/care-score mechanic rewards consistent check-ins (Duolingo-style habit loop)

This turns logging into a relationship rather than a chore, and gives the AI a continuous, low-friction data stream to personalize against.

---

## 5. Feature Set

### 5.1 MVP — Hackathon Build Scope

| Feature | Description |
|---|---|
| **Mascot chat interface** | Conversational check-in flow; central hub for all interaction |
| **Cycle & ovulation prediction** | Core calendar logic; drives phase-aware insights |
| **Phase-aware insights** | e.g. cycle-aware gym mode — "heavy lifting may feel harder today, you're in late luteal phase" |
| **PMS / mood / pain logging** | Captured via mascot conversation, feeds insight engine |
| **Nutrition recommendations** | Basic phase-based suggestions |
| **Partner Mode (stub)** | Second linked view; receives mock supportive nudges triggered by low mood logs |
| **In-app 1:1 chat (stub)** | Simple chat UI between the two linked accounts (encryption can be described, not fully implemented) |
| **Doctor-ready summary generator** | One AI call that compiles logged data into a clean, exportable summary |

### 5.2 Full Product Vision (Roadmap — Not Built for Hackathon)

- Fertility planning / conception support
- Pregnancy & postpartum modules
- PCOS / Endometriosis risk flagging
- Sleep correlation analysis
- Mental health correlation over time
- Adolescence-specific onboarding and education
- Real end-to-end encrypted partner chat
- Wearable integration (sleep, heart rate)

---

## 5.3 Personalization Engine — Modular Feature Mapping

EVE is not one fixed feature set shown to everyone — it's a **library of modules**, and the mascot's onboarding conversation determines which modules are switched on for a given user. This is what makes it personalized rather than just customizable (customization = user manually toggles things; personalization = the product figures out what she needs and shows only that).

**How it works:**
1. During onboarding, the mascot asks a short set of conversational questions — not a form: life stage, current goal (avoid pregnancy / trying to conceive / just tracking / pregnant / postpartum), and any relevant health context she chooses to share.
2. Answers map to a **life-stage profile**, which activates a specific module set.
3. The module set isn't static — it re-evaluates as her answers change over time (e.g. she updates status from "trying to conceive" to "pregnant," and the module set shifts automatically, with the mascot acknowledging the transition rather than silently swapping screens).

**Module-to-stage mapping (from the researched feature list):**

| Module | General tracking | Trying to conceive | Pregnant | Postpartum |
|---|:---:|:---:|:---:|:---:|
| Period & cycle prediction | ✅ | ✅ | — | — |
| Ovulation prediction | ✅ | ✅ | — | — |
| Pregnancy avoidance / conceiving guidance | ✅ (avoidance) | ✅ (conceiving) | — | — |
| PMS symptom logging | ✅ | ✅ | — | — |
| Mood tracking | ✅ | ✅ | ✅ | ✅ |
| Pain logs | ✅ | ✅ | ✅ | ✅ |
| Nutrition recommendations | ✅ | ✅ (fertility-focused) | ✅ (trimester-based) | ✅ (recovery-based) |
| Cycle-aware gym mode | ✅ | ✅ | pregnancy-safe variant | postpartum recovery variant |
| Sleep correlation | ✅ | ✅ | ✅ | ✅ |
| PCOS / Endometriosis risk flags | ✅ | ✅ | — | — |
| Mental health correlation | ✅ | ✅ | ✅ | ✅ (incl. postpartum mood screening) |
| Pregnancy milestone tracking | — | — | ✅ | — |
| Appointment / medication reminders | optional | ✅ | ✅ | ✅ |

**Why this matters for the pitch:** it directly answers "the world redesigned for her" — the product reshapes itself around *her specific stage*, instead of asking every woman to navigate a bloated, one-size-fits-all app. For the hackathon demo, this is a strong show-don't-tell moment: onboard as two different personas live and show the module set visibly change.

**Hackathon scope note:** build the mapping logic for 2 stages (e.g. General tracking + Pregnant) to keep the demo tight, but present the full table above as the designed system.

---

## 6. Partner Mode — Design Principles

Partner Mode is a differentiator, but it only works if it doesn't feel like surveillance. Ground rules:

- **Opt-in, granular consent.** She chooses what categories (mood, symptoms, none) are visible to her partner — never raw logs by default.
- **Nudges, not data dumps.** Partner sees *"she's having a tough week, consider checking in"* — never the underlying symptom log.
- **Her control is the feature.** The redesign isn't just tracking her — it's putting her in control of who knows what, when.
- **Chat is the support channel.** Rather than partner passively viewing dashboards, the product's real support mechanism is a direct, private conversation.

---

## 7. Success Metrics (for demo/pitch framing)

| Metric | Why it matters |
|---|---|
| Check-in completion rate via mascot vs. traditional form | Proves the mascot reduces logging friction |
| Insight relevance / phase-prediction accuracy | Core value proposition of "adaptive" |
| Partner nudge → chat response rate | Validates Partner Mode's actual utility, not just novelty |
| Doctor-summary generation quality | Judged demo moment; shows AI companion has real utility beyond chat |

---

## 8. Technical Architecture (High-Level)

- **Frontend:** Mascot chat UI (primary), calendar/dashboard views (secondary), Partner Mode view (linked account)
- **AI layer:** LLM-driven conversational check-ins + insight generation, prompted with cycle-phase context and logged history
- **Cycle engine:** Rules-based prediction (cycle length, phase calculation) feeding both the AI layer and the calendar
- **Data model:** Per-user health profile (cycle data, symptom logs, mood logs) + linked partner-account relationship with consent flags per data category
- **Doctor summary:** Single AI call over structured log data → formatted export (PDF/text)

---

## 9. Miscellaneous / Stretch Ideas (Not Core Scope)

Ideas worth mentioning in the pitch as future direction, but not required for the hackathon build:

- **Action-oriented mascot via MCP integrations.** Instead of only detecting a mood dip or PMS symptom and logging/nudging, the mascot could *act* — e.g. connecting to a quick-commerce app (Blinkit-style) via MCP to order comfort essentials (chocolate, heating pad, sanitary products, pain relief) the moment a low-mood or high-pain check-in is logged. This moves EVE from "tracks and advises" to "tracks, advises, and helps directly" — a strong differentiator if demoed, even as a mocked/simulated call.
- **Monthly positive-report digest.** A scheduled Cloud Function (the same `onSchedule` pattern as the reminder dispatcher, just a monthly cadence) pulls her logged data from the past month and calls the same AI proxy used for doctor-ready summaries — but with a different prompt, explicitly instructed to frame the month positively and encouragingly rather than clinically (a "here's how far you've come" narrative, not a symptom list). The result is stored as `users/{uid}/monthlyReports/{yyyy-mm}` and surfaced via an FCM notification ("Your EVE monthly report is ready"), reusing the same notification infrastructure built for the nine onboarding-selected reminder types.

These should be framed as "designed for" in the pitch, not built live, unless time allows a simple mocked MCP call as a demo flourish.

---

## 10. Out of Scope (Explicitly, for the Pitch)

- Medical diagnosis of any kind — EVE surfaces risk flags and patterns, never diagnoses; always recommends professional consultation
- Real-time wearable integration
- Full encryption implementation (described in architecture, not built live)
- Non-cycle life stages beyond the demoed phase(s)

---

## 11. One-Line Pitch

**EVE turns health tracking into a relationship — a mascot that learns her, adapts to her, and brings the people who love her into the loop, on her terms.**
