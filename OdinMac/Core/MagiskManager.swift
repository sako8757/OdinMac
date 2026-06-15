import Foundation

enum MagiskStep: Int, CaseIterable {
    case flashStock     = 0
    case bootAndroid    = 1
    case patchBoot      = 2
    case pullPatched    = 3
    case flashPatched   = 4
    case done           = 5

    var title: String {
        switch self {
        case .flashStock:   return "Flash Stock Firmware"
        case .bootAndroid:  return "Boot into Android"
        case .patchBoot:    return "Patch Boot with Magisk"
        case .pullPatched:  return "Pull Patched Image"
        case .flashPatched: return "Flash Patched Boot"
        case .done:         return "Rooted!"
        }
    }

    var detail: String {
        switch self {
        case .flashStock:
            return "Use the Flash tab to flash stock firmware. Disable re-partition unless needed."
        case .bootAndroid:
            return "Boot into Android. Allow setup to complete (you can skip sign-in)."
        case .patchBoot:
            return "Install Magisk APK on the device, open it, tap Install → Select and Patch a File, choose AP_*.tar from internal storage, then tap Let's Go."
        case .pullPatched:
            return "After patching, tap Pull from Device to automatically retrieve the magisk_patched*.tar from /sdcard/Download."
        case .flashPatched:
            return "Put the device back into Download Mode (Vol Down + Bixby + Power), then tap Flash Patched Boot."
        case .done:
            return "Device is rooted! Open Magisk app and tap Finish to complete setup."
        }
    }

    var icon: String {
        switch self {
        case .flashStock:   return "memorychip"
        case .bootAndroid:  return "power"
        case .patchBoot:    return "wrench.and.screwdriver"
        case .pullPatched:  return "arrow.down.circle"
        case .flashPatched: return "bolt.fill"
        case .done:         return "checkmark.seal.fill"
        }
    }
}

@MainActor
final class MagiskManager: ObservableObject {
    @Published var currentStep: MagiskStep = .flashStock
    @Published var patchedBootURL: URL?
    @Published var magiskAPKURL: URL?
    @Published var isBusy = false
    @Published var isDownloading = false
    @Published var latestMagiskVersion: String?
    @Published var statusMessage = ""
    @Published var error: String?

    var onLog: ((String, LogLevel) -> Void)?
    var onPatchedBootReady: ((URL) -> Void)?  // notify FlashViewModel to populate AP slot

    private func log(_ msg: String, _ level: LogLevel = .info) {
        onLog?(msg, level)
        statusMessage = msg
    }

    // MARK: - magiskboot location

    func locateMagiskboot() -> URL? {
        let fm = FileManager.default
        let candidates: [URL] = [
            Bundle.main.resourceURL?.appendingPathComponent("magiskboot"),
            URL(fileURLWithPath: "/opt/homebrew/bin/magiskboot"),
            URL(fileURLWithPath: "/usr/local/bin/magiskboot"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("bin/magiskboot"),
        ].compactMap { $0 }
        return candidates.first { fm.isExecutableFile(atPath: $0.path) }
    }

    var magiskbootAvailable: Bool { locateMagiskboot() != nil }

    // MARK: - Download latest Magisk APK from GitHub

    func downloadLatestMagisk() async {
        guard !isBusy else { return }
        isBusy = true
        isDownloading = true
        error = nil
        log("Fetching latest Magisk release from GitHub…")

        do {
            let apiURL = URL(string: "https://api.github.com/repos/topjohnwu/Magisk/releases/latest")!
            var req = URLRequest(url: apiURL)
            req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 20

            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let version = json["tag_name"] as? String,
                  let assets  = json["assets"]  as? [[String: Any]],
                  let asset   = assets.first(where: {
                      let name = ($0["name"] as? String ?? "").lowercased()
                      return name.hasPrefix("magisk") && name.hasSuffix(".apk")
                          && !name.contains("stub") && !name.contains("manager")
                  }),
                  let urlStr  = asset["browser_download_url"] as? String,
                  let dlURL   = URL(string: urlStr),
                  let apkName = asset["name"] as? String else {
                throw NSError(domain: "Magisk", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not find Magisk APK in latest GitHub release."
                ])
            }

            log("Downloading Magisk \(version)…")
            let dest = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(apkName)

            let (tmpURL, resp) = try await URLSession.shared.download(from: dlURL)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                throw NSError(domain: "Magisk", code: 2, userInfo: [NSLocalizedDescriptionKey: "Download failed: server error."])
            }
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmpURL, to: dest)

