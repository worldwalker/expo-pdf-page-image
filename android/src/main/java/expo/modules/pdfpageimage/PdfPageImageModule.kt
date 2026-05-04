package expo.modules.pdfpageimage

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import expo.modules.kotlin.exception.CodedException
import expo.modules.kotlin.exception.Exceptions
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.util.UUID

private const val OUTPUT_DIR_NAME = "pdf-page-image"

private class PdfInvalidUri(message: String) : CodedException("ERR_PDF_INVALID_URI", message, null)

private class PdfFileNotFound(message: String) : CodedException("ERR_PDF_FILE_NOT_FOUND", message, null)

private class PdfOpenFailed(message: String) : CodedException("ERR_PDF_OPEN_FAILED", message, null)

private class PdfEmptyDocument : CodedException("ERR_PDF_EMPTY_DOCUMENT", "PDF document does not contain any pages.", null)

private class PdfRenderFailed(message: String) : CodedException("ERR_PDF_RENDER_FAILED", message, null)

private class PdfWriteFailed(message: String) : CodedException("ERR_PDF_WRITE_FAILED", message, null)

private class PdfCleanupFailed(message: String) : CodedException("ERR_PDF_CLEANUP_FAILED", message, null)

class PdfPageImageModule : Module() {
  private val context: Context
    get() = appContext.reactContext ?: throw Exceptions.ReactContextLost()

  override fun definition() = ModuleDefinition {
    Name("PdfPageImage")

    AsyncFunction("generateAllPages") { uri: String, scale: Double ->
      generateAllPages(uri, scale)
    }

    AsyncFunction("cleanupPages") { uris: List<String> ->
      cleanupPages(uris)
    }
  }

  private fun outputDirectory(): File {
    val dir = File(context.cacheDir, OUTPUT_DIR_NAME)
    if (!dir.exists()) {
      if (!dir.mkdirs()) {
        throw PdfWriteFailed("Failed to create PDF page output directory: ${dir.path}")
      }
    }
    return dir
  }

  private fun parsePdfUri(uriString: String): Uri {
    val trimmed = uriString.trim()
    if (trimmed.isEmpty()) {
      throw PdfInvalidUri("PDF URI is empty.")
    }
    return when {
      trimmed.startsWith("content://") -> Uri.parse(trimmed)
      trimmed.startsWith("file://") -> Uri.parse(trimmed)
      trimmed.startsWith("/") ->
        Uri.parse(File(trimmed).absoluteFile.toURI().toString())
      else -> throw PdfInvalidUri("Unsupported PDF URI: $trimmed")
    }
  }

  private fun openReadOnlyPfd(uri: Uri): ParcelFileDescriptor {
    return when (uri.scheme?.lowercase()) {
      "content" -> {
        try {
          context.contentResolver.openFileDescriptor(uri, "r")
        } catch (e: SecurityException) {
          throw PdfOpenFailed("Unable to open PDF from content URI: ${e.localizedMessage}")
        } catch (e: FileNotFoundException) {
          throw PdfFileNotFound("PDF file not found for content URI: ${e.localizedMessage}")
        } ?: throw PdfOpenFailed("Unable to open PDF from content URI.")
      }
      "file" -> {
        val path = uri.path ?: throw PdfInvalidUri("Invalid file URI: $uri")
        val file = File(path)
        if (!file.exists()) {
          throw PdfFileNotFound("PDF file not found at path: ${file.path}")
        }
        try {
          ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        } catch (e: Exception) {
          throw PdfOpenFailed("Unable to open PDF document at path: ${file.path} (${e.localizedMessage})")
        }
      }
      else -> throw PdfInvalidUri("Unsupported PDF URI scheme: ${uri.scheme}")
    }
  }

  private fun generateAllPages(uriString: String, scale: Double): List<Map<String, Any>> {
    val uri = parsePdfUri(uriString)
    val pfd = openReadOnlyPfd(uri)
    val renderer = try {
      PdfRenderer(pfd)
    } catch (e: Exception) {
      pfd.close()
      throw PdfOpenFailed("Unable to open PDF document: ${e.localizedMessage}")
    }

    return try {
      if (renderer.pageCount <= 0) {
        throw PdfEmptyDocument()
      }

      val outputDir = outputDirectory()
      val renderScale = scale.coerceAtLeast(1.0).toFloat()
      val results = ArrayList<Map<String, Any>>(renderer.pageCount)

      for (i in 0 until renderer.pageCount) {
        val page = try {
          renderer.openPage(i)
        } catch (e: Exception) {
          throw PdfRenderFailed("Unable to access PDF page at index $i: ${e.localizedMessage}")
        }

        try {
          val baseW = page.width.coerceAtLeast(1)
          val baseH = page.height.coerceAtLeast(1)
          val outW = (baseW * renderScale).toInt().coerceAtLeast(1)
          val outH = (baseH * renderScale).toInt().coerceAtLeast(1)

          val bitmap = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
          val canvas = Canvas(bitmap)
          canvas.drawColor(Color.WHITE)

          val matrix = Matrix()
          matrix.setScale(renderScale, renderScale)

          try {
            page.render(bitmap, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
          } catch (e: Exception) {
            bitmap.recycle()
            throw PdfRenderFailed("Failed to render PDF page at index $i: ${e.localizedMessage}")
          }

          val outFile = File(outputDir, "${UUID.randomUUID()}.png")
          try {
            FileOutputStream(outFile).use { fos ->
              if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, fos)) {
                throw PdfWriteFailed("Failed to encode rendered PDF page as PNG.")
              }
            }
          } catch (e: PdfWriteFailed) {
            bitmap.recycle()
            throw e
          } catch (e: Exception) {
            bitmap.recycle()
            throw PdfWriteFailed("Failed to write rendered PDF page: ${e.localizedMessage}")
          }

          bitmap.recycle()

          results.add(
            mapOf(
              "width" to outW,
              "height" to outH,
              "uri" to outFile.absoluteFile.toURI().toString()
            )
          )
        } finally {
          page.close()
        }
      }

      results
    } finally {
      renderer.close()
      pfd.close()
    }
  }

  private fun cleanupPages(uris: List<String>) {
    val outputDir = outputDirectory().canonicalFile
    val outputPrefix = outputDir.absolutePath + File.separator
    val cleanupErrors = mutableListOf<String>()

    for (raw in uris.toSet()) {
      val file = resolveCleanupFile(raw.trim()) ?: continue
      val canonical: String
      try {
        canonical = file.canonicalPath
      } catch (_: Exception) {
        continue
      }

      if (!canonical.startsWith(outputPrefix)) {
        continue
      }

      if (!file.exists()) {
        continue
      }

      try {
        if (!file.delete()) {
          cleanupErrors.add("Failed to remove ${file.name}: delete returned false")
        }
      } catch (e: Exception) {
        cleanupErrors.add("Failed to remove ${file.name}: ${e.localizedMessage}")
      }
    }

    if (cleanupErrors.isNotEmpty()) {
      throw PdfCleanupFailed(cleanupErrors.joinToString("\n"))
    }
  }

  private fun resolveCleanupFile(uriString: String): File? {
    if (uriString.isEmpty()) {
      return null
    }
    return when {
      uriString.startsWith("content://") -> null
      uriString.startsWith("file://") -> {
        val uri = Uri.parse(uriString)
        val path = uri.path ?: return null
        File(path)
      }
      uriString.startsWith("/") -> File(uriString)
      else -> null
    }
  }
}
