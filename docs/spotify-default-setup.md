# macOS M4 Pro: Set Spotify as Default Audio Handler

**Date:** 2026-01-06
**Device:** MacBook Pro (M4 Pro)
**OS:** macOS Sequoia (or newer)

## Overview
macOS does not provide a single "Default Music Player" setting. This guide documents the two distinct changes required to effectively make Spotify the default:
1.  **Media Keys:** Hijacking `Play/Pause` (F8) to stop opening Apple Music.
2.  **File Associations:** Forcing audio files (MP3, WAV, etc.) to open in Spotify.

---

## 1. Media Key Behavior (The "Play" Button)

The `Play` button is hardcoded to launch `Music.app` by the OS. We use a lightweight utility called **noTunes** to intercept this signal and redirect it.

### A. Installation & Setup

**Prerequisites:** Homebrew installed.

1.  **Install noTunes via Homebrew:**
    ```bash
    brew install --cask notunes
    ```

2.  **Configure Redirect (Optional but Recommended):**
    By default, noTunes simply blocks Apple Music. Run this command to explicitly tell it to launch Spotify instead if no music is playing:
    ```bash
    defaults write digital.twisted.noTunes replacement /Applications/Spotify.app
    ```

3.  **Startup:**
    * Open **noTunes** from your Applications folder.
    * Click the icon in the menu bar and ensure **"Launch on startup"** is checked.

### B. Revert Changes (Restore Apple Music)

If you wish to return to the default macOS behavior:

1.  **Remove the defaults configuration:**
    ```bash
    defaults delete digital.twisted.noTunes
    ```

2.  **Uninstall the utility:**
    ```bash
    brew uninstall --cask notunes
    ```

---

## 2. File Associations (Double-Clicking Files)

macOS defaults `.mp3`, `.m4a`, and `.wav` to Apple Music. This must be changed per file type.

### A. Configuration

1.  Locate a file of the desired type in Finder (e.g., `sample.mp3`).
2.  Right-click the file and select **Get Info** (or press `Cmd + I`).
3.  Locate the **"Open with:"** section.
4.  Select **Spotify.app** from the dropdown menu.
5.  Click the **Change All...** button.
6.  Click **Continue** on the confirmation prompt.

*Repeat this process for `.wav` and `.flac` files if necessary.*

### B. Revert Changes

1.  Locate a file of the specific type (e.g., `sample.mp3`).
2.  Right-click and select **Get Info**.
3.  Under **"Open with:"**, select **Music.app** (default).
4.  Click **Change All...** and confirm.

---

## 3. Automation Script (Advanced)

If you need to automate the file association changes across multiple machines, you can use `duti` (a CLI tool for default applications).

### A. Apply via Script
```bash
# Install duti
brew install duti

# bundle_id for Spotify is usually com.spotify.client
# Set Spotify as default for mp3, m4a, and wav
duti -s com.spotify.client .mp3 all
duti -s com.spotify.client .m4a all
duti -s com.spotify.client .wav all
```

### B. Revert via Script
```bash
# bundle_id for Apple Music is com.apple.Music
duti -s com.apple.Music .mp3 all
duti -s com.apple.Music .m4a all
duti -s com.apple.Music .wav all
```
