# Accountable

<img src="Accountable/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="96" alt="Accountable icon" align="right">

An iOS app that helps you spend less time on social media by holding you to the time you choose.

Most screen time apps set a daily cap and let you ignore it. Accountable asks one question every time: **"How long do you want?"** Your apps stay locked until you answer. Then they unlock for exactly that long and lock again when the time's up. Run out of time and you take a short break before the next session.

> **Status:** v1 code complete. Runs in the Simulator in demo mode; not yet tested on a device. See [Roadmap](#roadmap).

## How it works

1. **A short intro.** Three research findings, then your own numbers: how many of your remaining years social media is on track to take, with a slider to see how many you'd win back by cutting down.
2. **Pick your apps.** Grant Screen Time access and choose the apps that pull you in, using Apple's picker.
3. **Locked by default.** Selected apps stay shielded until you start a session.
4. **Say how long.** 5, 10, 15, 30 minutes, or your own number. Only time in those apps counts.
5. **Keep your word.** When the time's used up, the apps lock again. By default each break that day is longer than the last (3, 10, 30, 60 minutes), resetting at midnight. You can change this in Settings.
6. **See how you're doing.** Today's promises kept, your streak, and the week at a glance.
7. **Meet Buddy.** A small robot whose mood follows your promises. Keep them and Buddy grows, brightens and hops around. Break them and Buddy shrinks, fades and droops. Only kept promises (of at least a minute) bring Buddy back.

## The research behind it

- **Less scrolling, less lonely.** Students who limited social media to about 30 minutes a day felt significantly less lonely and depressed within three weeks. *Hunt et al., Journal of Social and Clinical Psychology, 2018.*
- **An hour back, every day.** People paid to deactivate Facebook for four weeks freed up about 60 minutes a day and reported small but significant gains in well-being. *Allcott et al., American Economic Review, 2020.*
- **Deciding ahead works.** Across 94 studies, deciding exactly when and how you'll act made people much more likely to follow through. *Gollwitzer & Sheeran, Advances in Experimental Social Psychology, 2006.*

## Privacy

- **Everything stays on your phone.** No backend, no accounts, no analytics.
- **We can't see your apps.** Screen Time gives Accountable anonymous tokens, not app names, and nothing about what you do inside them.

## Research study mode

Accountable is also used in a separate 4-week University of Florida study comparing flat and escalating breaks. That study is run independently of the app. Regular users never see it, and nothing is logged for them.

A researcher enables study mode on a participant's phone from a hidden screen, entering a participant ID and group. The participant then sees a consent screen, and only after they agree does the app keep a local event log. The log has sessions, limits and breaks, never app names or content. It leaves the phone only if the participant exports it as a CSV.

## Architecture

One app, three extensions, and a small shared data layer. No third-party dependencies.

| Target | Role |
|---|---|
| `Accountable` | Main SwiftUI app: intro, app picker, "How long?" flow, home screen, settings, study mode |
| `AccountableMonitor` | `DeviceActivityMonitor` extension: re-locks apps when a session's time is used up |
| `AccountableShield` | `ShieldConfiguration` extension: custom lock screen showing when the app becomes available |
| `AccountableShieldAction` | `ShieldAction` extension: handles taps on the lock screen buttons |

State is shared between the app and extensions through an App Group (`group.com.wille1773.accountable`).

**Frameworks:** [FamilyControls](https://developer.apple.com/documentation/familycontrols) (individual authorization), [ManagedSettings](https://developer.apple.com/documentation/managedsettings) (shields), [DeviceActivity](https://developer.apple.com/documentation/deviceactivity) (usage tracking).

### Platform notes

- Device activity schedules must be at least 15 minutes long. Session limits use usage thresholds within a longer schedule, and cooldowns are enforced in the app, so short sessions and cooldowns still work.
- Opening Accountable directly from the lock screen requires iOS 26.5 or later. Earlier versions fall back to a notification that opens the app.
- Screen Time APIs do not work in the iOS Simulator. There the app runs a **demo mode**: no real locking, and a fast clock (1 minute = 2 seconds) so you can watch sessions and breaks play out. Real testing requires a physical device.

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

A paid Apple Developer Program team is required: free Personal Teams can't use Family Controls on a device. See [docs/TESTING.md](docs/TESTING.md) for a step-by-step test checklist.

## Roadmap

All milestones are written and build cleanly. None has been tested on a device yet; see [docs/TESTING.md](docs/TESTING.md).

- [x] 1. Project setup, App Group, extension targets, Screen Time authorization, app picker
- [x] 2. Default shielding of selected apps and custom shield screen
- [x] 3. "How long?" flow: unlock, track usage, re-lock at the limit
- [x] 4. Cooldowns with flat and escalating modes
- [x] 5. Home screen stats and streak
- [x] 6. Study mode: consent, participant ID, group assignment, event logging, CSV export
- [x] 7. Edge cases: restart mid-session, midnight rollover, revoked permission, changed app selection
- [ ] On-device testing

## Author

William Evans, University of Florida
