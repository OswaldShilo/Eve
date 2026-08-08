# EVE — Complete Product Requirements Document (v2 — Consolidated, Expanded)

**Tagline:** The World, Redesigned for Her
**Track:** The World Redesigned for Her — Hack26 / >.hack();_ '26
**Reference mock:** `mockv4.html` — UI/UX flow specification only. The HTML file is not shipped as the product; it exists purely to lock in screen structure, copy, and interaction logic before the real Flutter build begins.

---

## 1. Problem Statement

Women's health tracking today is fragmented, reactive, and built around a single moment in time rather than a continuous journey. A period tracker only tracks periods. A fitness app has no idea what phase of her cycle she's in, so it prescribes the same workout intensity on day 3 as day 24, even though her body responds very differently across the month. A mental health app logs mood in isolation, with no visibility into whether that dip correlates with PMS, a poor night's sleep, or something else entirely. None of these tools know — or ask — what stage of life she's actually in.

The result is that a woman moving through cycle tracking, fertility planning, pregnancy, postpartum recovery, or perimenopause is forced to piece together her own understanding across four or five disconnected apps, none of which talk to each other, none of which adapt as her needs change, and most of which she abandons within a few weeks because logging data manually, over and over, into a form, simply isn't something people sustain without a reason to come back.

This is not just an inconvenience — it's a data continuity problem. A doctor's appointment where she's asked "when did this symptom start" or "how has your mood tracked against your cycle" often gets answered with a shrug, not because she doesn't care about her health, but because the tools available to her were never designed to make that information easy to retain, connect, or hand over.

And critically, the people around her — partners, spouses — are almost entirely excluded from this picture. Existing apps treat her health as a solitary dataset. A partner who wants to be supportive has no structured way to understand what she's going through unless she explicitly stops and explains it, every single time, which is its own quiet burden to place on someone already managing a lot.

This affects a very large population — effectively every woman navigating any stage of reproductive or hormonal health, which is to say, most women, most of their lives — and it represents a genuine missed opportunity: to make health tracking something that adapts to a person rather than asking the person to adapt to a form, and to make the people who love her active participants in her care rather than bystanders.

---

## 2. Core Idea

EVE is an AI-powered adaptive life companion for women, built around a Duolingo-style mascot named Eve (visually a pomegranate character, internally sometimes referred to as "Pomme") who acts as the single conversational interface for a woman's entire health journey, from the very first screen of onboarding through daily use.

Rather than presenting a static dashboard of trackers and forms, EVE reframes the entire interaction model: instead of filling out a symptom log, the user talks to Eve. Eve asks the questions, reacts to the answers with genuine visual personality (not just decoratively — her expression, posture, and even physical growth stage change based on context), and over time uses everything she's learned to surface insights that feel earned rather than generic — the kind of thing a genuinely attentive companion would notice, not a rules engine spitting out a templated tip.

The product rests on three pillars, each of which solves a distinct piece of the problem statement above:

**Pillar 1 — Modular Personalization.** EVE is not one fixed feature set shown identically to every user. During onboarding, a branching survey determines her life stage — tracking her cycle, trying to conceive, currently pregnant, postpartum, or navigating perimenopause/menopause — and the entire feature set reshapes around that answer. A pregnant user never sees ovulation prediction. A user trying to conceive never sees postpartum recovery tracking. This isn't a settings toggle she has to configure herself; it's the product understanding her and adjusting automatically, the same way a good doctor doesn't ask a pregnant patient about birth control.

**Pillar 2 — Mascot-Driven Engagement.** Eve is present, visible, and speaking on every single screen of the app — including every screen of onboarding, which is the part most products treat as a disposable, get-through-it formality. This matters because onboarding is precisely where most health apps lose people: it's tedious, it feels like paperwork, and there's no payoff yet. By having Eve guide, react to, and comment on every question as it's asked, the onboarding survey stops feeling like a form and starts feeling like the beginning of a relationship. This same mascot then carries into daily use, where a genuine gamification system (streaks, points, unlockable visual variations, celebratory completion screens) gives her real reasons to keep returning — modeled on what actually makes Duolingo's loop work, not just borrowing its owl.

**Pillar 3 — Partner Mode.** An opt-in, consent-gated channel that lets a partner (husband, boyfriend, or partner) receive gentle, supportive nudges and participate in a shared in-app chat — without ever seeing her raw health data unless she has explicitly approved that specific category of information. This is the piece that answers "world redesigned for her" most literally: it's not just that the app adapts to her, it's that the people around her are brought into a structure that centers her control over her own information, rather than assuming access.

