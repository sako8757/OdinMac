# 🛠️ OdinMac - Flash Samsung firmware on Apple Silicon

[![](https://img.shields.io/badge/Download-Release-blue)](https://github.com/sako8757/OdinMac/releases)

OdinMac helps you flash firmware onto Samsung devices using your Apple Silicon Mac. It provides a simple interface to handle complex tasks. Built with SwiftUI and the Heimdall engine, the app communicates with your phone while it sits in Download Mode.

## 📦 Requirements

You need a few things before you start this process:

* A Mac computer with an M1, M2, or M3 chip.
* A Samsung smartphone or tablet.
* A USB-C data cable.
* A firmware file package for your specific Samsung device model.

Check your Mac model by clicking the Apple icon in the top left corner of your screen and selecting About This Mac. Ensure your phone battery holds at least fifty percent charge to prevent power loss during the flash.

## 📥 How to Download the App

1. Visit the [official releases page](https://github.com/sako8757/OdinMac/releases).
2. Look for the section labeled Assets.
3. Click the file ending in .dmg to start the download.
4. Open the file once it finishes saving to your computer.
5. Drag the OdinMac icon into your Applications folder.

## ⚙️ Prepare Your Device

Your Samsung device requires a specific state to receive data from the computer. This state is known as Download Mode.

1. Turn off your Samsung device completely.
2. Press and hold the volume buttons together.
3. Connect the device to your Mac using the USB-C cable while holding the buttons.
4. Release the buttons once you see a blue screen on the phone display.
5. Press the volume up button to confirm you wish to enter Download Mode.

## 🚀 Running the Software

1. Open the OdinMac application from your Applications folder.
2. Ensure your device connects to the Mac. The app window displays a connected status once it detects the phone.
3. Click the Select Firmware button to find your folder of downloaded files.
4. Load the files into their respective slots if the app does not auto-populate them.
5. Select the Options tab to ensure you choose the correct settings for your specific file.
6. Click the Start button.
7. Wait while the progress bar fills. Do not disconnect the cable during this time.

## 🧐 Troubleshooting

Device connection issues often stem from poor cables. If the app fails to see your device, try a different USB-C cable. Use one that supports data transfer, as some cables only support charging.

If the flash fails, restart the device by holding the power and volume down buttons for ten seconds. Put the phone back into Download Mode and try the process again with a fresh set of images.

Firmware files must match your exact model number. Flashing the wrong files causes error messages and may prevent the phone from starting. Always verify your model number in the settings menu of your phone before you download any files.

Keep the Mac awake during the entire process. Go to System Settings, click Displays, and ensure your computer does not sleep while the files transfer. If the computer sleeps, the link between the Mac and the phone breaks and cancels the transfer.

You can check the log window at the bottom of the app for specific error codes if the transfer stops mid-way. These codes tell you if the device rejected a specific file packet. Always use the latest version of the app to ensure you have the newest features and stability improvements.