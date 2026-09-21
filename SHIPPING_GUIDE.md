# CovaMac — Official Shipping & Distribution Guide

This guide walks you through distributing **CovaMac** to the public, hosting the download on your website or Framer page, and configuring Apple Developer ID code signing and notarization.

---

## 1. Quick Start: Build the Shipping Package

To build the complete release distribution package right now:
```bash
./package_release.sh
```

This automated script will:
1. Compile **Universal 2 native binaries** for both Apple Silicon (`arm64` M1–M4) and Intel (`x86_64`).
2. Merge them into a single fat executable using `lipo`.
3. Assemble the **`CovaMac.app`** bundle with high-resolution icons, Retina display assets, and production `Info.plist`.
4. Apply **Hardened Runtime** with required entitlements (`Entitlements.plist`).
5. Generate a branded **`CovaMac-1.0.0.dmg`** disk image with an `/Applications` drag-and-drop link and custom volume icon.
6. Package a **`CovaMac-1.0.0.zip`** archive.
7. Generate cryptographic **`SHA256SUMS.txt`** checksums for verification.

All artifacts are generated in the `./dist/` directory:
- 📁 **`dist/CovaMac-1.0.0.dmg`** — Recommended installer format for your website and users.
- 📦 **`dist/CovaMac-1.0.0.zip`** — Direct download archive.
- 📄 **`dist/SHA256SUMS.txt`** — Verification checksums for release integrity.
- 🖥️ **`dist/CovaMac.app`** — Standalone application bundle.

---

## 2. Where to Upload & Host Your Files

### Option A: GitHub Releases (Recommended & Free CDN)
1. Go to your GitHub repository: `https://github.com/your-username/CovaMac`.
2. Click **Releases** → **Draft a new release**.
3. Set tag version: `v1.0.0`.
4. Release title: `CovaMac Pro 1.0.0 — Release`.
5. Drag and drop the following files from `./dist/`:
   - `CovaMac-1.0.0.dmg`
   - `CovaMac-1.0.0.zip`
   - `SHA256SUMS.txt`
6. Click **Publish release**.
7. Right-click `CovaMac-1.0.0.dmg` on the release page and copy its link:
   `https://github.com/your-username/CovaMac/releases/download/v1.0.0/CovaMac-1.0.0.dmg`

### Option B: Cloudflare R2 / AWS S3 / DigitalOcean Spaces
- Upload `CovaMac-1.0.0.dmg` and set cache headers (`Cache-Control: public, max-age=3600`).
- Point your custom download domain (e.g. `https://download.covamac.com/CovaMac.dmg`).

---

## 3. Connecting the Download Button in Framer

In your Framer landing page:
1. Select your primary hero **"Download Free"** or **"Download for Mac"** button.
2. In the right-hand panel under **Link**, paste your direct download URL:
   - e.g. `https://github.com/your-username/CovaMac/releases/download/v1.0.0/CovaMac-1.0.0.dmg`
3. Set **New Tab** to `Off` (so it triggers direct file download).
4. Add a subtle badge or caption below the button:
   - *"Compatible with macOS 13+ (Ventura, Sonoma, Sequoia) • Universal 2 for Apple Silicon & Intel"*

---

## 4. Apple Developer ID Code Signing & Notarization

When you are ready to distribute without any Gatekeeper security warnings:

### Step 1: Install Your Developer ID Certificate
1. Log in to [developer.apple.com](https://developer.apple.com/account/resources/certificates/list).
2. Create and download a **Developer ID Application** certificate.
3. Double-click the `.cer` file to import it into your macOS Keychain.
4. Verify it in Terminal:
   ```bash
   security find-identity -v -p codesigning
   ```
   You will see an entry like:
   `1) XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX "Developer ID Application: Your Name (TEAM_ID)"`

### Step 2: Store Notarization Credentials
Run `notarytool` once to securely save your App Store Connect credentials into your macOS Keychain:
```bash
xcrun notarytool store-credentials "COVAMAC_NOTARY" \
  --apple-id "your-apple-id@email.com" \
  --team-id "YOUR_10_DIGIT_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```
*(Generate an app-specific password at [appleid.apple.com](https://appleid.apple.com) under Security → App-Specific Passwords).*

### Step 3: Run the 1-Command Release & Notarize Script
```bash
./package_release.sh \
  --sign-id "Developer ID Application: Your Name (TEAM_ID)" \
  --notarize-profile "COVAMAC_NOTARY"
```

The script will automatically:
- Code-sign the universal binary with your Developer ID and Hardened Runtime.
- Submit `CovaMac-1.0.0.dmg` to Apple's notarization servers.
- Wait for Apple's approval receipt.
- Staple the notarization ticket into `CovaMac-1.0.0.dmg` and `CovaMac.app`.

---

## 5. Notes for Ad-Hoc / Beta Distribution (Before Purchasing Apple Developer Account)

If you distribute the ad-hoc build before purchasing an Apple Developer membership ($99/year), macOS Gatekeeper may display a prompt stating the developer cannot be verified.

Users can open the app effortlessly using either method:
- **Method 1 (Finder)**: Right-click (or Control-click) `CovaMac.app` and choose **Open**, then click **Open**.
- **Method 2 (Terminal)**: Clear the quarantine flag:
  ```bash
  xattr -cr /Applications/CovaMac.app
  ```

---

## 6. Pre-Flight Verification Checklist

Before publishing your release:
- [x] Universal 2 binary verified (`arm64` + `x86_64`).
- [x] App Icon & high-res branding bundled.
- [x] Hardened Runtime & `Entitlements.plist` active.
- [x] Menu bar extra and battery telemetry functioning.
- [x] Uninstaller and process manager active with deadlock safeguards.
- [x] Amazon affiliate links in `MonetizationConfig.swift` verified.
- [x] Checksums file `dist/SHA256SUMS.txt` matches generated packages.
