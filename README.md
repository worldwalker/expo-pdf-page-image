# expo-pdf-page-image

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

## License

MIT
