# expo-pdf-page-image - iOS and Android only!

Expo module that renders each page of a local PDF to PNG files and exposes `generateAllPages` / `cleanupPages`.

- **iOS:** `PDFKit`, output under the app temp directory (`NSTemporaryDirectory()/pdf-page-image/`).
- **Android:** `PdfRenderer`, output under `context.cacheDir/pdf-page-image/`. Input URIs: `file://`, absolute path, or `content://`.

## Install

```bash
npx expo install expo-pdf-page-image
```

Use in a project with Expo dev client / prebuild (native code required).

## API

See `src/index.ts`. Native module name: `PdfPageImage`.

## Usage example

import { PdfPageImageModule } from "expo-pdf-page-image";

PdfPageImageModule.generateAllPages("file://path/to/pdf.pdf", 1);

### The package also exports the types of images

```
export type PageImage = {
  height: number;
  uri: string;
  width: number;
};
```

## License

MIT
