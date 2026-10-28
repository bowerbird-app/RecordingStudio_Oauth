# frozen_string_literal: true

require "test_helper"

class IntegrationAccessRecordingsTest < Minitest::Test
  Recording = Struct.new(:id, :created_at, keyword_init: true)

  def test_actor_access_recordings_returns_empty_without_actor
    assert_empty RecordingStudioOauth::Integration.actor_access_recordings(actor: nil)
  end

  def test_actor_access_recordings_composes_accessible_lookups
    actor = Object.new
    first_root = Object.new
    second_root = Object.new
    older = Recording.new(id: "a", created_at: Time.utc(2026, 1, 1))
    newer = Recording.new(id: "b", created_at: Time.utc(2026, 2, 1))
    duplicate = Recording.new(id: "a", created_at: Time.utc(2026, 1, 1))
    seen_roots = []

    passed_actor = nil
    RecordingStudioAccessible.stub(:root_recordings_for, lambda { |actor:|
      passed_actor = actor
      [first_root, second_root]
    }) do
      RecordingStudioAccessible.stub(:access_recordings_for_actor, lambda { |recording:, **|
        seen_roots << recording
        recording.equal?(first_root) ? [older, newer] : [duplicate]
      }) do
        result = RecordingStudioOauth::Integration.actor_access_recordings(actor: actor)

        assert_same actor, passed_actor
        assert_equal [first_root, second_root], seen_roots
        assert_equal %w[a b], result.map(&:id)
      end
    end
  end

  def test_actor_access_recordings_is_empty_without_roots
    RecordingStudioAccessible.stub(:root_recordings_for, []) do
      assert_empty RecordingStudioOauth::Integration.actor_access_recordings(actor: Object.new)
    end
  end
end
