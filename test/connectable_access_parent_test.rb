# frozen_string_literal: true

require "test_helper"

class ConnectableAccessParentTest < Minitest::Test
  AccessRecording = Struct.new(:parent_recording)
  Parent = Struct.new(:recordable_type, :parent_recording_id)
  Client = Struct.new(:api_key)

  def test_workspace_parent_is_connectable_for_public_and_operations
    access = AccessRecording.new(Parent.new("Workspace"))

    assert RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("public"))
    assert RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("operations"))
  end

  def test_parentless_message_group_is_not_connectable
    access = AccessRecording.new(Parent.new("MessageGroup"))

    refute RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("public"))
    refute RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("operations"))
  end

  def test_parentless_namespaced_message_group_is_not_connectable
    access = AccessRecording.new(Parent.new("RecordingStudioMessages::MessageGroup"))

    refute RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("public"))
    refute RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("operations"))
  end

  def test_nested_message_group_parent_is_not_connectable
    access = AccessRecording.new(Parent.new("MessageGroup", "workspace-root-id"))

    refute RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("public"))
    refute RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("operations"))
  end

  def test_nested_folder_parent_is_not_connectable
    access = AccessRecording.new(Parent.new("Folder", "workspace-root-id"))

    refute RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("public"))
    refute RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("operations"))
  end

  def test_parentless_folder_is_not_connectable_by_default
    access = AccessRecording.new(Parent.new("Folder"))

    refute RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("public"))
    refute RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("operations"))
  end

  def test_host_can_allowlist_another_root_type
    previous = RecordingStudioOauth.configuration.connectable_root_recordable_type_names
    RecordingStudioOauth.configuration.connectable_root_recordable_type_names = %w[Workspace PressCenter]
    access = AccessRecording.new(Parent.new("PressCenter"))

    assert RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("public"))
    assert RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: Client.new("operations"))
  ensure
    RecordingStudioOauth.configuration.connectable_root_recordable_type_names = previous
  end

  def test_admin_root_is_connectable_only_for_operations_clients
    access = AccessRecording.new(Parent.new("AdminRoot"))
    public_client = Client.new("public")
    operations_client = Client.new("operations")

    refute RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: public_client)
    refute RecordingStudioOauth::Integration.connectable_access_parent?(access)
    assert RecordingStudioOauth::Integration.connectable_access_parent?(access, oauth_client: operations_client)
  end

  def test_human_api_name_and_operations_client
    assert_equal "Public", RecordingStudioOauth::Integration.human_api_name("public")
    assert_equal "Operations", RecordingStudioOauth::Integration.human_api_name("operations")
    assert RecordingStudioOauth::Integration.operations_client?(Client.new("operations"))
    refute RecordingStudioOauth::Integration.operations_client?(Client.new("public"))
    refute RecordingStudioOauth::Integration.operations_client?(nil)
  end
end
