# Sangtae (Status)

A lightweight, native macOS system monitor that lives in your menu bar.

"Sangtae" (상태) means "Status" or "Condition" in Korean.

## Features

- **CPU Usage:** Real-time load average and per-core usage (P-Core / E-Core distinction).
- **Memory:** Used vs Total memory with pressure indication.
- **Network:** Real-time upload and download speeds.
- **Disk:** Usage statistics for mounted volumes.
- **Battery:** Current level and charging status (simulated on desktops).
- **Processes:** List of top CPU-consuming processes.
- **Design:** Clean, native macOS UI with support for Dark/Light mode.

## Installation

### Method 1: Homebrew (Recommended)
This is the easiest way to install and keep the app updated.
```bash
brew tap smok95/sangtae
brew install --cask sangtae
```

### Method 2: Manual Download
Download the latest `.dmg` from the [Releases](https://github.com/smok95/Sangtae/releases) page.

## Building from Source

Requirements:
- macOS 13.0 or later
- Xcode Command Line Tools (for Swift)
- Python 3 + Pillow (for icon generation)

1. Clone the repository:
   ```bash
   git clone https://github.com/smok95/Sangtae.git
   cd Sangtae
   ```

2. Generate the app icon:
   ```bash
   pip3 install Pillow
   python3 generate_icon.py
   chmod +x make_icon.sh
   ./make_icon.sh
   ```

3. Build the application:
   ```bash
   chmod +x build_app.sh
   ./build_app.sh
   ```

4. The app will be located in the current directory as `Sangtae.app`.

## Troubleshooting

### "Sangtae.app is damaged and can't be opened"
Since this app is not signed with a paid Apple Developer ID, macOS Gatekeeper may block it when downloaded from the internet. To fix this:

1. Move the app to your `/Applications` folder.
2. Open Terminal and run:
   ```bash
   xattr -cr /Applications/Sangtae.app
   ```
3. Launch the app again.
