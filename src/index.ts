import { requireNativeModule } from "expo-modules-core";

/**
 * @description The type of the page image.
 * @example
 * ```ts
 * {
 *   height: number;
 *   uri: string;
 *   width: number;
 * }
 * ```
 */
export type PageImage = {
  height: number;
  uri: string;
  width: number;
};

type NativePdfPageImageModule = {
  cleanupPages(uris: string[]): Promise<void>;
  generateAllPages(uri: string, scale: number): Promise<PageImage[]>;
};

let nativeModule: NativePdfPageImageModule | null = null;

function getNativeModule(): NativePdfPageImageModule {
  const module =
    nativeModule ?? requireNativeModule<NativePdfPageImageModule>("PdfPageImage");

  nativeModule = module;

  return module;
}

/**
 * @description The module name for the native module.
 * @example
 * ```ts
 * import PdfPageImageModule from "expo-pdf-page-image";
 *
 * PdfPageImageModule.cleanupPages(["file://path/to/pdf.pdf"]);
 * PdfPageImageModule.generateAllPages("file://path/to/pdf.pdf", 1);
 * ```
 */
const PdfPageImageModule = {
  /**
   * @description Clean up the pages of the PDF.
   * @param uris - The URIs of the PDF files to clean up.
   * @example
   * ```ts
   * import PdfPageImageModule from "expo-pdf-page-image";   
   *
   * PdfPageImageModule.cleanupPages(["file://path/to/pdf.pdf"]);
   * ```
   */
  cleanupPages(uris: string[]) {
    return getNativeModule().cleanupPages(uris);
  },
  /**
   * @description Generate all pages of the PDF.
   * @param uri - The URI of the PDF file to generate pages from.
   * @param scale - The scale of the pages.
   * @example
   * ```ts
   * import PdfPageImageModule from "expo-pdf-page-image";   
   *
   * PdfPageImageModule.generateAllPages("file://path/to/pdf.pdf", 1);
   * ```
   */
  generateAllPages(uri: string, scale = 1) {
    return getNativeModule().generateAllPages(uri, scale);
  },
};

export default PdfPageImageModule;
