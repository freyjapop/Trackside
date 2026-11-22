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

Trackside is a single self-contained page, `index.html`. How it saves depends on where it runs:

- **Web app (GitHub Pages, `localhost`)**: riders sign up and sign in with email (password or a magic link) and their journal is saved to Supabase, so it syncs across devices. Add `?backend=supabase` to the URL to use this anywhere else.
- **Claude artifact**: no sign-in; each viewer's journal is saved privately in Claude.
- **Anywhere else** (or with `?backend=local`): saved in the browser on that device.

### Publishing the web app

1. On GitHub: **Settings → Pages → Build and deployment**, choose **Deploy from a branch**, branch `main`, folder `/ (root)`, then Save. The app appears at `https://freyjapop.github.io/Trackside/`.
2. In Supabase: **Authentication → URL Configuration**, set **Site URL** to `https://freyjapop.github.io/Trackside/` and add the same address under **Redirect URLs**. Sign-up confirmation, magic-link and password-reset emails send riders back there.
3. Optional, before launch: Supabase's built-in email sender only allows a few emails an hour. Add your own email service under **Authentication → Emails → SMTP settings**.

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
