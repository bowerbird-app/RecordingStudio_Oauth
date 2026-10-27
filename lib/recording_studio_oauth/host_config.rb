# frozen_string_literal: true

module RecordingStudioOauth
  module HostConfig
    YAML_NAME = "recording_studio_oauth.yml"

    def self.file(app)
      candidates(app).find(&:exist?)
    end

    def self.candidates(app)
      files = []
      files << Pathname(app.root).join("config", YAML_NAME) if app.respond_to?(:root) && app.root
      files.concat(path_files(app))
      files
    end

    def self.path_files(app)
      return [] unless app.respond_to?(:paths) && app.paths && app.paths["config"]

      config_paths = app.paths["config"]
      dirs = config_paths.respond_to?(:existent) ? config_paths.existent : Array(config_paths)
      dirs.map { |dir| Pathname(dir).join(YAML_NAME) }
    end
  end
end
