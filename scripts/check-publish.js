/**
 * npm requires `name` + `version`. Warn if publishing without a real git remote
 * (podspec source uses repository URL + version tag).
 */
const pkg = require("../package.json");

if (!pkg.name || !pkg.version) {
  console.error("package.json must include name and version.");
  process.exit(1);
}

const repoUrl = pkg.repository?.url;
if (!repoUrl) {
  console.warn(
    "[expo-pdf-page-image] Consider setting package.json repository.url for CocoaPods git source + discoverability.",
  );
}

process.exit(0);
