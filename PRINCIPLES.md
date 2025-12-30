# Ephemera — Design & Development Principles

## Vision

Ephemera is an AI-powered evolutionary astrology companion for iOS. It delivers personalized, meaningful astrological guidance through a clean, elegant interface—meeting users where they are with timely wisdom rooted in their unique birth chart and life context.

---

## Core Concepts

### Evolutionary Astrology Foundation
- Focus on the **soul's journey** and karmic evolution, not just personality traits
- Emphasize growth, potential, and lessons rather than fixed predictions
- Honor the North Node/South Node axis as central to understanding life purpose
- Treat challenging transits as opportunities for transformation

### Personalization Philosophy
- Astrology without context is noise; context transforms it into guidance
- The user's **birth data** (date, time, location) is the foundation
- Their **life story** (challenges, dreams, background) is the lens
- Readings should feel like they were written *for this person*, not generated generically

---

## User Profile — The Foundation

### Essential Birth Data
- Date of birth
- Time of birth (with "unknown" option + rectification guidance)
- Location of birth (city-level precision)

### Life Context Questions
These deepen personalization and should be gathered conversationally:

1. **Current challenges** — What are you struggling with right now?
2. **Dreams & aspirations** — What are you moving toward?
3. **Background & upbringing** — Key influences that shaped you
4. **Relationship status** — For tailoring love/partnership readings
5. **Career/purpose** — Current work and sense of calling
6. **Spiritual orientation** — Openness to different frameworks
7. **Previous astrology exposure** — Beginner vs. experienced

Input methods:
- Text entry (primary)
- Voice dictation (future enhancement)

---

## Reading Types

### 1. Daily Readings
- Brief, actionable guidance for the day
- Based on current transits to natal chart
- Delivered as morning push notification
- Tone: warm, grounded, practical

### 2. Weekly Readings
- Broader themes and energies for the week ahead
- Highlights key days or transits to watch
- Delivered Sunday evening or Monday morning
- Tone: reflective, forward-looking

### 3. Key Astrological Timing
Triggered by significant transits:
- **Saturn Return** (~ages 29, 58)
- **Mercury Retrograde** periods
- **Eclipses** affecting natal planets
- **Jupiter transits** to key points
- **Pluto/Neptune/Uranus** transits (generational but personally timed)
- **Lunar phases** in relation to natal chart
- **Solar Return** (birthday chart)

These should feel momentous—not spammy.

### 4. On-Demand Readings
- User-initiated queries
- Can be general ("What should I know right now?")
- Or specific ("How will this week affect my career?")
- Consider credits/limits to maintain value

---

## Social Features

### Friend Connections
- Add friends via invite code, phone contacts, or username
- Both users must consent to compatibility reading

### Compatibility Readings
- Synastry analysis (chart overlay)
- Composite chart insights (the relationship itself)
- Focus on growth opportunities, not just "are we compatible?"
- Evolutionary lens: What is this relationship teaching each soul?

---

## Design Principles

### Aesthetic
- **Clean & minimal** — let the content breathe
- **Celestial without cliché** — avoid overused zodiac imagery
- **Dark mode primary** — evokes night sky, reduces eye strain
- **Subtle animation** — stars, gentle transitions, nothing flashy
- **Typography-forward** — elegant serif for readings, clean sans for UI

### Tone of Voice
- Warm but not saccharine
- Wise but not preachy
- Grounded but open to mystery
- Personal but respecting boundaries
- Never fear-mongering about "bad" transits

### UX Priorities
1. **Onboarding should feel like a conversation**, not a form
2. **Readings should be effortless to access** — minimal taps
3. **Notifications should feel like a gift**, not an interruption
4. **Profile updates should be frictionless** — life changes, so should context

---

## Technical Considerations

### Data & Privacy
- Birth data and personal context are sensitive
- Clear privacy policy on data usage
- Option to delete all data
- No selling of personal information

### AI Integration
- LLM generates readings based on:
  - Calculated chart positions
  - Current transits
  - User's profile context
- Prompt engineering should embed evolutionary astrology principles
- Responses should be consistent in voice and philosophy

### Notifications
- APNs for push delivery
- User controls frequency per reading type
- Smart timing (don't wake people up)
- Rich notifications where appropriate

### Ephemeris & Calculations
- Accurate planetary position calculations required
- Consider Swiss Ephemeris or similar
- Handle timezone/DST correctly for birth time

---

## Future Considerations

- Voice input for profile questions
- Audio readings (text-to-speech or pre-recorded)
- Journal feature to track life events against transits
- Year-ahead forecasts
- Transit calendar visualization
- Apple Watch complications
- Widgets for daily guidance

---

## Naming Note

**Ephemera** — things that exist or are enjoyed for only a short time. A nod to:
- The fleeting nature of each day's cosmic weather
- The transient moments astrology illuminates
- The ephemeris itself (tables of planetary positions)

---

*Remember: We're not predicting fate. We're illuminating the soul's journey.*

