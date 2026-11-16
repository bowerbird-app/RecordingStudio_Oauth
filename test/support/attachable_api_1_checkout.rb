# frozen_string_literal: true

require "fileutils"

# Attachable v0.28.0 requires recording_studio_api < 1.0. This gem requires
# recording_studio_api >= 1.0.0. Bundler cannot solve both. The suite checks
# out that tag and opens the one requirement. Hosts still need an Attachable
# release that allows API 1.
module AttachableApi1Checkout
  TAG = "v0.28.0"
  SOURCE = "https://github.com/bowerbird-app/RecordingStudio_attachable.git"
  CLOSED = 'spec.add_dependency "recording_studio_api", ">= 0.24.0", "< 1.0"'
  OPEN = 'spec.add_dependency "recording_studio_api", ">= 1.0.0", "< 2.0"'

  module_function

  def prepare!(root)
    gemspec = File.join(root, "recording_studio_attachable.gemspec")
    checkout(root) unless File.file?(gemspec)
    relax(gemspec)
    root
  end

  def checkout(root)
    FileUtils.mkdir_p(File.dirname(root))
    system("git", "clone", "--depth", "1", "--branch", TAG, SOURCE, root, exception: true)
  end

  def relax(gemspec)
    text = File.read(gemspec)
    return if text.include?(OPEN)

    raise "Attachable gemspec no longer requires API < 1.0" unless text.include?(CLOSED)

    File.write(gemspec, text.sub(CLOSED, OPEN))
  end
end
