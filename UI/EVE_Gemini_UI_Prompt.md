# Prompt for Gemini — EVE Mobile UI Mock (Single HTML File)

Paste everything below into Gemini as one prompt.

---

Build a single, self-contained HTML file (inline CSS + vanilla JS, no external dependencies except Google Fonts) that mocks up the mobile app onboarding flow for a health app called **EVE**. Render it inside a mobile phone frame (375x812px, centered on the page, rounded corners, subtle shadow, like a phone mockup). This is a clickable prototype — use JS to switch between "screens" (divs) with smooth transitions, not real navigation.

## Brand & Visual Style
- **Palette:** Primary pink `#FF6B9D`, soft blush background `#FFF0F5`, white `#FFFFFF`, deep plum text `#3D1F2E` for contrast, accent gold/apple-red `#E63950` used sparingly for highlights.
- **Typography:** Rounded, friendly sans-serif — use Google Font "Quicksand" or "Baloo 2" for headings, "Inter" for body text.
- **Tone:** Warm, playful, premium — think Duolingo's confidence + a soft feminine wellness aesthetic. Not clinical, not childish.
- **Motion:** Soft bounce easing (`cubic-bezier(0.68, -0.55, 0.27, 1.55)`), gentle scale/fade transitions between screens, nothing jarring.

## The Mascot — "Eve"
Design Eve as a small, round, apple-shaped character (nod to the Eden/apple motif) — NOT a literal fruit emoji, but a soft, rounded mascot silhouette drawn in CSS/SVG:
- Rounded apple-like body in gradient pink-to-red
- A small green leaf on top like a little quiff/hair tuft
- Simple friendly face: two dot eyes, blush circles on cheeks, a small curved smile
- Should support at least 3 expression states via CSS class swap: neutral/curious, happy/celebrating (eyes closed, big smile), concerned/soft (slightly tilted, softer smile)
- Draw this as inline SVG so it can be reused and have its expression swapped across all screens

Eve should appear on every screen, anchored bottom-right or center depending on screen, and should visibly react (expression change + small bounce animation) at key moments described below.

## Screen Flow

### Screen 1 — Splash / Intro Animation
- Full pink gradient background
- Eve animates in with a bounce/scale-up entrance (0 → 1 scale with overshoot), like an app icon coming alive
- Below Eve, app wordmark "EVE" fades in, letter by letter or with a soft fade
- Tagline fades in beneath: **"The world, redesigned for her."**
- Auto-transitions (or has a "Get Started" button that fades in after ~1.5s) to Screen 2

### Screen 2 — Welcome / Value Prop (optional single card)
- Eve in curious/neutral pose, small speech-bubble style greeting: *"Hi, I'm Eve. Let's get to know you."*
- One primary button: **"Let's begin"**

### Screen 3 — Onboarding Survey (5 questions, one per screen)
Build this as a 5-step flow with a thin progress bar at the top (fills left to right, pink on blush track). Each question is its own screen with:
- Eve's expression subtly shifts per question (curious pose)
- Question text large and friendly
- Answers as big tappable pill/card buttons (not tiny radio buttons) — full width, rounded 16px corners, selected state = filled pink with white text, unselected = white with pink border
- A "Next" button appears once an option is selected, animates in from bottom

Use these 5 questions (mock data, structured so answers could drive personalization):

1. **"What are you here for?"**
   → Just tracking my cycle / Trying to conceive / I'm pregnant / Recently had a baby
2. **"How would you describe your cycle right now?"**
   → Pretty regular / Irregular / Not sure / I don't track it yet
3. **"What do you want EVE to help with most?"**
   → Understanding my mood & symptoms / Fitness that fits my cycle / Nutrition guidance / Staying on top of appointments
4. **"Do you want a partner or loved one to be able to support you in-app?"**
   → Yes, invite them / Maybe later / No thanks
5. **"How are you feeling about your health journey today?"**
   → Confident / A little overwhelmed / Curious / Just getting started

On question 5, once answered, Eve's expression should shift to "happy/celebrating."

### Screen 4 — "Building your EVE" (personalization loading state)
- Eve in a small idle bounce/thinking animation loop
- Text above: **"Personalizing your EVE..."**
- Below, 3-4 lines of text that appear one at a time (staggered fade-in, ~600ms apart) listing what's being set up based on their answers, e.g.:
  - "Setting up your cycle tracker"
  - "Tailoring your nutrition guidance"
  - "Turning on Partner Mode" *(only show this line if Q4 answer was "Yes, invite them" — use JS to conditionally render based on stored answer)*
- After ~2.5s, auto-transition to Screen 5

### Screen 5 — Personalized Home Screen (the payoff)
- Top: soft greeting — **"Good to have you, [Name placeholder]. Here's your EVE."**
- Eve appears smaller, docked in a corner, happy expression, tappable (implies you can chat with her)
- Below: a grid/list of module cards that visibly reflects the survey answers — dynamically render only the relevant modules based on stored answers from Screen 3 (use JS conditionals, not hardcoded), for example:
  - If "Just tracking" or "Trying to conceive" → show Cycle Tracker, Ovulation Prediction, Mood & Symptom Log cards
  - If "I'm pregnant" → show Pregnancy Milestones, Appointment Reminders instead of cycle/ovulation cards
  - Always show Mood Tracking and Nutrition cards, but with copy that reflects their stated goal from Q3
  - If Partner Mode was accepted in Q4 → show an additional "Invite your partner" card
- Each module card: white background, soft shadow, pink accent icon (simple inline SVG icons — leaf, heart, calendar, dumbbell, moon), rounded corners
- This screen should make it visually obvious that the app reconfigured itself based on the 5 answers — this is the core "wow" moment, so make the personalization feel earned and specific, not generic

## Technical Requirements
- Single HTML file, all CSS in a `<style>` block, all JS in a `<script>` block at the bottom
- Store survey answers in a simple JS object/state as the user progresses
- Use CSS keyframes for all animations — no external animation libraries
- Make all buttons functional (clicking actually navigates/stores state) so this feels like a real clickable prototype, not a static image
- Comment the JS clearly so sections (survey logic, personalization logic, screen transitions) are easy to find and edit later
- Keep everything mobile-frame-contained; the rest of the page background can be a neutral color so the phone frame is the clear focal point

## Deliverable
Output the complete HTML file, ready to save and open directly in a browser.
