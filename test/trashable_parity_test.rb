# frozen_string_literal: true

require "test_helper"

# Proves Oauth call sites map onto RecordingStudioTrashable sibling APIs with
# main-compatible void / kept / active semantics (no invented wrappers).
class TrashableParityTest < Minitest::Test
  def test_gemspec_and_gemfile_pin_trashable_v0_9
    gemspec = File.read(File.expand_path("../recording_studio_oauth.gemspec", __dir__))
    gemfile = File.read(File.expand_path("../Gemfile", __dir__))
    dummy_gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio_trashable", "~> 0.9"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.9.0"'
    assert_includes dummy_gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.9.0"'
  end

  def test_engine_requires_trashable
    engine = File.read(File.expand_path("../lib/recording_studio_oauth/engine.rb", __dir__))

    assert_includes engine, 'require "recording_studio_trashable"'
  end

  def test_void_oauth_authorization_uses_void_recording_not_update_columns
    source = File.read(
      File.expand_path("../lib/recording_studio_oauth/services/void_oauth_authorization.rb", __dir__)
    )

    assert_includes source, "RecordingStudioTrashable.void_recording!(access_recording, time: time)"
    assert_includes source, "recording_studio_trashable_trashed?"
    assert_includes source, "return if access_recording.nil?"
    refute_includes source, "update_columns(trashed_at:"
    refute_includes source, "recording_studio_trashable_trash!"
  end

  def test_void_recording_source_still_pins_update_columns
    trashable_root = Gem.loaded_specs.fetch("recording_studio_trashable").full_gem_path
    source = File.read(File.join(trashable_root, "lib/recording_studio_trashable.rb"))
    method_source = source[/def void_recording!\(.*?\n    end/m]

    refute_nil method_source
    assert_includes method_source, "update_columns(trashed_at: time, updated_at: time)"
    refute_includes method_source, "update!("
  end

  def test_integration_and_admin_use_trashable_active_scope
    integration = File.read(File.expand_path("../lib/recording_studio_oauth/integration.rb", __dir__))
    admin = File.read(
      File.expand_path("../app/controllers/recording_studio_oauth/admin/oauth_clients_controller.rb", __dir__)
    )

    assert_includes integration, ".recording_studio_trashable_active"
    refute_match(/trashed_at:\s*nil/, integration)
    assert_includes admin, "unscoped.recording_studio_trashable_active.find_by"
    refute_match(/trashed_at:\s*nil/, admin)
  end

  def test_authorization_model_and_create_use_predicates
    model = File.read(File.expand_path("../app/models/recording_studio_oauth/oauth_authorization.rb", __dir__))
    create = File.read(
      File.expand_path("../lib/recording_studio_oauth/services/create_oauth_authorization.rb", __dir__)
    )

    assert_includes model, "recording_studio_trashable_kept?"
    assert_includes model, "recording_studio_trashable_trashed?"
    refute_match(/trashed_at\.(nil\?|present\?)/, model)
    assert_includes create, "recording_studio_trashable_trashed?"
    refute_match(/trashed_at\.present\?/, create)
  end

  class ScopedRecording
    class << self
      def table_name
        "recording_studio_recordings"
      end

      def connection
        @connection ||= FakeConnection.new
      end

      def scope(name, body)
        define_singleton_method(name) do |*args|
          instance_exec(*args, &body)
        end
      end
    end

    include RecordingStudioTrashable::RecordingScopes

    attr_accessor :trashed_at, :updated_at, :updated_with, :update_bang_called

    def initialize(trashed_at: nil, updated_at: nil)
      @trashed_at = trashed_at
      @updated_at = updated_at
      @update_bang_called = false
    end

    def update!(*)
      @update_bang_called = true
      raise "update! must not be called"
    end

    def update_columns(attributes)
      self.updated_with = attributes
      self.trashed_at = attributes[:trashed_at] if attributes.key?(:trashed_at)
      self.updated_at = attributes[:updated_at] if attributes.key?(:updated_at)
      self
    end
  end

  class FakeConnection
    def quote_table_name(name)
      %("#{name}")
    end

    def quote_column_name(name)
      %("#{name}")
    end
  end

  def test_predicates_match_trashed_at_presence
    active = ScopedRecording.new(trashed_at: nil)
    trashed = ScopedRecording.new(trashed_at: Time.utc(2026, 10, 13, 12, 0, 0))

    assert active.recording_studio_trashable_kept?
    refute active.recording_studio_trashable_trashed?
    refute trashed.recording_studio_trashable_kept?
    assert trashed.recording_studio_trashable_trashed?
  end

  def test_void_recording_is_idempotent_and_skips_nil_in_oauth_wrapper
    recording = ScopedRecording.new(trashed_at: nil, updated_at: Time.utc(2026, 1, 1))
    time = Time.utc(2026, 10, 13, 15, 30, 0)

    result = RecordingStudioTrashable.void_recording!(recording, time: time)

    assert_same recording, result
    assert_equal time, recording.trashed_at
    assert_equal time, recording.updated_at
    assert_equal({ trashed_at: time, updated_at: time }, recording.updated_with)
    refute recording.update_bang_called

    RecordingStudioTrashable.void_recording!(recording, time: Time.utc(2026, 10, 14))
    assert_equal time, recording.trashed_at

    error = assert_raises(ArgumentError) { RecordingStudioTrashable.void_recording!(nil) }
    assert_equal "recording is required", error.message
  end

  def test_kept_and_trashed_sql_helpers_quote_identifiers
    assert_equal '"recording_studio_recordings"."trashed_at" IS NULL',
                 ScopedRecording.recording_studio_trashable_kept_sql
    assert_equal '"child"."trashed_at" IS NULL',
                 ScopedRecording.recording_studio_trashable_kept_sql("child")
    assert_equal '"recording_studio_recordings"."trashed_at" IS NOT NULL',
                 ScopedRecording.recording_studio_trashable_trashed_sql
    assert_equal '"child"."trashed_at" IS NOT NULL',
                 ScopedRecording.recording_studio_trashable_trashed_sql("child")

    error = assert_raises(ArgumentError) { ScopedRecording.recording_studio_trashable_kept_sql(nil) }
    assert_equal "table is required", error.message
  end
end
