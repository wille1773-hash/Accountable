# Accountable

<img src="Accountable/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="96" alt="Accountable icon" align="right">

**A fun, interactive way to take your time back from social media.**

I watched social media take over my life and my friends' lives. "Five minutes" turned into hours, and screen time limits were too easy to ignore. I wanted something that holds me to my word without lecturing me, so I built Accountable.

## How it works

- **Say how long.** Your chosen apps stay locked until you open Accountable and pick a time: 5, 10, 15, 30 minutes, or your own.
- **Keep your word.** The apps unlock for exactly that long, then lock again. Run out of time and you take a short break, which gets longer each time you run out that day.
- **Meet Buddy.** A little green robot whose mood follows your promises. Keep them and he thrives; break them and he shrinks and droops. Only kept promises cheer him back up.
- **See your progress.** Promises kept in a row, your recent promises, minutes per day, and how many years of your life you're winning back.
- **Unwind.** Guided breathing, grounding, and ideas for something better to do when you feel the pull.
- **Widgets.** Buddy hops around your Home Screen and shows how you're doing.

![Buddy widgets](design/widgets.png)

## Why it works

- Limiting social media to ~30 min/day reduced loneliness and depression in 3 weeks. *(Hunt et al., 2018)*
- A 4-week Facebook break freed up ~60 min/day and improved well-being. *(Allcott et al., 2020)*
- Deciding in advance how you'll act strongly improves follow-through. *(Gollwitzer & Sheeran, 2006)*

## Privacy

Everything stays on your phone. No accounts, servers, or analytics. Apple's Screen Time never shares app names or what you do inside them.

A hidden study mode, used for a separate University of Florida study, keeps a local log only for participants who give consent.

## Running it

Open `Accountable.xcodeproj` in Xcode 26.3+ and press Run on a Simulator to try the demo. Locking apps needs a real iPhone (iOS 17+) and a paid Apple Developer account. See [docs/TESTING.md](docs/TESTING.md).

Built with Swift and SwiftUI using FamilyControls, ManagedSettings, DeviceActivity and WidgetKit. No third-party packages.

## Author

William Evans, University of Florida
