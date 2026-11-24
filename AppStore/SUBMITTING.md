# Publishing Daily Word to the App Store

One App Store record covers iPhone, iPad and Mac (same bundle ID, so it's a "universal purchase").
Everything to paste is in [`metadata.md`](metadata.md); images and videos are in `Screenshots/` and `Previews/`.
Regenerate them any time with `scripts/render_store_assets.sh`.

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

In the app's **iOS App → 1.0 Prepare for Submission** page:

- **Previews and Screenshots**
  - iPhone 6.9" Display: drag in `Screenshots/iphone-6.9/*.png` (01 → 05) and `Previews/iphone-6.9.mp4`.
  - iPad 13" Display: `Screenshots/ipad-13/*.png` and `Previews/ipad-13.mp4`.
- Promotional text, Description, Keywords, Support URL, Marketing URL, Copyright: from metadata.md.
- **Build**: click **+** and choose the build you uploaded.
- **App Review Information**: untick "Sign-in required". Paste the review notes from metadata.md.
- Version release: Automatically.

Then **macOS App → 1.0 Prepare for Submission**:
- Screenshots: `Screenshots/mac/*.png`. App preview: `Previews/mac.mp4`.
- Same text fields; pick the Mac build.

App-level pages (left sidebar):
- **App Information**: Category Education / Reference. Age rating → Edit → answer None everywhere (4+).
  Content rights: choose **Yes, it contains third-party content** and confirm you have the rights. The lookups and bonus word use Wiktionary and dictionaryapi.dev content under CC BY-SA, with attribution in the app.
- **App Privacy**: Privacy Policy URL → `https://goyalpramod.github.io/daily-word/privacy`. Data collection → **No, we do not collect data from this app**. Publish.
- **Pricing and Availability**: Price **Free (0)**, all countries.

EU only: **Business → Trader status**: declare yourself a **non-trader** (you're not selling anything), otherwise the app won't be offered in the EU.

## 5. Submit

On each platform's version page: **Add for Review** → **Submit to App Review**. Reviews usually take 1–3 days. You'll get an email either way.

## Costs

None beyond the Apple Developer Program you already pay for. Free apps have no fees; iCloud sync uses each user's own iCloud storage; the dictionary sources are free; GitHub hosting is free.
