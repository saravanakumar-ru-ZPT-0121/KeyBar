import SwiftUI
import Vision
import AppKit
import UniformTypeIdentifiers

/// Metadata parsed from a scanned `otpauth://totp/...` URI, ready to be handed
/// off to `AddAccountView` for confirmation and saving.
struct ImportedTOTPAccount {
    var issuer: String
    var accountName: String
    var base32Secret: String
    var algorithm: TOTPAlgorithm
    var digits: Int
    var period: Int
}

/// Lets the user drag-and-drop or paste a QR code image; decodes it with
/// Vision's `VNDetectBarcodesRequest` and parses the resulting `otpauth://` URI.
struct QRImportView: View {
    var onImport: (ImportedTOTPAccount) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Import from QR Code")
                .font(.headline)

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("Drag a QR code image here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 260, height: 160)
                .onDrop(of: [.image], isTargeted: $isTargeted) { providers in
                    handleDrop(providers: providers)
                }

            Button("Paste from Clipboard") {
                pasteFromClipboard()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }

            Button("Cancel", role: .cancel) { dismiss() }
        }
        .padding(24)
        .frame(width: 320, height: 360)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSImage.self) }) else {
            return false
        }
        _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
            DispatchQueue.main.async {
                if let image = image as? NSImage {
                    process(image: image)
                } else {
                    errorMessage = "Couldn't read that image."
                }
            }
        }
        return true
    }

    private func pasteFromClipboard() {
        guard let image = NSImage(pasteboard: .general) else {
            errorMessage = "No image found on the clipboard."
            return
        }
        process(image: image)
    }

    private func process(image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            errorMessage = "Couldn't read that image."
            return
        }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard
                let results = request.results,
                let payload = results.first?.payloadStringValue
            else {
                errorMessage = "No QR code found in that image."
                return
            }
            guard let account = QRImportView.parse(otpauthURI: payload) else {
                errorMessage = "That QR code isn't a valid otpauth:// TOTP code."
                return
            }
            errorMessage = nil
            onImport(account)
        } catch {
            errorMessage = "Failed to scan image: \(error.localizedDescription)"
        }
    }

    /// Parses an `otpauth://totp/Issuer:accountName?secret=...&issuer=...&algorithm=...&digits=...&period=...` URI.
    static func parse(otpauthURI: String) -> ImportedTOTPAccount? {
        guard
            let components = URLComponents(string: otpauthURI),
            components.scheme == "otpauth",
            components.host == "totp"
        else { return nil }

        var queryItems: [String: String] = [:]
        for item in components.queryItems ?? [] {
            queryItems[item.name] = item.value
        }

        guard let secret = queryItems["secret"], Base32.decode(secret) != nil else {
            return nil
        }

        let label = components.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let decodedLabel = label.removingPercentEncoding ?? label

        var issuer = queryItems["issuer"] ?? ""
        var accountName = decodedLabel

        if let separatorRange = decodedLabel.range(of: ":") {
            let labelIssuer = String(decodedLabel[decodedLabel.startIndex..<separatorRange.lowerBound])
            let labelAccount = String(decodedLabel[separatorRange.upperBound...])
            if issuer.isEmpty { issuer = labelIssuer }
            accountName = labelAccount
        }

        let algorithm = TOTPAlgorithm(rawValue: (queryItems["algorithm"] ?? "SHA1").uppercased()) ?? .sha1
        let digits = Int(queryItems["digits"] ?? "6") ?? 6
        let period = Int(queryItems["period"] ?? "30") ?? 30

        return ImportedTOTPAccount(
            issuer: issuer,
            accountName: accountName,
            base32Secret: secret,
            algorithm: algorithm,
            digits: digits,
            period: period
        )
    }
}