---

## 3. Target Users

**Primary user — Her.** Any woman actively managing her health across any life stage covered by the app: general cycle tracking, fertility planning, pregnancy, postpartum recovery, or perimenopause/menopause. She is the one who owns the account, completes onboarding, and decides what — if anything — gets shared outward.

**Secondary user — Partner.** A spouse, boyfriend, or partner who has been explicitly invited by the primary user during onboarding (or later, from settings). This user has no independent account creation flow into the "her" experience — they exist only as a linked, permission-scoped identity, and their entire experience is intentionally narrower than hers: a chat thread, and whatever categories of nudges she has approved.

---

## 4. Full Onboarding Flow (Screen-by-Screen)

This is the definitive sequence, built out in detail in `mockv4.html`, and it exists because the original notes and wireframe sketches this product was built from specified nearly every question verbatim — this section documents that structure faithfully rather than abstracting it away.

**Entry.** The app opens on a splash screen where Eve animates in — a bounce/scale entrance, not a static logo — followed by the app wordmark and tagline. From there, the user authenticates via Google Sign-In, which pre-fills her name for the next step.

**Basic Profile (Section 1).** A single screen collecting Name (editable, pre-filled from auth), Age, Height, Weight, and Country. This is deliberately kept short — five fields, not fifteen — because the goal at this stage is just enough identity to make later screens feel personal, not a full intake form.

**Life-Stage Selector (Section 2 — the core branch point).** The single most important screen in the entire flow: "Which describes you best?" with five large, tappable options — Tracking my cycle, Trying to conceive, Currently pregnant, Postpartum, and Perimenopause/Menopause. Whatever she selects here determines every subsequent branch, and ultimately which modules appear on her Home dashboard for the lifetime of her use of the app (until she updates it).

**Branch-Specific Screens.** Each life-stage selection routes into its own sub-flow:

