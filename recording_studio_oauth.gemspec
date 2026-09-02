# frozen_string_literal: true

require_relative "lib/recording_studio_oauth/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_oauth"
  spec.version     = RecordingStudioOauth::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_Oauth"
  spec.summary     = "Authorization server for third-party apps in Recording Studio"
  spec.description = "People Connect a registered app. The app gets its own Accessible grant. " \
                     "API stays the resource server and token URL."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_Oauth"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_Oauth/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "flat_pack", "~> 0.1.143"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "recording_studio_accessible", "~> 0.9"
  spec.add_dependency "recording_studio_admin", "~> 2.0"
  spec.add_dependency "recording_studio_api", "~> 0.5"
end
