# frozen_string_literal: true

module RecordingStudioOauth
  module Integration
    DEFAULT_API_NAME = "public"
    OPERATIONS_API_NAME = "operations"

    module_function

    def actor_access_recordings(actor:)
      return [] if actor.nil?

      access_ids = RecordingStudio::Access.where(actor: actor).pluck(:id)
      return [] if access_ids.empty?

      RecordingStudio::Recording.unscoped
                                .where(recordable_type: "RecordingStudio::Access", recordable_id: access_ids, trashed_at: nil)
                                .order(:created_at, :id)
                                .to_a
    end

    def connect_access_recordings(actor:, oauth_client: nil)
      actor_access_recordings(actor: actor).select do |recording|
        connectable_access_parent?(recording, oauth_client: oauth_client)
      end
    end

    def resolve_access_recording_for_actor(actor:, requested_access_recording_id: nil, oauth_client: nil)
      candidates = connect_access_recordings(actor: actor, oauth_client: oauth_client)
      return { recording: nil, candidates: [], error: :no_access_recordings } if candidates.empty?

      requested_id = requested_access_recording_id.to_s.presence
      if requested_id.present?
        selected = candidates.find { |recording| recording.id == requested_id }
        return { recording: selected, candidates: candidates, error: nil } if selected.present?

        return { recording: nil, candidates: candidates, error: :invalid_access_recording }
      end

      return { recording: candidates.first, candidates: candidates, error: nil } if candidates.one?

      { recording: nil, candidates: candidates, error: :selection_required }
    end

    def connectable_access_parent?(access_recording, oauth_client: nil)
      parent = access_recording.parent_recording
      return false if parent.nil?
      return false if parent.recordable_type == "RecordingStudio::Access"
      return operations_client?(oauth_client) if admin_root_recordable_type?(parent.recordable_type)

      true
    end

    def admin_root_recordable_type?(recordable_type)
      Array(RecordingStudioOauth.configuration.admin_root_recordable_type_names).map(&:to_s).include?(recordable_type.to_s)
    end

    def operations_client?(oauth_client)
      oauth_client.respond_to?(:api_key) && oauth_client.api_key.to_s == OPERATIONS_API_NAME
    end

    def api_names
      return RecordingStudioApi.configuration.api_names if defined?(RecordingStudioApi) &&
                                                           RecordingStudioApi.respond_to?(:configuration) &&
                                                           RecordingStudioApi.configuration.respond_to?(:api_names)

      [DEFAULT_API_NAME]
    end

    def named_api_choices
      api_names.map { |name| [human_api_name(name), name] }
    end

    def human_api_name(name)
      key = name.to_s
      return "Public" if key == DEFAULT_API_NAME
      return "Operations" if key == OPERATIONS_API_NAME

      key.tr("_", " ").split.map(&:capitalize).join(" ")
    end

    def multiple_named_apis?
      api_names.size > 1
    end
  end
end
