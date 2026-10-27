# frozen_string_literal: true

require_relative "lib/recording_studio_oauth/version"

Gem::Specification.new do |spec| # rubocop:disable Metrics/BlockLength
  spec.name        = "recording_studio_oauth"
  spec.version     = RecordingStudioOauth::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_Oauth"
  spec.summary     = "Inbound Connect and outbound provider connections for Recording Studio"
  spec.description = "People Connect a registered app inbound. This app also connects out to third-party providers and stores those tokens on OutboundConnection rows. API stays the inbound resource server and token URL."
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

  spec.add_dependency "flat_pack", ">= 0.1.315"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", ">= 6.1.0"
  spec.add_dependency "recording_studio_accessible", "~> 0.11"
  spec.add_dependency "recording_studio_admin", "~> 2.0"
  spec.add_dependency "recording_studio_api", ">= 0.5.2", "< 0.18"
  spec.add_dependency "recording_studio_cache", "~> 0.5"
  spec.add_dependency "recording_studio_metrics", ">= 0.3", "< 1.0"
  spec.add_dependency "recording_studio_site_settings", "~> 0.2"
  spec.add_dependency "recording_studio_trashable", "~> 0.10"
  spec.add_dependency "view_component", ">= 4.14", "< 5"
end # rubocop:enable Metrics/BlockLength
