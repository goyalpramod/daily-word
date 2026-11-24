# Publishing Daily Word to the App Store

One App Store record covers iPhone, iPad and Mac (same bundle ID, so it's a "universal purchase").
Everything to paste is in [`metadata.md`](metadata.md); images and videos are in `Screenshots/` and `Previews/`.
Regenerate them any time with `scripts/render_store_assets.sh`.

## Where everything goes

All paths start at [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps** → **Daily Word: Words & Origins** → **Distribution** tab.
"Version page" means the left sidebar's **iOS App → 1.0 Prepare for Submission** (do it again for **macOS App → 1.0**).

| What | Where in App Store Connect (click path) | Copy from |
|---|---|---|
| Name | Sidebar **General → App Information** → Localizable Information → *Name* | metadata.md → Name |
| Subtitle | Sidebar **General → App Information** → Localizable Information → *Subtitle* | metadata.md → Subtitle |
| Category | Sidebar **General → App Information** → *Category* (Primary / Secondary) | metadata.md → Category |
| Content rights | Sidebar **General → App Information** → *Content Rights* → Edit | Step 4 below |
| Age rating | Sidebar **General → App Information** → *Age Rating* → Edit | Answer None/No to all (4+) |
| Header image | Version page → **Product Page Information** → **Header and Search Results** tab → **Header** → Upload | `Creative/header-3840x1646.png` |
| Search results image | Version page → **Product Page Information** → **Header and Search Results** tab → **Search Results** → Upload | `Creative/search-3840x2560.png` |
| Screenshots and previews | Version page → **Product Page Information** → **App Previews and Screenshots** tab → each device slot | `Screenshots/…`, `Previews/…` (table in step 4) |
| Promotional text | Version page → scroll below the screenshots → *Promotional Text* | metadata.md → Promotional text |
| Description | Version page → below the screenshots → *Description* | metadata.md → Description |
| Keywords | Version page → below the screenshots → *Keywords* | metadata.md → Keywords |
| Support URL | Version page → *Support URL* | metadata.md → Support URL |
| Marketing URL | Version page → *Marketing URL* | metadata.md → Marketing URL |
| Copyright | Version page → *Copyright* | `2026 Pramod Goyal` |
| Build | Version page → **Build** section → **+** | The 1.0 (1) you uploaded |
| App Review notes | Version page → bottom → **App Review Information** → *Notes* (untick *Sign-in required*) | metadata.md → Notes for App Review |
| Privacy policy URL + data answer | Sidebar **App Store → Trust & Safety → App Privacy** | URL in metadata.md; answer "No, we do not collect data" |
| Price and countries | Sidebar → **Pricing and Availability** (scroll down the sidebar) | Free; untick China mainland |
| EU trader status | Top menu **Business** → Trader Status | "Not a trader" |
| iCloud schema | [icloud.developer.apple.com](https://icloud.developer.apple.com) → CloudKit Database → container → **Deploy Schema Changes** | Step 1 below |

Promotional text, description, keywords, URLs and copyright are per platform: paste them on **both** the iOS and macOS version pages.
Name, subtitle, category, age rating, privacy and price are app-wide: set them once.

## 0. Before you start (once)

- [ ] The repo is public and GitHub Pages is on (Settings → Pages → Branch `main`, folder `/docs`), so these URLs work:
  `https://goyalpramod.github.io/daily-word/` (support) and `…/privacy` (privacy policy).
- [ ] You've run the app at least once on a device with iCloud signed in (this creates the iCloud database schema).

## 1. Push the iCloud schema to production

Release builds use the *production* iCloud database, which starts empty.

1. Open [icloud.developer.apple.com](https://icloud.developer.apple.com) → **CloudKit Database**.
2. Pick the container `iCloud.io.github.goyalpramod.dailyword`.
3. Click **Deploy Schema Changes…** (bottom left) → **Deploy**.

## 2. Create the app in App Store Connect

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App**.
2. Platforms: tick **iOS** and **macOS**.
3. Name: `Daily Word: Words & Origins` (if taken, see alternatives in metadata.md).
4. Primary language: English (U.S.). Bundle ID: `io.github.goyalpramod.dailyword`. SKU: `dailyword`.
5. User access: Full access → **Create**.

## 3. Upload the builds (in Xcode)

iPhone/iPad:
1. Top bar destination → **Any iOS Device (arm64)**.
2. **Product → Archive**. When the Organizer opens: **Distribute App → App Store Connect → Distribute**.

Mac:
1. Destination → **Any Mac**.
2. **Product → Archive → Distribute App → App Store Connect → Distribute**.

Builds show up in App Store Connect under **TestFlight** after 10–30 minutes. (Before each new upload, bump the build number in `project.yml`, `CURRENT_PROJECT_VERSION`, then run `xcodegen generate`.)

> Want friends to try it before review finishes? TestFlight → **External Testing** → add a group → **Enable public link**. Share the link.

## 4. Fill in the listing

In the app's **iOS App → 1.0 Prepare for Submission** page, under **Product Page Information**:

- **Header and Search Results** tab (optional, shown on iOS/iPadOS 27+):
  - **Header** → **Upload** → `Creative/header-3840x1646.png` (21:9, 3840 × 1646).
  - **Search Results** → **Upload** → `Creative/search-3840x2560.png` (3:2, 3840 × 2560).
  - Click **Preview** to check light/dark mode and the crops on each device. The headline and the main widgets sit
    inside Apple's safe areas, so they stay visible at every crop. Don't drop screenshots here; they're the wrong size.
- **App Previews and Screenshots** tab (checked against Apple's spec, Nov 2026):

  | Slot in App Store Connect | Required? | Files | Size |
  |---|---|---|---|
  | iPhone with Dynamic Island (medium display) | **Required** | `Screenshots/iphone-6.3/*.png` | 1206 × 2622 |
  | iPhone with Dynamic Island (large display) | Optional | `Screenshots/iphone-6.9/*.png` | 1320 × 2868 |
  | iPad 13" | **Required** (app runs on iPad) | `Screenshots/ipad-13/*.png` | 2064 × 2752 |
  | iPhone app preview (video) | Optional | `Previews/iphone-6.9.mp4` | 886 × 1920, 25 s |
  | iPad app preview (video) | Optional | `Previews/ipad-13.mp4` | 1200 × 1600, 25 s |
  | iPhone Duo | Not required yet (from April 2027, iOS 27.1 SDK) | — | — |

- Promotional text (170), Description (4000), Keywords (100 bytes, comma-separated), Support URL (required),
  Marketing URL (optional), Copyright (required, e.g. `2026 Pramod Goyal`; Apple adds the ©): from metadata.md.
- **Build**: click **+** and choose the build you uploaded.
- **App Review Information**: untick "Sign-in required". Contact phone must start with `+` and the country code.
  Paste the review notes from metadata.md.
- Version release: Automatically.

Then **macOS App → 1.0 Prepare for Submission**:
- Screenshots (required, 16:10): `Screenshots/mac/*.png` at 2880 × 1800. App preview (optional): `Previews/mac.mp4` at 1920 × 1080.
- Same text fields; pick the Mac build.

App-level pages (left sidebar):
- **App Information**: Category Education / Reference. Age rating → Edit → answer None everywhere (4+).
  Content rights: choose **Yes, it contains third-party content** and confirm you have the rights. The lookups and bonus word use Wiktionary and dictionaryapi.dev content under CC BY-SA, with attribution in the app.
- **App Privacy**: Privacy Policy URL → `https://goyalpramod.github.io/daily-word/privacy`. Data collection → **No, we do not collect data from this app**. Publish.
- **Pricing and Availability**: Price **Free (0)**. Availability: all countries except **China mainland** (it now needs an AI-content declaration and a security assessment).

EU only: **Business → Trader status**: declare yourself a **non-trader** (you're not selling anything), otherwise the app won't be offered in the EU.

## 5. Submit

On each platform's version page: **Add for Review** → **Submit to App Review**. Reviews usually take 1–3 days. You'll get an email either way.

## Costs

None beyond the Apple Developer Program you already pay for. Free apps have no fees; iCloud sync uses each user's own iCloud storage; the dictionary sources are free; GitHub hosting is free.
