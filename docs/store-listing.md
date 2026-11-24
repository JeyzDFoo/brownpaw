# Store listing drafts

Copy these into App Store Connect and the Play Console. Everything here
matches what the app does as of November 2026: Firebase Auth, Firestore,
Storage (profile photo), Cloud Messaging (flow alerts), and location read on
the phone only when you tap to check in or look for nearby runs. If any of
that changes, update this file, `web/privacy.html` and both stores' privacy
answers together.

## Shared

- **Name:** Brownpaw
- **Privacy policy:** https://brownclaw.web.app/privacy.html
- **Account deletion (Play asks for a link):** https://brownclaw.web.app/privacy.html#delete
- **Support URL:** https://brownclaw.web.app/support
- **Support / contact email:** support@brownpaw.app, privacy@brownpaw.app (check both reach you)
- **Category:** Sports (Apple secondary: Weather)
- **Price:** Free, no in-app purchases, no ads
- **Countries:** Canada to start (add the US when the guide reaches it)

## App Store

**Subtitle** (30 max): `Whitewater logbook and gauges`

**Promotional text** (170 max):
Log every run in seconds, with the flow filled in for you. Live gauges for the Lower Mainland and BC, and a guide to the runs.

**Keywords** (100 max, no spaces after commas):
`kayak,whitewater,river,logbook,gauge,flow,paddling,creek,rafting,canoe,water level,BC,hydrometric`

**Description:**

Brownpaw is a logbook for whitewater paddlers.

LOG A RUN IN SECONDS
Check in at the put-in and Brownpaw suggests the run you're on. Tap once and the date and river flow are filled in for you from the nearest gauge. Add notes, a rating and who you paddled with if you like.

YOUR SEASON AT A GLANCE
See every run you've done, how often, and at what levels. Each logged run gets its own page with the flow that day.

LIVE GAUGES
Star the gauges you care about and see current levels and history at a glance, with charts from a day to a year. Set a flow alert and get a notification when your run comes in.

A GUIDE TO THE RUNS
Browse runs on a map or in a list, with difficulty, put-ins and take-outs, and the gauge that matters.

WORKS ON THE RIVER
Your logbook and starred gauges are saved on your phone, so they open without signal.

PRIVATE BY DEFAULT
Your logbook is yours. No ads, no tracking, and your location never leaves your phone.

Starting with BC's Lower Mainland. River levels come from the Water Survey of Canada.

Whitewater is dangerous. Gauge data can be late or wrong; always scout and make your own call.

**What to Test** (TestFlight):
Log a run from the Log tab and from a put-in check-in. Star a few gauges and set a flow alert. Try it with no signal. Tell us anything that feels slow or confusing.

### App Privacy (App Store Connect > App Privacy)

Tracking: **No**, the app does not track.

| Data type | Collected | Linked to user | Purpose |
|---|---|---|---|
| Contact Info > Email Address | Yes | Yes | App Functionality |
| Contact Info > Name | Yes | Yes | App Functionality |
| User Content > Photos or Videos | Yes (optional profile photo) | Yes | App Functionality |
| User Content > Other User Content | Yes (logbook entries, runs you add) | Yes | App Functionality |
| Identifiers > User ID | Yes | Yes | App Functionality |
| Identifiers > Device ID | Yes (push token for alerts) | Yes | App Functionality |
| Location | **No** (read on device only, never sent) | | |
| Usage Data, Diagnostics, everything else | No | | |

### Age rating

Answer "None" to every content question; no user-to-user communication, no
web browsing, no gambling. Result: 4+.

### App Review notes

Brownpaw is a private logbook and river-level app for whitewater kayakers.
Sign in with Apple, Google or email. Demo account: (email) / (password).
Location is optional and only used while the app is open to suggest which
run you are at (the check-in card on the Logbook tab). Notifications are optional flow alerts
(the bell on a gauge or run page). Account deletion: Me > Delete account.

## Google Play

**Short description** (80 max):
`Whitewater logbook with live river gauges. Log a run in seconds.`

**Full description:** same as the App Store description above.

### Data safety (Play Console > App content > Data safety)

- Does your app collect or share any of the required user data types? **Yes**
- Is all data encrypted in transit? **Yes**
- Do you provide a way for users to request that their data is deleted? **Yes** (in app, and the link above)
- Shared with third parties: **None** (Firebase is a service provider, not sharing)

| Category > type | Collected | Optional? | Purpose |
|---|---|---|---|
| Personal info > Name | Yes | Required | App functionality, Account management |
| Personal info > Email address | Yes | Required | App functionality, Account management |
| Personal info > User IDs | Yes | Required | App functionality, Account management |
| Photos and videos > Photos | Yes | Optional | App functionality |
| App activity > Other user-generated content | Yes (logbook) | Optional | App functionality |
| Device or other IDs | Yes (push token) | Optional | App functionality |
| Location | **No** (processed on device only) | | |

Processed ephemerally: No. Data collection is not used for analytics,
advertising or personalisation.

### Other App content answers

- **Ads:** No ads.
- **App access:** Some functionality is restricted; give the demo account.
- **Content rating (IARC):** Utility/productivity style app; no violence,
  sexuality, language, controlled substances, gambling; users can't
  interact or share content. Expect "Everyone" / PEGI 3.
- **Target audience:** 13 and over.
- **News app:** No. **Government app:** No. **Health:** No.
- **Financial features:** None.

## Screenshots

App Store needs 6.9" iPhone shots (1320 x 2868) and, since the app runs on
iPad, 13" iPad shots. Play needs at least 2 phone shots and a 1024 x 500
feature graphic. Suggested set, light theme: Logbook home, a logged run,
Gauges list, a gauge chart, Guide map, quick log.