            magiskAPKURL = dest
            latestMagiskVersion = version
            log("Magisk \(version) saved to Downloads: \(apkName)", .success)
        } catch {
            self.error = error.localizedDescription
            log("Download failed: \(error.localizedDescription)", .error)
        }
        isDownloading = false
        isBusy = false
    }

    // MARK: - Patch boot.img locally (no phone required)

    /// Patches the boot image from `apURL` using the Magisk binaries inside `magiskAPK`
    /// and the `magiskboot` tool found on the host. Produces a flashable tar in ~/Downloads.
    func patchBootLocally(apURL: URL, magiskAPK: URL) async {
        guard !isBusy else { return }
        guard let magiskbootBin = locateMagiskboot() else {
            error = "magiskboot not found. Install it to /opt/homebrew/bin/magiskboot or place it in the app's Resources folder. See: github.com/topjohnwu/magiskboot_build"
            return
        }
        isBusy = true
        error = nil

        do {
            let workDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("odinmac-patch-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: workDir) }

            // 1. Extract boot.img from AP archive
            log("Extracting boot.img from AP archive…")
            let extractProc = Process()
            extractProc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            extractProc.arguments = ["-xf", apURL.path, "-C", workDir.path]
            extractProc.standardError = Pipe()
            try extractProc.run(); extractProc.waitUntilExit()

            let enumerator = FileManager.default.enumerator(
                at: workDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            var bootImg: URL?
            while let url = enumerator?.nextObject() as? URL {
                if url.lastPathComponent.lowercased() == "boot.img" { bootImg = url; break }
            }
            guard let bootImg else {
                throw NSError(domain: "MagiskPatch", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "boot.img not found inside AP archive."
                ])
            }
            log("Found boot.img", .success)

            // 2. Set up patch working directory
            let patchDir = workDir.appendingPathComponent("patch")
            try FileManager.default.createDirectory(at: patchDir, withIntermediateDirectories: true)
            let workBoot = patchDir.appendingPathComponent("boot.img")
            try FileManager.default.copyItem(at: bootImg, to: workBoot)

            // 3. Extract Magisk binaries from APK (APK is a ZIP file)
            log("Extracting Magisk binaries from APK…")
            let unzipProc = Process()
            unzipProc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzipProc.arguments = [
                "-o", "-q", magiskAPK.path,
                "lib/arm64-v8a/libmagiskinit.so",
                "lib/arm64-v8a/libmagisk64.so",
                "lib/arm64-v8a/libmagisk32.so",
                "lib/arm64-v8a/libstub.so",
                "-d", patchDir.path,
            ]
            unzipProc.standardOutput = Pipe(); unzipProc.standardError = Pipe()
            try unzipProc.run(); unzipProc.waitUntilExit()

            let arm64Dir = patchDir.appendingPathComponent("lib/arm64-v8a")
            let fm = FileManager.default

            func extractBin(_ lib: String, _ out: String) {
                let src = arm64Dir.appendingPathComponent(lib)
                let dst = patchDir.appendingPathComponent(out)
                guard fm.fileExists(atPath: src.path) else { return }
                try? fm.copyItem(at: src, to: dst)
                try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst.path)
            }
            extractBin("libmagiskinit.so", "magiskinit")
            extractBin("libmagisk64.so",   "magisk64")
            extractBin("libmagisk32.so",   "magisk32")
            extractBin("libstub.so",       "stub.apk")

            guard fm.fileExists(atPath: patchDir.appendingPathComponent("magiskinit").path) else {
                throw NSError(domain: "MagiskPatch", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "libmagiskinit.so not found in APK. Is this a valid Magisk APK?"
                ])
            }

            // 4. Copy magiskboot into patch dir and make executable
            let mbCopy = patchDir.appendingPathComponent("magiskboot")
            try fm.copyItem(at: magiskbootBin, to: mbCopy)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mbCopy.path)

            func run(_ args: [String]) -> Int32 {
                let p = Process()
                p.executableURL = mbCopy
                p.arguments = args
                p.currentDirectoryURL = patchDir
                p.standardOutput = Pipe(); p.standardError = Pipe()
                try? p.run(); p.waitUntilExit()
                return p.terminationStatus
            }

            // 5. Unpack boot image
            log("Unpacking boot image…")
            let unpackRC = run(["unpack", "boot.img"])
            guard unpackRC == 0 else {
                throw NSError(domain: "MagiskPatch", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "magiskboot unpack failed (rc=\(unpackRC)). Unsupported image format?"
                ])
            }

            // 6. Compress Magisk binaries with xz
            log("Compressing Magisk binaries…")
            for bin in ["magisk64", "magisk32"] where fm.fileExists(atPath: patchDir.appendingPathComponent(bin).path) {
                _ = run(["compress=xz", bin, "\(bin).xz"])
            }

            // 7. Inject Magisk into ramdisk
            log("Patching ramdisk…")
            var cpioCmds: [String] = [
                "add 0750 init magiskinit",
                "mkdir 0750 overlay.d",
                "mkdir 0750 overlay.d/sbin",
            ]
            for (file, entry) in [("magisk64.xz", "overlay.d/sbin/magisk64.xz"),
                                   ("magisk32.xz", "overlay.d/sbin/magisk32.xz"),
                                   ("stub.apk",    "overlay.d/sbin/stub.xz")]
            where fm.fileExists(atPath: patchDir.appendingPathComponent(file).path) {
                cpioCmds.append("add 0644 \(entry) \(file)")
            }
            _ = run(["cpio", "ramdisk.cpio"] + cpioCmds)

            // 8. Repack
            log("Repacking patched boot image…")
            guard run(["repack", "boot.img"]) == 0 else {
                throw NSError(domain: "MagiskPatch", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "magiskboot repack failed."
                ])
            }

            let newBoot = patchDir.appendingPathComponent("new-boot.img")
            guard fm.fileExists(atPath: newBoot.path) else {
                throw NSError(domain: "MagiskPatch", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "new-boot.img not produced after repack."
                ])
            }

            // 9. Rename new-boot.img → boot.img, pack into flashable tar
            log("Creating flashable tar…")
            let origBoot = patchDir.appendingPathComponent("boot.img.orig")
            try fm.moveItem(at: workBoot, to: origBoot)
            try fm.moveItem(at: newBoot,  to: workBoot)

            let ts   = Int(Date().timeIntervalSince1970)
            let dest = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("magisk_patched_mac_\(ts).tar")

            let tarProc = Process()
            tarProc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            tarProc.arguments = ["-cvf", dest.path, "-C", patchDir.path, "boot.img"]
            tarProc.standardError = Pipe()
            try tarProc.run(); tarProc.waitUntilExit()

            patchedBootURL = dest
            onPatchedBootReady?(dest)
            currentStep = .flashPatched
            log("Local patch complete: \(dest.lastPathComponent)", .success)
            log("Patched boot ready. Go to Step 5 to flash.", .success)

        } catch {
            self.error = error.localizedDescription
            log("Local patch failed: \(error.localizedDescription)", .error)
        }
        isBusy = false
    }

    // MARK: - Step actions

    /// Pull magisk_patched*.tar from device via ADB
    func pullPatchedBoot(adb: ADBManager) async {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        log("Searching for magisk_patched on device...")

        do {
            let paths = try await adb.findMagiskPatched()
            guard let remotePath = paths.first else {
                error = "No magisk_patched*.tar found on device.\nMake sure you ran the patch in the Magisk app."
                log("magisk_patched not found on device", .warning)
                isBusy = false
                return
            }
            log("Found: \(remotePath)")
            log("Pulling \((remotePath as NSString).lastPathComponent)...")

            let localURL = try await adb.pullFile(from: remotePath)
            patchedBootURL = localURL
            currentStep = .flashPatched
            onPatchedBootReady?(localURL)
            log("Patched boot saved: \(localURL.lastPathComponent)", .success)
        } catch {
            self.error = error.localizedDescription
            log("Pull failed: \(error.localizedDescription)", .error)
        }
        isBusy = false
    }

    /// Push Magisk APK and install via ADB
    func installMagisk(adb: ADBManager) async {
        guard let apkURL = magiskAPKURL else {
            error = "No Magisk APK selected"
            return
        }
        guard !isBusy else { return }
        isBusy = true
        error = nil
        log("Installing Magisk APK via ADB...")

        do {
            let result = try await adb.installMagisk(apkURL: apkURL)
            log(result, .success)
            // Push APK to internal storage too (Magisk needs it to patch)
            log("Pushing APK to /sdcard/Download/Magisk.apk...")
            try await adb.pushFile(from: apkURL, to: "/sdcard/Download/Magisk.apk")
            log("Magisk APK installed and pushed to device", .success)
            currentStep = .patchBoot
        } catch {
            self.error = error.localizedDescription
            log("Install failed: \(error.localizedDescription)", .error)
        }
        isBusy = false
    }

    /// Push AP firmware to device's internal storage so Magisk can find it for patching
    func pushAPFirmware(apURL: URL, adb: ADBManager) async {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        let fileName = apURL.lastPathComponent
        log("Pushing \(fileName) to device storage...")
        do {
            try await adb.pushFile(from: apURL, to: "/sdcard/Download/\(fileName)")
            log("AP firmware pushed. Open Magisk on device and patch it.", .success)
        } catch {
            self.error = error.localizedDescription
            log("Push failed: \(error.localizedDescription)", .error)
        }
        isBusy = false
    }

    func advance() {
        let next = MagiskStep(rawValue: currentStep.rawValue + 1) ?? .done
        currentStep = next
    }

    func reset() {
        currentStep = .flashStock
        patchedBootURL = nil
        statusMessage = ""
        error = nil
    }
}
