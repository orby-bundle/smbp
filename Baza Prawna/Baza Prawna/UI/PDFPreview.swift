//
//  PDFPreview.swift
//  Baza Prawna
//

import SwiftUI
import PDFKit
import UIKit
import Combine

struct PDFPreviewTile: View {
    let cacheKey: String
    let openText: String
    let tapHintText: String
    let pdfDataProvider: () async throws -> Data

    @StateObject private var previewLoader = PDFPreviewLoader()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(
        cacheKey: String,
        openText: String = "Zobacz PDF",
        tapHintText: String = "Podgląd dokumentu - dotknij, aby otworzyć",
        pdfDataProvider: @escaping () async throws -> Data
    ) {
        self.cacheKey = cacheKey
        self.openText = openText
        self.tapHintText = tapHintText
        self.pdfDataProvider = pdfDataProvider
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))

                if let image = previewLoader.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .overlay(alignment: .bottom) {
                            Text(tapHintText)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.45))
                                .clipShape(Capsule())
                                .padding(8)
                        }
                } else if previewLoader.isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Ładowanie podglądu...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.richtext")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Akt nie jest jeszcze dostępny")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1.41, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue.opacity(0.35), lineWidth: 1)
            )

            if !openText.isEmpty {
                Text(openText)
                    .font(horizontalSizeClass == .regular ? .body : .subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .underline()
                    .padding(.horizontal, horizontalSizeClass == .regular ? 14 : 12)
                    .padding(.vertical, horizontalSizeClass == .regular ? 8 : 6)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .task(id: cacheKey) {
            await previewLoader.loadPreview(cacheKey: cacheKey, pdfDataProvider: pdfDataProvider)
        }
    }
}

@MainActor
private final class PDFPreviewLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false

    private static let previewCache = NSCache<NSString, UIImage>()

    func loadPreview(
        cacheKey: String,
        pdfDataProvider: () async throws -> Data
    ) async {
        let versionedKey = "v2_\(cacheKey)" as NSString

        if let cachedImage = Self.previewCache.object(forKey: versionedKey) {
            image = cachedImage
            return
        }

        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await pdfDataProvider()
            guard let previewImage = Self.makeTopHalfPreviewImage(from: data) else { return }
            Self.previewCache.setObject(previewImage, forKey: versionedKey)
            image = previewImage
        } catch {
            image = nil
        }
    }

    private static func makeTopHalfPreviewImage(from pdfData: Data) -> UIImage? {
        guard
            let document = PDFDocument(data: pdfData),
            let page = document.page(at: 0)
        else {
            return nil
        }

        let pageBounds = page.bounds(for: .cropBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return nil }

        let targetWidth: CGFloat = 900
        let targetHeight = max(1, targetWidth * (pageBounds.height / pageBounds.width))
        let fullThumbnail = page.thumbnail(
            of: CGSize(width: targetWidth, height: targetHeight),
            for: .cropBox
        )

        guard let cgImage = fullThumbnail.cgImage else {
            return fullThumbnail
        }

        let cropHeight = max(1, Int(CGFloat(cgImage.height) * 0.55))
        let cropRect = CGRect(x: 0, y: 0, width: cgImage.width, height: cropHeight)

        guard let cropped = cgImage.cropping(to: cropRect) else {
            return fullThumbnail
        }

        return UIImage(cgImage: cropped, scale: fullThumbnail.scale, orientation: .up)
    }
}
