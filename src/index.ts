import { requireNativeModule } from "expo-modules-core";

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

const PdfPageImageModule = {
  cleanupPages(uris: string[]) {
    return getNativeModule().cleanupPages(uris);
  },
  generateAllPages(uri: string, scale = 1) {
    return getNativeModule().generateAllPages(uri, scale);
  },
};

export default PdfPageImageModule;