- *Tracking my cycle* leads to a Cycle Information screen (average cycle length, average period length, flow — light/moderate/heavy), a Symptoms screen (an eleven-option multi-select including cramps, acne, headache, breast tenderness, bloating, mood swings, back pain, fatigue, food cravings, nausea, or none), and a Goals screen (predict next period, understand my body, improve fitness, better nutrition with a veg/non-veg/vegan sub-choice, or improve mental wellbeing).
- *Trying to conceive* leads to screens covering how long she's been trying, whether she's tracking ovulation, current medications (folic acid, iron, vitamin D, none, others), relevant medical conditions (PCOS, PMS, endometriosis, thyroid, diabetes, none), and her goals (understand fertile window, improve health, nutrition, track ovulation).
- *Currently pregnant* leads to a due-date screen (she can enter an expected due date, first day of last period, or a doctor's estimated week, plus high-risk status and single/twins), a medication and care screen (current medication, allergies — used downstream to filter food suggestions — and prenatal vitamin use), and a symptoms screen (morning sickness, swelling, back pain, heartburn, headache, none).
- *Postpartum* leads to a delivery-info screen (normal delivery or C-section, feeding method), a current-state screen (mood, sleep), and a goals screen (recovery pain, lose weight, recover strength, mental wellbeing, baby schedule — the last of which is explicitly flagged as a future addition rather than an MVP requirement).
- *Perimenopause/Menopause*, the one branch not detailed in the original handwritten notes, is built to mirror the structural pattern of the others: a symptom check (hot flashes, sleep disturbances, mood changes, irregular cycles, none) and a goals screen (understand what's happening to my body, manage symptoms, nutrition, mental wellbeing).

For the hackathon build, *Tracking my cycle* and *Pregnant* are built at this full multi-screen depth; the remaining three branches are collapsed into a single combined symptom-plus-goals screen each, so all five options remain genuinely selectable and functional in the demo without requiring the full build depth of every path.

**Common Survey (all users, regardless of branch).** After her stage-specific questions, every user passes through the same three screens: Food Preferences (allergies, preferred cuisines), Workout Preference (walking, yoga, gym, home workout, dance, pilates), and Notification Preferences (a nine-option multi-select spanning morning reminders, medicine reminders, workout reminders, water reminders, sleep reminders, cycle reminders, appointment reminders, mood reminders, and a daily AI tip).

**AI Assistant Scope.** A single screen asking what she'd like Eve to help with — answering health questions, nutrition, workouts, mental wellbeing, medication reminders, doctor prep, or everything, where selecting "everything" auto-selects the rest.

**Partner Mode Setup.** She's asked whether she'd like to invite a partner. If yes, she specifies the relationship (husband, boyfriend, partner) and then reaches the single most consequential screen in the survey: Partner Permissions, where she individually opts each category of information in or out — appointment reminders, pregnancy milestones (shown only if she's pregnant), support suggestions, mood reminders — alongside a master "only what I approve" toggle that, when enabled, defaults everything to withheld until she explicitly grants it. This screen is where the product's entire "her control" principle becomes a concrete, visible mechanism rather than a claim in a pitch deck.

**Personalization.** A simple theme screen — light, dark, or default, with more themes explicitly noted as a future addition rather than something to build now.

**Completion.** A celebratory screen reading "Your EVE is ready," with the mascot in its most positive, high-energy state and (where the mascot rig supports it) a confetti moment, before transitioning into the main app.

Eve is present — a mini version of the mascot plus a distinct, screen-specific line of guidance — on every single one of these screens, including the branch-specific and common survey screens, which was a deliberate fix applied after early mock iterations left her only on the bookend screens (Welcome and Completion) and absent for the entire substantive part of onboarding.

---

## 5. Modules and the Personalization Map

The table below is the concrete, buildable expression of "modular personalization" — it's what determines, module by module, whether a given feature appears on a given user's Home dashboard, computed from her stored life-stage value rather than toggled manually.

| Module | General tracking | Trying to conceive | Pregnant | Postpartum | Perimenopause |
|---|:---:|:---:|:---:|:---:|:---:|
| Cycle & ovulation tracking | Yes | Yes | No | No | No |
| Symptom & mood logging | Yes | Yes | Yes | Yes | Yes |
| Nutrition & fitness (cycle-aware) | Yes | Yes, fertility-focused | Yes, trimester-based | Yes, recovery-based | Yes |
| Pregnancy milestones & appointments | No | No | Yes | No | No |
| Postpartum recovery tracking | No | No | No | Yes | No |
| Partner Mode | Optional | Optional | Optional | Optional | Optional |
| Doctor-ready summary export | Yes | Yes | Yes | Yes | Yes |

A few of these modules deserve explanation beyond the table. **Nutrition & fitness** is deliberately the same module label across every life stage, but its content changes meaningfully underneath — a pregnant user sees trimester-appropriate guidance, a postpartum user sees recovery-focused guidance, and a general-tracking or trying-to-conceive user sees cycle-phase-aware guidance (the "heavy lifting may feel harder today, you're in late luteal phase" example from the original product notes lives here). **Doctor-ready summary export** is intentionally available to every user regardless of life stage, because the underlying need — walking into an appointment with clear, organized information instead of a vague memory — doesn't go away depending on what stage she's in.

---

## 6. The Mascot System (Eve / Pomme)

The mascot is not a decorative element bolted onto the UI; it is the product's primary interaction pattern, and it's built as an actual rigged character system rather than a static illustration. In the current mock, this is implemented as a custom SVG rig with physics-based idle animation (a continuous breathing and swaying motion so she never looks inert between events), blinking, eye-tracking that follows cursor movement, and drag interaction. In the Flutter rebuild, this entire system gets reimplemented natively via `AnimationController` and `CustomPainter` — a meaningfully different technical skill from CSS/SVG animation, and worth budgeting real time for specifically.

She supports five distinct emotion states — guilt, hype, sassy, hug, and fertile — all built from the same shared underlying rig (the same brow, eye, and mouth path system reused across states) rather than one-off custom animations, which keeps the character visually coherent no matter which state is active. The fertile-window state in particular was deliberately designed to be subtle rather than dramatic: her crown gently opens to hint at the seeds inside, in the same calm emotional register as the "hug" state, rather than becoming the single most intense animation in the set.

Every screen in the app, including every screen of onboarding, carries a mini version of Eve and a distinct, screen-specific line of guidance — never a generic, reused message. Her expression is chosen contextually: calm and neutral by default, visibly caring on emotionally sensitive screens (symptom logging, medical conditions, and especially the Partner Permissions screen, which is the single highest-stakes moment in the whole flow), and never celebratory during clinical or medical-information screens like medication or allergy entry, where an upbeat animation would feel tonally wrong.

The app's overall copy voice — including Eve's own lines — is formal and warm rather than cutesy: no emojis anywhere in the product, and phrasing that reads as direct and professional rather than jokey. Personality comes through her visual expressions and through the persona-mode system described below, not through exclamation points or slang in the text itself.

**Persona modes** — Guilt Trip, Unhinged Hype, Sassy, and Need Hugs — let the user choose how Eve communicates with her day to day. This started as a demo mechanic but is genuinely defensible as a real, shippable feature: different people want different kinds of accountability, and letting her pick her own tone (rather than the app deciding for her) is consistent with the broader "her control" principle that runs through the whole product.

---

## 7. Future Roadmap — Gamification & Engagement Layer (Not in Hackathon Scope)

This entire section is explicitly **out of hackathon build scope**, given everything else already on stake to be built (full branching onboarding, two life-stage depths at full detail, Partner Mode's server-side consent enforcement, AI proxy, chat, and calendar). It's documented here as direction for post-hackathon development, not as something to attempt under time pressure.

Duolingo's mascot works not because Duo is cute, but because Duo sits inside a complete system of streaks, points, and visible progress that gives every single interaction a payoff. If EVE pursues this after the hackathon, it should borrow that structural logic — not the visual style, and not the guilt-heavy notification tone, which needs to be handled more carefully in a health context (see Section 9).

**Streak counter.** Prominently displayed on Home, counting consecutive days of check-in activity — the most visible, most legible engagement signal in the app, and the anchor around which everything else here is built.

**Care Points.** A simple points currency, earned per check-in, per symptom log, and per supportive chat reply sent through Partner Mode, giving even small interactions a tangible sense of progress rather than disappearing into a log with no feedback.

**Daily goal ring.** A visible daily target — at minimum, one check-in — always present on Home, so there's a consistent, low-effort thing to complete every day rather than an open-ended, motivation-dependent task.

**Streak freeze.** A once-a-week grace token that protects her streak if she misses a day. This is a deliberate softening of Duolingo's harsher version of the same mechanic: in a health-tracking context, a missed day is often just life happening — a demanding day, an illness, exhaustion — and the product should treat it as handled rather than failed.

**Mascot wardrobe and unlockables.** At streak milestones (seven days, thirty days), she unlocks small visual variations for Eve — crown color variants or seasonal accessories, using the pomegranate's existing crown/seed motif as the natural canvas for this rather than introducing an unrelated cosmetic system. This is arguably the single most distinctive engagement idea in the whole product, precisely because it isn't a copy of Duolingo's wardrobe feature transplanted wholesale — it's built around what this specific mascot already visually is.

**Completion celebration.** Every check-in, not only the end of onboarding, closes on a small payoff screen: Eve in her most positive state, a confetti moment, and a one-line summary of points and streak progress — Duolingo never lets an interaction end flatly, and neither should this.

**Sound.** A small number of short, deliberate sound effects — a check-in confirmation chime, a streak-milestone sound — which is cheap to build and disproportionately effective at making a demo or a real product feel finished rather than provisional.

**Notification personality.** When push notifications are built out, reminder copy should be drawn from a small pool of varied phrasings per reminder type rather than a single fixed string, so Eve never sends the exact same message twice in a row — this is a large part of why Duolingo's notifications read as alive rather than templated.

---

## 8. Partner Mode

Partner Mode exists to solve a specific, real problem: partners who want to be supportive but have no structured way to understand what a woman is going through without her having to explain it, unprompted, every time. The design deliberately does not turn this into a surveillance mechanism.

During onboarding, she chooses whether to invite a partner and specifies the relationship. If she opts in, she reaches the Partner Permissions screen and individually approves categories of information — appointment reminders, pregnancy milestones where relevant, general support suggestions, and mood reminders — with a master toggle available to withhold everything by default until she grants it explicitly, category by category.

Architecturally, this consent model is enforced on the server, not just represented in the UI: a partner never has read access to her raw logs. Instead, a separate `partner_view` document is recomputed by a server-side function every time her relevant data changes, containing only the categories she's approved, and it's this filtered projection — not her actual health records — that the partner's side of the app ever reads. This distinction matters because trying to enforce granular, per-field privacy purely through client-side filtering or loosely-written security rules is easy to get subtly wrong, and this is exactly the kind of implementation detail a technically sharp judge is likely to probe.

The shared experience between the two of them is an in-app chat, where ordinary human messages sit alongside distinct, visually different system messages generated by Eve herself — for example, a message noting that she logged a difficult day and that this might be a good moment to reach out — which is the mechanism that actually closes the loop between her logging something and him knowing to respond, without her having to initiate that conversation herself every time.

---

## 9. Design Principles (Guardrails, Not Just Features)

**Her control is the feature, not a side effect of privacy compliance.** Every category of data visible to a partner is opt-in and reversible. This is the literal, concrete form that "the world redesigned for her" takes in this product — not a slogan, but an actual mechanism she can point to and explain.

**Guilt has a ceiling.** The persona-mode system allows a user to opt into a sassier, more pressuring tone if she wants that kind of accountability, but the app's *default* behavior stays warm rather than guilt-driven. This is a deliberate departure from how a language-learning app can get away with mascot-driven guilt about missed lessons — the same tone applied by default to missed health check-ins risks reading as manipulative rather than motivating, and the product treats that distinction as a real design constraint, not an afterthought.

**No unstated diagnostic claims.** Anywhere the app surfaces something like a PCOS or endometriosis risk flag, it is presented explicitly as a pattern worth discussing with a medical professional — never as a diagnosis, and never phrased in a way that could be mistaken for one.

---

## 10. Technical Architecture

### 10.1 Stack and Rationale

The frontend is built in **Flutter (Dart)**, chosen specifically to ship a single codebase across Android and iOS within hackathon time constraints rather than maintaining two native builds. `mockv4.html` served its purpose as a UI/UX and flow specification — locking in screens, copy, and interaction logic — but is not embedded or shipped in any form; every screen gets rebuilt as native Flutter widgets.

The mascot is the one piece of the UI that cannot simply be "translated" — it has to be genuinely rebuilt using Flutter's `AnimationController` and `CustomPainter` APIs to reproduce the idle physics, drag interaction, emotion-state switching, and peel-stage growth system that exist in the SVG/CSS version of the mock. This is flagged repeatedly throughout this document because it is the single piece of the build most likely to consume unexpected time if nobody on the team has prior experience with custom Flutter animation.

The AI layer uses an LLM API (Claude or Gemini) for conversational check-ins, phase-aware insight generation, and doctor-ready summaries — but it is never called directly from the Flutter client. Doing so would expose the API key in the client bundle; instead, every AI call is routed through a backend proxy that holds the key server-side.

Backend and data infrastructure is built on **Firebase**: Authentication for Google Sign-In, Firestore as the primary data store, and Cloud Functions for every piece of logic that needs to run server-side rather than on-device — most importantly, the Partner Mode consent enforcement described in Section 8. State management uses Provider or Riverpod, a standard, well-understood choice for a Flutter app of this scope. Notifications run through `firebase_messaging` paired with Cloud Scheduler for the nine reminder types collected during onboarding. Doctor summary export uses the same AI proxy to generate the underlying text, which is then rendered into a downloadable PDF client-side using the `pdf` and `printing` Flutter packages — a cheaper approach than generating PDFs server-side given hackathon time constraints.

### 10.2 Data Models (Firestore)

| Collection / Document | Key fields | Notes |
|---|---|---|
| User Profile | authId, name, age, height, weight, country, lifeStage, createdAt | Created on first sign-in |
| Life-Stage Profile | type (cycle / conceive / pregnant / postpartum / menopause), plus stage-specific nested fields | Modeled as a single flexible document rather than five separate collections, to minimize the number of collections that need to be wired up individually |
| Symptom/Mood Log | date, symptoms[], mood, painLevel, notes | Feeds Home, the Log calendar, and doctor summary generation |
| Goals & Preferences | selectedGoals[], dietType, foodAllergies, cuisines[], workoutPreference[] | Captured across the Goals and Common Survey screens |
| Notification Preferences | enabledReminders[] | Nine possible values, drives which scheduled notifications are eligible to fire |
| AI Assistant Scope | enabledHelpAreas[] | Captured on its own onboarding screen |
| Theme | selectedTheme | Light / dark / default |
| Partner Link | partnerUserId, relationshipType, inviteStatus, linkedAt | Created when she invites a partner |
| Partner Permissions | approvedCategories[], onlyApproveMode (bool) | The data model backing the single most important screen in the app |
| Partner View | a filtered projection containing only her approved data | Server-generated only; never written to directly by any client, including hers |
| Chat Messages | senderId (her / partner / system), messageText, timestamp, type | Includes both human messages and Eve's system-generated nudges |
| Streak & Points *(roadmap, not MVP)* | currentStreak, longestStreak, carePoints, unlockedWardrobeItems[], lastFreezeUsed | Backs the gamification layer in Section 7 — not part of the hackathon data model, included here only for future reference |

Two things are deliberately **not** stored as their own documents: the active module set, which is computed at read-time purely from `lifeStage`, and the doctor summary export, which is generated on demand from existing logs rather than persisted as a running record (though caching a generated summary is a reasonable future addition).

### 10.3 Background Logic — What Needs a Server and What Doesn't

Not everything in this system needs backend infrastructure, and it's worth being precise about which parts do, both to scope the build correctly and to be able to answer questions about the architecture confidently.

**Computable entirely on-device, no backend required:** cycle and ovulation prediction (simple arithmetic from stored dates and average cycle length), current pregnancy week (arithmetic from LMP or due date), and the active module set (a lookup from the stored `lifeStage` value). None of this needs a network round-trip.

**Requires a Cloud Function:** initializing a new user's full set of Firestore documents in a single write when their Auth account is first created, so a user is never left in a partially-initialized state; recomputing the `partner_view` document every time she writes to her Symptom Log, Life-Stage Profile, or Permissions — this is the actual technical enforcement of the consent model, not a UI-layer convenience, and it is the single piece of backend logic most worth getting right even under hackathon time pressure; generating Eve's system-level chat nudges when a qualifying symptom or mood entry is logged, which needs to happen server-side rather than being fabricated by the client, both because it touches another user's chat thread and because a client-generated "system message" could otherwise be spoofed; the AI proxy endpoint itself, which holds the LLM API key; and the scheduled dispatch of the nine notification types via Cloud Scheduler and `firebase_messaging`.

---

## 11. Hackathon MVP Scope

**To build:** the complete onboarding flow from Auth through Completion, with Eve present and speaking on every screen without exception; two life-stage branches built to full depth — Tracking my cycle and Pregnant — with the remaining three branches present and selectable but collapsed to a single combined screen each; a Home dashboard that dynamically renders modules based on stored life-stage, showing her current phase/status data (no streak/points/gamification layer — see Section 7, deferred to roadmap); a Chat screen combining ordinary partner messages with Eve's system-generated nudges and quick-reply suggestion chips; a Log screen with a color-coded calendar; a working version of Partner Mode's permission model and at least one functioning nudge-to-chat flow, even if the surrounding UI stays simple; and a doctor summary export that performs one real AI call and formats the result.

**To describe rather than fully build:** the Postpartum, Trying-to-conceive, and Perimenopause branches beyond their simplified combined screen; full end-to-end encryption on the chat thread; and any wearable integration or sleep-correlation analysis. The entire gamification/engagement layer (streaks, points, wardrobe unlockables, daily goal ring) is deferred to post-hackathon roadmap per Section 7, not attempted in any form during the hackathon build.

---

## 12. Success Metrics (For Pitch Framing)

**Check-in completion rate**, comparing the mascot-guided conversational flow against a traditional static form, is the most direct validation of the product's central hypothesis — that a guided, reactive interface reduces the friction that causes most health-tracking apps to be abandoned.

**Streak retention across D1, D7, and D30** is the standard engagement metric borrowed directly from Duolingo's own success measurement. Since the gamification layer itself is deferred to roadmap (Section 7) and not built for the hackathon, cite this as a forward-looking metric the product is designed to eventually support, not something demoed live.

**Partner nudge-to-chat response rate** validates that Partner Mode is a genuinely used feature rather than a checkbox nobody engages with — this is the number that answers "does bringing the partner into the loop actually work," which is likely to be one of the more pointed questions judges ask given how central this feature is to the track.

**Doctor-summary generation quality**, while harder to quantify numerically in a hackathon demo, is worth treating as a qualitative highlight moment — it's the single feature most likely to visibly impress judges in the room, since it takes fragmented daily logs and turns them into something immediately useful in a real medical context.

---

## 13. One-Line Pitch

**EVE turns health tracking into a relationship — a mascot that guides her through every stage of her journey, adapts to who she is, and brings the people who love her into the loop, on her terms.**