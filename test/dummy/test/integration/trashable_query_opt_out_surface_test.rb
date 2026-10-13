# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# Query-only Trashable must not load engine side effects. Surface for
# importmap/assets/capability/CopyHelper/trash metrics matches main (no Trashable UI).
class TrashableQueryOptOutSurfaceTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_by(email: "admin@admin.com") ||
            User.create!(email: "admin@admin.com", password: "Password", password_confirmation: "Password")
    sign_in @user
  end

  test "query-only boot loads helpers without Trashable engine side effects" do
    refute defined?(RecordingStudioTrashable::Engine),
           "Oauth must not load RecordingStudioTrashable::Engine"

    importmap_paths = Rails.application.config.importmap.paths.map(&:to_s)
    asset_paths = Rails.application.config.assets.paths.map(&:to_s)

    refute importmap_paths.any? { |path| path.include?("RecordingStudio_trashable") || path.include?("recording_studio_trashable") },
           "importmap paths must not include Trashable (got #{importmap_paths.grep(/trashable/i).inspect})"
    refute asset_paths.any? { |path| path.include?("RecordingStudio_trashable") || path.include?("recording_studio_trashable") },
           "asset paths must not include Trashable (got #{asset_paths.grep(/trashable/i).inspect})"

    refute RecordingStudio.registered_capabilities.key?(:trashable),
           "registered_capabilities must not include :trashable"

    helper_names = ActionView::Base.included_modules.map(&:name)
    refute_includes helper_names, "RecordingStudioTrashable::CopyHelper"
    refute defined?(RecordingStudioTrashable::CopyHelper),
           "query-only boot must not load RecordingStudioTrashable::CopyHelper"

    trash_metric_names =
      if RecordingStudioMetrics.respond_to?(:definitions)
        RecordingStudioMetrics.definitions.map { |definition| "#{definition.resource}.#{definition.name}" }
                              .select { |name| name.start_with?("trash.") }
      elsif RecordingStudioMetrics.respond_to?(:find)
        Array(RecordingStudioMetrics.find("trash.in_trash") || RecordingStudioMetrics.find(:trash, :in_trash)).compact
      else
        []
      end
    assert_empty trash_metric_names, "trash.* metrics must not register (got #{trash_metric_names.inspect})"

    # Query helpers are intentional; capability RecordingMethods must not load.
    assert RecordingStudio::Recording.respond_to?(:recording_studio_trashable_kept_sql)
    assert_includes RecordingStudio::Recording.included_modules, RecordingStudioTrashable::RecordingScopes
    instance_methods = RecordingStudio::Recording.instance_methods.grep(/trashable/).sort
    refute_includes instance_methods, :recording_studio_trashable_trash!
    refute_includes instance_methods, :recording_studio_trashable_restore!
    refute_includes instance_methods, :recording_studio_trashable_purge!
    refute_includes instance_methods, :recording_studio_trashable_validate_purge!

    get root_path
    assert_response :success
    body = response.body
    refute_includes body, "controllers/recording_studio_trashable/"
    refute_match(%r{rel="modulepreload"[^>]+recording_studio_trashable/}, body)

    importmap_json = Rails.application.importmap.to_json(resolver: ActionController::Base.helpers)
    refute_includes importmap_json, "trashable"
  end
end
