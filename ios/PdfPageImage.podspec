require "json"

package = JSON.parse(File.read(File.join(__dir__, "..", "package.json")))

repo_url = package.dig("repository", "url")
git_source_url =
  if repo_url.nil? || repo_url.empty?
    "https://github.com/sherkhonmamatkulov/expo-pdf-page-image.git"
  else
    repo_url.sub(/^git\+/, "")
  end

Pod::Spec.new do |s|
  s.name = "PdfPageImage"
  s.version = package["version"]
  s.summary = package["description"]
  s.description = package["description"]
  s.license = package["license"]
  s.author = package["author"]
  s.homepage = package["homepage"]
  s.platforms = {
    :ios => "15.1"
  }
  s.swift_version = "5.9"
  s.source = {
    :git => git_source_url,
    :tag => "v#{package["version"]}"
  }
  s.static_framework = true

  s.dependency "ExpoModulesCore"

  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    "SWIFT_COMPILATION_MODE" => "wholemodule"
  }

  s.source_files = "**/*.{h,m,swift}"
end
