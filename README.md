# Trackside

An online riding journal for horse riders. Log lessons and the horses you ride, record dressage and jumping scores, reflect on each ride and carry focus points into the next one. A built-in equestrian library covers breeds, coat colours, terminology, tack and horse care.

## Features

- **Journal**: full ride entries or a 30-second quick log, with session type, horses, disciplines, exercises, ride and confidence ratings.
- **Reflection loop**: what went well, what was hard, what the instructor said, and 1–3 focus points that appear on the home screen before the next ride.
- **Scores**: dressage tests (percentage, placing, optional movement marks) and jumping rounds (height, faults, time, fault causes).
- **Horses**: profiles, rider notes, ride history and a care log with due dates.
- **Progress**: dressage and jumping charts, ride and confidence trend, goals, and flatwork and jumping skills checklists.
- **Library**: breeds, colours and markings, terminology, tack and equipment, horse care and riding tips.
- **Detailed feedback**: fault patterns, weakest dressage movements and tips matched to your reflections.

Everything is free for now; Premium is paused.

## Running it

Trackside is a single self-contained page: open `index.html` in a browser. Fonts load from Google Fonts.

When it runs as a Claude artifact, each rider's journal is saved privately and syncs across devices. Opened anywhere else, it saves to the browser's local storage on that device.

## Brand

- Palette: Light Yellow `#F6F4D2`, Vanilla Custard `#D4E09B`, Tea Green `#CBDFBD`, Golden Chestnut `#C08552`, Espresso `#5E3023`
- Type: Patrick Hand (headings, notes) and DM Sans (reading, numbers)
- Logo: the double horseshoe in `assets/trackside-shoes.png`, shown on a stitched patch

## Files

- `index.html`: the app
- `assets/trackside-shoes.png`: logo artwork (transparent PNG, also embedded in the app)
- `assets/horse-icon.png`: leaping horse silhouette used for the Horses tab icon

## Database (Supabase)

Project `wkbnevtbbuqngdvfobol` · URL `https://wkbnevtbbuqngdvfobol.supabase.co` · publishable key `sb_publishable_ykD-gBJEBroHsugiKIEqVA_lQl3dRm5` (safe to use in the browser; row level security protects the data).

The schema lives in `supabase/migrations/` and is already applied to the project.

| Table | What it holds |
| --- | --- |
| `profiles` | One row per rider, created automatically on sign-up: display name, jump units, Premium status |
| `horses`, `horse_care_events` | Horse profiles and the farrier/vaccination/worming/dentist care log |
| `entries`, `entry_horses` | Journal entries and which horses were ridden in each |
| `focus_points` | "Focus for next time" points and their status (open, worked on, improved, still a problem) |
| `dressage_results`, `dressage_marks` | Dressage tests and optional per-movement marks |
| `jumping_results` | Jumping rounds: height, faults, time, fault causes; `is_clear` is worked out automatically |
| `goals`, `skill_progress` | Goals with target dates and the flatwork/jumping skills checklist |
| `library_articles`, `bookmarks` | The 83 encyclopedia articles and each rider's saved articles |

**Login:** Supabase Auth (email and password or magic link). Turn on other providers, such as Google or Apple, in the dashboard under Authentication → Providers.

**Privacy:** every table has row level security. A rider can only read and change their own rows, and signed-out visitors can't read anything.

**Premium (paused):** everything is free right now and every library article is readable by all signed-in riders. The groundwork for paid Premium is kept for later: `profiles.is_premium`, `premium_until` and the Stripe fields (riders can't change them), `is_premium()`, and three Stripe edge functions in `supabase/functions/` (`create-checkout`, `customer-portal`, `stripe-webhook`). They're deployed but do nothing until `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` are set.
