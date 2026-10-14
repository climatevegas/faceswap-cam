# FaceSwap Cam - iPhone Build Guide

## Option 1: GitHub Actions (No Mac Needed) ⭐ RECOMMENDED

Build your iPhone app on Apple's cloud Macs automatically.

### Step 1: Create a GitHub account
Go to https://github.com and sign up (free)

### Step 2: Create a new repository
1. Click "+" → "New repository"
2. Name it: `faceswap-cam`
3. Set to **Public** (GitHub Actions is free for public repos)
4. Click "Create repository"

### Step 3: Upload the project
On the repository page, click "uploading an existing file" and drag the entire `FaceswapiOS` folder contents.

**OR** use these commands:
```bash
cd /home/famous/FaceswapiOS
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/faceswap-cam.git
git push -u origin main
```

### Step 4: Wait for the build
1. Go to the "Actions" tab in your repo
2. You'll see "Build iOS App" running
3. Wait ~5-10 minutes for it to complete

### Step 5: Download your IPA
1. Click on the completed build
2. Scroll down to "Artifacts"
3. Download `FaceswapCam-ipa.zip`
4. Inside is your `FaceswapCam.ipa` file!

---

## Option 2: Build on a Mac (If You Have One)

### Prerequisites:
- macOS with Xcode 14+
- Apple Developer account ($99/year)
- CocoaPods: `sudo gem install cocoapods`

### Steps:
```bash
# 1. Navigate to project
cd FaceswapiOS

# 2. Install dependencies
pod install

# 3. Open workspace (NOT the .xcodeproj!)
open FaceswapCam.xcworkspace

# 4. In Xcode:
#    - Select your Development Team under Signing & Capabilities
#    - Choose a simulator or connected device
#    - Press Cmd+R to run

# 5. To build IPA:
#    - Product → Archive
#    - Distribute App → Development
#    - Export and save
```

---

## Installing the IPA on Your iPhone

### Method A: AltStore (Free, no jailbreak)
1. Install AltStore on your computer (https://altstore.io)
2. Connect your iPhone
3. Install AltStore on your iPhone
4. Drag the IPA into AltStore
5. Trust the developer: Settings → General → VPN & Device Management

### Method B: Sideloadly (Free)
1. Download Sideloadly (https://sideloadly.io)
2. Connect iPhone
3. Drag IPA in, sign in with Apple ID
4. Install

### Method C: Cydia Impactor (Paid Apple IDs won't work)
1. Download Cydia Impactor
2. Drag IPA onto Impactor
3. Enter Apple ID

---

## What the App Does

- 📷 Real-time face replacement using front camera
- 🎤 Voice replacement (detects your voice, plays pre-recorded voice)
- 🎚️ Adjustable face blend and size
- 🎨 Modern dark UI
- 🔊 Pre-recorded voice file picker

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "No provisioning profile" | Sign in with Apple ID in Xcode → Signing & Capabilities |
| "Developer mode not enabled" | iPhone Settings → Privacy → Developer Mode → ON |
| "Untrusted Developer" | Settings → General → VPN & Device Management → Trust |
| Build fails in GitHub | Check Actions tab logs, ensure all files uploaded |

---

## Need Help?

The project is located at: `/home/famous/FaceswapiOS/`
Or download the zip: `/home/famous/Downloads/FaceswapiOS.zip`
