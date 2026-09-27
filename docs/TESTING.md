# Testing on a device

Screen Time APIs don't work in the Simulator. Everything here is on a physical iPhone, signed with a **paid** Apple Developer team (free Personal Teams can't use Family Controls).

## One-time setup

1. Open `Accountable.xcodeproj`.
2. For each of the four targets (Accountable, AccountableMonitor, AccountableShield, AccountableShieldAction): **Signing & Capabilities** → check **Automatically manage signing** → choose your **Team**. Family Controls and the App Group are already in the project; Xcode registers them with Apple when you pick the team.
3. Plug in your iPhone, tap **Trust**, turn on **Settings → Privacy & Security → Developer Mode**, and restart the phone.
4. Pick your iPhone at the top of Xcode and press **Run** (▶).

Tip: to see what the extensions are doing, open **Console.app** on your Mac, select your iPhone, and filter by `AccountableMonitor`.

## Milestone checks

### 1. Intro, authorization, app picker
- [ ] First launch shows the intro: welcome, three research cards, your numbers, your life in years, how it works.
- [ ] Moving the slider and age updates the life projection.
- [ ] **Turn on Screen Time access** shows Apple's prompt and Face ID.
- [ ] Choose 2–3 apps (e.g. TikTok, Instagram). The card lists them. Tap **Continue**.
- [ ] Force-quit and reopen: you land on the home screen with the same apps.

### 2. Default shielding and shield screen
- [ ] Open a selected app from the home screen: the Accountable lock screen appears ("This one's locked").
- [ ] **Open Accountable**: on iOS 26.5+ it opens Accountable; on older iOS you get a notification that opens it.
- [ ] **Close** returns to the home screen.
- [ ] Apps you didn't select still open normally.

### 3. "How long?" sessions
- [ ] **How long do you want?** → **5**. The selected apps open normally.
- [ ] Use one for about 4 minutes: you get "About a minute left".
- [ ] At about 5 minutes of use you get "Time's up" and the lock screen returns. **Write down how late it fires** (Apple doesn't promise exact timing).
- [ ] Start another session and tap **I'm done** after a minute: apps lock right away.
- [ ] Time only counts while a selected app is on screen: start 5 min, use 2, leave for 5, come back; you should still have about 3.

### 4. Cooldowns
- [ ] After a session runs out, the home screen shows a live countdown and "You can start again at …". The lock screen says the same time.
- [ ] Settings → Breaks → set steps to 1, 2, 3 min to test quickly. Hit the limit three times in a row: breaks are 1, 2, then 3 min.
- [ ] Switch to **Same break every time**: every break is the same length.

### 5. Home stats and streak
- [ ] End one session early and let one run out: Today shows "1 of 2 promises kept".
- [ ] Streak shows 0 after a limit hit today; on a clean day it counts up from setup day.

### 6. Study mode
- [ ] Before enrolling, Settings has no Study section, and nothing is logged.
- [ ] Settings → press and hold the version number (under the little robot) for 2 seconds → enter the researcher passcode.
- [ ] Set a participant ID and group, then **Save**. Settings closes and the consent screen appears.
- [ ] **No thanks** removes the enrollment. **I agree** starts logging, and the Breaks section now says it's set by the study.
- [ ] **Export my data (CSV)** opens the share sheet. AirDrop it to your Mac and check the rows match what you did.
- [ ] Check whether `shield_shown` rows appear. If none do, iOS isn't letting the lock screen extension write, and only `shield_button_tapped` rows will show opens of locked apps.

### 7. Edge cases
- [ ] **Restart mid-session:** start 15 min, restart the phone, and open a selected app. It should still be unlocked, and still lock at the limit.
- [ ] **Midnight:** start a 30 min session at 11:50 PM. It should keep running past midnight, and the next day's break counts start fresh.
- [ ] **Revoke access:** Settings → Screen Time → turn off access for Accountable (or delete it from the Screen Time apps list). Reopen Accountable: it shows "Screen Time access is off". Turning it back on returns you home.
- [ ] **Change apps:** add or remove an app in Settings. The new set is locked, and the log shows `selection_changed` with counts.

## Known limits

- The lock screen can't show a live countdown. It shows the clock time instead.
- "Minutes left" updates in steps as iOS reports usage, so it can lag by a minute or so.
- Developers report a cap of about 50 individually picked apps per shield (not confirmed in Apple's docs). Picking categories covers more.
- Changing the phone's clock can shorten a break. Apple offers a setting to force automatic time, but it wasn't turned on because it changes a device setting for the participant.
