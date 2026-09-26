# Accountable

An iOS app that holds you to the social media time limits you set for yourself.

Instead of a fixed daily cap, Accountable asks one question each time you want to use a distracting app: **"How long do you want?"** It unlocks your chosen apps for exactly that long, then locks them again. If you keep coming back after hitting your limit, you wait longer before you can start another session.

> **Status:** In active development. Features below describe the planned v1; see [Roadmap](#roadmap) for progress.

## How it works

1. **Choose your apps.** On first launch, grant Screen Time access and pick the apps to control (TikTok, Instagram, etc.) using Apple's app picker.
2. **Locked by default.** Selected apps stay shielded until you start a session.
3. **Make a promise.** Open Accountable and choose how long you want: 5, 10, 15, 30 minutes, or a custom amount.
4. **Keep your word.** The apps unlock. When your time is used up, they lock again automatically.
5. **Cooldowns.** After you reach a limit, there is a cooldown before you can start a new session. In escalating mode, each repeat that day makes the cooldown longer (default steps: 3, 10, 30, 60 minutes). Cooldowns reset at midnight.
6. **Track your day.** The home screen shows promises made vs. kept, current lockout status, and your streak of days with every limit kept.

## Research study

Accountable is being used in a 4-week study with University of Florida students comparing two conditions:

| Group | Cooldown behavior |
|---|---|
| **Flat** | Every cooldown is the same length. |
| **Escalating** | Cooldowns grow with each repeat in a day. |

Study features include an informed-consent screen shown before anything else, a researcher-only settings screen for participant ID and group assignment, local event logging, and CSV export via the iOS share sheet.

### Privacy

- **Nothing leaves the phone** unless the participant exports their log and chooses to share it.
- **No backend, no accounts, no analytics.**
- **Only app-level events are logged.** Accountable never records what content you view. Apple's Screen Time APIs expose selected apps only as opaque tokens, so the log does not contain app names.

Logged events (with timestamps): session requested (minutes), session started, limit reached, lockout started (length), lockout ended, and interaction with a locked app.

## Architecture

One app, three extensions, and a small shared data layer. No third-party dependencies.

| Target | Role |
|---|---|
| `Accountable` | Main SwiftUI app: onboarding, app picker, "How long?" flow, home screen, study settings |
| `AccountableMonitor` | `DeviceActivityMonitor` extension: re-locks apps when a session's time is used up |
| `AccountableShield` | `ShieldConfiguration` extension: custom lock screen showing when the app becomes available |
| `AccountableShieldAction` | `ShieldAction` extension: handles taps on the lock screen buttons |

State is shared between the app and extensions through an App Group (`group.com.wille1773.accountable`).

**Frameworks:** [FamilyControls](https://developer.apple.com/documentation/familycontrols) (individual authorization), [ManagedSettings](https://developer.apple.com/documentation/managedsettings) (shields), [DeviceActivity](https://developer.apple.com/documentation/deviceactivity) (usage tracking).

### Platform notes

- Device activity schedules must be at least 15 minutes long. Session limits use usage thresholds within a longer schedule, and cooldowns are enforced in the app, so short sessions and cooldowns still work.
- Opening Accountable directly from the lock screen requires iOS 26.5 or later. Earlier versions fall back to a notification that opens the app.
- Screen Time APIs do not work in the iOS Simulator. Testing requires a physical device.

## Requirements

- iOS 17.0 or later
- Xcode 26.3 or later
- A physical iPhone
- An Apple Developer account with the Family Controls capability. Distribution through TestFlight or the App Store requires Apple's approval of the Family Controls distribution entitlement.

## Getting started

1. Clone the repository:
   ```bash
   git clone https://github.com/wille1773-hash/Accountable.git
   ```
2. Open `Accountable.xcodeproj` in Xcode.
3. For each of the four targets, open **Signing & Capabilities**, select your development team, and confirm that **Family Controls** and the App Group are enabled.
4. Connect your iPhone, enable Developer Mode (Settings → Privacy & Security → Developer Mode), and run the `Accountable` scheme.

## Roadmap

- [ ] 1. Project setup, App Group, extension targets, Screen Time authorization, app picker
- [ ] 2. Default shielding of selected apps and custom shield screen
- [ ] 3. "How long?" flow: unlock, track usage, re-lock at the limit
- [ ] 4. Cooldowns with flat and escalating modes
- [ ] 5. Home screen stats and streak
- [ ] 6. Study mode: consent, participant ID, group assignment, event logging, CSV export
- [ ] 7. Edge cases: restart mid-session, midnight rollover, revoked permission, changed app selection

## Author

William Evans, University of Florida
