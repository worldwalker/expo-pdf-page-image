import ExpoModulesCore
import Foundation
import PDFKit
import UIKit

private enum PdfPageImageError: CodedError {
  case cleanupFailed(String)
  case emptyDocument
  case fileNotFound(String)
  case invalidUri(String)
  case openFailed(String)
  case renderFailed(String)
  case writeFailed(String)

  var code: String {
    switch self {
    case .cleanupFailed:
      return "ERR_PDF_CLEANUP_FAILED"
    case .emptyDocument:
      return "ERR_PDF_EMPTY_DOCUMENT"
    case .fileNotFound:
      return "ERR_PDF_FILE_NOT_FOUND"
    case .invalidUri:
      return "ERR_PDF_INVALID_URI"
    case .openFailed:
      return "ERR_PDF_OPEN_FAILED"
    case .renderFailed:
      return "ERR_PDF_RENDER_FAILED"
    case .writeFailed:
      return "ERR_PDF_WRITE_FAILED"
    }
  }

  var description: String {
    switch self {
    case .cleanupFailed(let message),
         .fileNotFound(let message),
         .invalidUri(let message),
         .openFailed(let message),
         .renderFailed(let message),
         .writeFailed(let message):
      return message
    case .emptyDocument:
      return "PDF document does not contain any pages."
    }
  }
}

public final class PdfPageImageModule: Module {
  private let outputDirectoryName = "pdf-page-image"

  public func definition() -> ModuleDefinition {
    Name("PdfPageImage")

    AsyncFunction("generateAllPages") { (uri: String, scale: Double) in
      return try self.generateAllPages(uri: uri, scale: scale)
    }

    AsyncFunction("cleanupPages") { (uris: [String]) in
      try self.cleanupPages(uris: uris)
    }
  }

  private func generateAllPages(uri: String, scale: Double) throws -> [[String: Any]] {
    let fileUrl = try normalizePdfUrl(uri)

    guard FileManager.default.fileExists(atPath: fileUrl.path) else {
      throw PdfPageImageError.fileNotFound("PDF file not found at path: \(fileUrl.path)")
    }

    guard let document = PDFDocument(url: fileUrl) else {
      throw PdfPageImageError.openFailed("Unable to open PDF document at path: \(fileUrl.path)")
    }

    guard document.pageCount > 0 else {
      throw PdfPageImageError.emptyDocument
    }

    try ensureOutputDirectoryExists()

    return try (0..<document.pageCount).map { index in
      guard let page = document.page(at: index) else {
        throw PdfPageImageError.renderFailed("Unable to access PDF page at index \(index).")
      }

      return try renderPage(page, scale: scale)
    }
  }

  private func cleanupPages(uris: [String]) throws {
    let outputDirectory = try outputDirectory()
    var cleanupErrors: [String] = []

    for uri in Set(uris) {
      guard let fileUrl = normalizeOutputUrl(uri) else {
        continue
      }

      guard fileUrl.path.hasPrefix(outputDirectory.path) else {
        continue
      }

      if !FileManager.default.fileExists(atPath: fileUrl.path) {
        continue
      }

      do {
        try FileManager.default.removeItem(at: fileUrl)
      } catch {
        cleanupErrors.append("Failed to remove \(fileUrl.lastPathComponent): \(error.localizedDescription)")
      }
    }

    if !cleanupErrors.isEmpty {
      throw PdfPageImageError.cleanupFailed(cleanupErrors.joined(separator: "\n"))
    }
  }

  private func renderPage(_ page: PDFPage, scale: Double) throws -> [String: Any] {
    let pageBounds = normalizedBounds(for: page)
    let renderScale = max(scale, 1)
    let renderSize = CGSize(
      width: max(pageBounds.width * renderScale, 1),
      height: max(pageBounds.height * renderScale, 1)
    )

    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)

    let image = renderer.image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: renderSize))

      context.cgContext.saveGState()
      context.cgContext.translateBy(x: 0, y: renderSize.height)
      context.cgContext.scaleBy(x: renderScale, y: -renderScale)
      page.draw(with: .mediaBox, to: context.cgContext)
      context.cgContext.restoreGState()
    }

    guard let data = image.pngData() else {
      throw PdfPageImageError.writeFailed("Failed to encode rendered PDF page as PNG.")
    }

    let outputUrl = try outputDirectory().appendingPathComponent("\(UUID().uuidString).png")

    do {
      try data.write(to: outputUrl, options: .atomic)
    } catch {
      throw PdfPageImageError.writeFailed("Failed to write rendered PDF page: \(error.localizedDescription)")
    }

    return [
      "height": Int(renderSize.height.rounded()),
      "uri": outputUrl.absoluteString,
      "width": Int(renderSize.width.rounded())
    ]
  }

  private func normalizedBounds(for page: PDFPage) -> CGRect {
    let bounds = page.bounds(for: .mediaBox)
    let rotation = ((page.rotation % 360) + 360) % 360

    if rotation == 90 || rotation == 270 {
      return CGRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.height, height: bounds.width)
    }

    return bounds
  }

  private func normalizePdfUrl(_ uri: String) throws -> URL {
    let trimmedUri = uri.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedUri.isEmpty else {
      throw PdfPageImageError.invalidUri("PDF URI is empty.")
    }

    if trimmedUri.hasPrefix("file://") {
      guard let fileUrl = URL(string: trimmedUri), fileUrl.isFileURL else {
        throw PdfPageImageError.invalidUri("Invalid file URI: \(trimmedUri)")
      }
      return fileUrl
    }

    if trimmedUri.hasPrefix("/") {
      return URL(fileURLWithPath: trimmedUri)
    }

    throw PdfPageImageError.invalidUri("Unsupported PDF URI: \(trimmedUri)")
  }

  private func normalizeOutputUrl(_ uri: String) -> URL? {
    let trimmedUri = uri.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmedUri.hasPrefix("file://") {
      return URL(string: trimmedUri)
    }

    if trimmedUri.hasPrefix("/") {
      return URL(fileURLWithPath: trimmedUri)
    }

    return nil
  }

  private func outputDirectory() throws -> URL {
    return FileManager.default.temporaryDirectory
      .appendingPathComponent(outputDirectoryName, isDirectory: true)
  }

  private func ensureOutputDirectoryExists() throws {
    let directory = try outputDirectory()

    if FileManager.default.fileExists(atPath: directory.path) {
      return
    }

    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
      throw PdfPageImageError.writeFailed("Failed to create PDF page output directory: \(error.localizedDescription)")
    }
  }
}
