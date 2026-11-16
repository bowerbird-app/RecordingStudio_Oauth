# frozen_string_literal: true

require "test_helper"
require "action_controller/metal/strong_parameters"

class HookSecretRedactionTest < Minitest::Test
  REDACTED = %w[
    AuthenticateOauthClient
    CreateOauthAuthorization
    CreateOauthClient
    DisconnectOutboundConnection
    FinishCentralRelay
    FinishOutboundConnect
    IssueDelegatedAccessToken
    LookupOutboundConnection
    PrepareOauthAuthorize
    RecordExternalInstall
    RefreshOutboundConnection
    RegisterOauthClient
    ResolveOauthClient
    StartCentralRelay
    StartOutboundConnect
    UpdateOauthClient
    VerifySessionToken
    LookupInboundConnection
    VoidOauthAuthorization
  ].freeze
  SECRET = "dummy-client-secret"
  CODE = "dummy-auth-code-value"
  STATE = "dummy-state-value"
  REFRESH = "dummy-refresh-token-value"

  Note = Struct.new(:code, :kept)
  Card = Data.define(:refresh_token, :kept)

  class Probe < RecordingStudio::Services::BaseService
    include RecordingStudioOauth::Services::RedactsHookSecrets

    def initialize(payload, fail: false)
      @payload = payload
      @fail = fail
      @client_secret = SECRET
    end

    private

    def perform
      return failure({ token: SECRET }, errors: [@payload]) if @fail

      success(@payload)
    end
  end

  def setup
    @hooks = RecordingStudio.configuration.hooks
    @hooks.clear(:after_service)
    @hooks.clear(:around_service)
  end

  def teardown
    @hooks.clear(:after_service)
    @hooks.clear(:around_service)
  end

  def test_only_secret_services_hide_hook_secrets
    classes = RecordingStudioOauth::Services.constants.filter_map do |name|
      constant = RecordingStudioOauth::Services.const_get(name)
      next unless constant.is_a?(Class)
      next unless constant < RecordingStudio::Services::BaseService

      constant
    end
    redacted, plain = classes.partition do |klass|
      klass.included_modules.include?(RecordingStudioOauth::Services::RedactsHookSecrets)
    end

    assert_equal 19, classes.size
    assert_empty plain
    assert_equal REDACTED.sort, redacted.map { |klass| klass.name.split("::").last }.sort
  end

  def test_nested_values_are_hidden_and_the_caller_keeps_them
    payload = secret_payload
    result, payloads, subjects = capture { Probe.call(payload) }

    assert result.success?
    assert_equal SECRET, result.value[:token]
    assert_equal CODE, result.value[:nested][0]["code"]
    assert_equal STATE, result.value[:nested][1].code
    assert_equal SECRET, result.value[:params]["client_secret"]
    refute result.value[:params].permitted?
    assert_hidden(payloads, subjects, Probe, [SECRET, CODE, STATE, REFRESH])
    view = hook_value(payloads)
    assert_nil view[:token]
    assert_equal "dummy-client-id", view[:client_id]
    assert_equal "keep-note", view[:nested][1][:kept]
    assert_nil view[:nested][1][:code]
    assert_nil view[:nested][2][:refresh_token]
    assert_equal "keep-card", view[:nested][2][:kept]
    assert_includes view[:note], "[FILTERED]"
    refute_includes view[:note], SECRET
    assert_nil view[:params]["client_secret"]
    assert_equal "dummy-code-challenge", view[:params]["code_challenge"]
    subjects.each { |subject| refute subject.instance_variable_defined?(:@client_secret) }
  end

  def test_a_failed_call_hides_the_same_values
    payload = secret_payload
    result, payloads, subjects = capture { Probe.call(payload, fail: true) }

    assert result.failure?
    assert_equal SECRET, result.error[:token]
    assert_equal CODE, result.errors.first[:nested][0]["code"]
    assert_hidden(payloads, subjects, Probe, [SECRET, CODE, STATE, REFRESH])
  end

  private

  def secret_payload
    {
      token: SECRET,
      nested: [
        { "code" => CODE },
        Note.new(STATE, "keep-note"),
        Card.new(refresh_token: REFRESH, kept: "keep-card")
      ],
      note: "https://app.example/cb?code=#{SECRET}",
      client_id: "dummy-client-id",
      params: ActionController::Parameters.new(
        "client_id" => "dummy-client-id",
        "client_secret" => SECRET,
        "code_challenge" => "dummy-code-challenge"
      )
    }
  end

  def capture
    payloads = []
    subjects = []
    @hooks.after_service { |_service_class, result| payloads << result }
    @hooks.around_service do |subject, block|
      subjects << subject
      view = block.call
      payloads << view
      payloads << subject
      view
    end
    [yield, payloads, subjects]
  end

  def assert_hidden(payloads, subjects, klass, secrets)
    matched = subjects.select { |subject| subject.instance_of?(klass) }

    assert_predicate matched, :any?
    matched.each { |subject| assert subject.is_a?(klass) }
    text = hook_text(payloads)
    secrets.each { |secret| refute_includes text, secret }
  end

  def hook_value(payloads)
    payloads.each do |payload|
      next unless payload.is_a?(RecordingStudio::Services::BaseService::Result)
      next unless payload.value.is_a?(Hash)

      return payload.value
    end
    flunk "hook result was missing"
  end

  def hook_text(object)
    chunks = []
    walk(object) { |item| chunks << item if item.is_a?(String) }
    chunks.join("\n")
  end

  def walk(object, seen = {}.compare_by_identity, &block)
    return if object.nil? || seen[object]
    return if object.is_a?(Class) || object.is_a?(Module) || object.is_a?(Proc)

    seen[object] = true
    yield object
    case object
    when Hash
      object.each_value { |value| walk(value, seen, &block) }
    when Array
      object.each { |value| walk(value, seen, &block) }
    when RecordingStudio::Services::BaseService::Result
      walk(object.value, seen, &block)
      walk(object.error, seen, &block)
      walk(object.errors, seen, &block)
    when Struct
      walk(object.to_h, seen, &block)
    else
      walk(object.to_unsafe_h, seen, &block) if parameters?(object)
      walk(object.to_h, seen, &block) if object.is_a?(Data)
      return unless object.instance_variables.any?

      object.instance_variables.each do |name|
        walk(object.instance_variable_get(name), seen, &block)
      end
    end
  end

  def parameters?(object)
    defined?(ActionController::Parameters) && object.is_a?(ActionController::Parameters)
  end
end
