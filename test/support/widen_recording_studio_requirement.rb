# frozen_string_literal: true

# Accessible, API, Attachable, Cache, Logs, Metrics, Site Settings, Trashable,
# Root Switchable, and Internationalization still require recording_studio below 6
# on the tags this Gemfile pins. Widen that requirement when Bundler loads those
# gemspecs so this app can resolve 6.1.0. Require this file from the Gemfile.
# `bundle install` evaluates the Gemfile before it loads test/support any other way.
module WidenRecordingStudioRequirement
  def add_dependency(name, *requirements)
    widened = name.to_s == "recording_studio" && requirements.none? { |requirement| requirement.to_s.include?("6") }
    requirements = [">= 6.1.0"] if widened

    super
  end
end

Gem::Specification.prepend(WidenRecordingStudioRequirement) unless Gem::Specification.ancestors.include?(WidenRecordingStudioRequirement)
