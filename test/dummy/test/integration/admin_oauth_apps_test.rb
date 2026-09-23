# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminOauthAppsTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    @user = create_user
    create_access_recording_for(user: @user)
    _admin_root, @admin_root_recording = create_admin_root_recording
    grant_or_bootstrap_access!(recording: @admin_root_recording, actor: @user, role: :admin)
    RecordingStudioOauth::OauthClient.find_or_create_by!(name: "Seed Demo App") do |client|
      client.redirect_uris = ["http://127.0.0.1/callback"]
      client.confidential = false
      client.api_key = "public"
    end
    sign_in @user
    switch_to_root!(@admin_root_recording)
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "staff admin shows registered apps after switching to Admin" do
    get "/admin"

    assert_response :success
    assert_includes response.body, "Admin"
    assert_includes response.body, "Registered apps"
    assert_includes response.body, "Active connections"
  end

  test "staff admin registered apps screen lists the client" do
    get "/admin/screens/oauth_clients"

    assert_response :success
    assert_includes response.body, "Registered apps"
    assert_includes response.body, "New app"
    assert_includes response.body, "/recording_studio_oauth/admin/oauth_clients/new"

    get "/admin/screens/oauth_clients/table", params: { anchor_url: "http://www.example.com/admin/screens/oauth_clients" }

    assert_response :success
    assert_includes response.body, "Seed Demo App"
    assert_includes response.body, "Public"
    assert_includes response.body, "Active"
    assert_includes response.body, "Revoke"
    refute_match(/rsoauth_cs_/, response.body)

    public_tooltip = css_select('[data-controller="flat-pack--tooltip"]').find do |element|
      element.at_css('[role="tooltip"]')&.text == "Cannot hide a password. No secret. Uses PKCE."
    end

    assert public_tooltip, "expected a Public secret tooltip"
    assert_includes public_tooltip.text, "Public"
    assert_includes public_tooltip.at_css("span")["class"], "badge-default-background-color"

    active_badge = css_select("span").find do |element|
      element["class"].to_s.include?("badge-success-background-color") && element.text.strip == "Active"
    end
    assert active_badge, "expected an Active status badge"
  end

  test "staff can open the new app form" do
    get "/recording_studio_oauth/admin/oauth_clients/new"

    assert_response :success
    assert_includes response.body, "New app"
    assert_includes response.body, "Name"
    assert_includes response.body, "Redirect URLs"
    assert_includes response.body, "Secret"
    assert_includes response.body, "Create app"
    assert_includes response.body, "Use central relay"
    assert_includes response.body, "Allow registration"
    assert_includes response.body, "This app decides whether people can sign up."
    assert_includes response.body, "When this is on, Connect uses the fixed callback on this host."
    assert_includes response.body, "Allowed return patterns"
    assert_includes response.body, "Exact return URLs"
    rules = css_select("#central_relay_rules").first
    assert rules["hidden"], "return rules stay hidden until Use central relay is on"
    refute_includes response.body, "max-w-sm"
  end

  test "staff can create a public app and see the client id once without a secret" do
    assert_difference -> { RecordingStudioOauth::OauthClient.count }, 1 do
      post "/recording_studio_oauth/admin/oauth_clients", params: {
        oauth_client: {
          name: "Staff Public App",
          redirect_uris: "http://127.0.0.1/callback",
          secret: "public"
        }
      }
    end

    client = RecordingStudioOauth::OauthClient.find_by!(name: "Staff Public App")
    assert_redirected_to "/recording_studio_oauth/admin/oauth_clients/#{client.id}"
    follow_redirect!

    assert_response :success
    assert_includes response.body, "App credentials"
    assert_includes response.body, client.client_id
    assert_includes response.body, "This app has no secret."
    refute_match(/rsoauth_cs_/, response.body)
    refute client.confidential?
    assert_nil client.client_secret_digest

    get "/admin/screens/oauth_clients/table", params: { anchor_url: "http://www.example.com/admin/screens/oauth_clients" }

    assert_response :success
    assert_includes response.body, "Staff Public App"
    assert_includes response.body, "Public"
    refute_includes response.body, client.client_id
    refute_match(/rsoauth_cs_/, response.body)

    public_tooltip = css_select('[data-controller="flat-pack--tooltip"]').find do |element|
      element.at_css('[role="tooltip"]')&.text == "Cannot hide a password. No secret. Uses PKCE."
    end

    assert public_tooltip, "expected a Public secret tooltip on the created app"
    assert_includes public_tooltip.at_css("span")["class"], "badge-default-background-color"
  end

  test "staff can create a confidential app and see the secret only once" do
    assert_difference -> { RecordingStudioOauth::OauthClient.count }, 1 do
      post "/recording_studio_oauth/admin/oauth_clients", params: {
        oauth_client: {
          name: "Staff Secret App",
          redirect_uris: "https://example.com/callback\n",
          secret: "has_secret"
        }
      }
    end

    client = RecordingStudioOauth::OauthClient.find_by!(name: "Staff Secret App")
    follow_redirect!

    assert_response :success
    assert_includes response.body, client.client_id
    secret = response.body[/\brsoauth_cs_[A-Za-z0-9_-]+\b/]
    assert_predicate secret, :present?
    assert client.confidential?
    assert client.authenticate_secret?(secret)

    get "/recording_studio_oauth/admin/oauth_clients/#{client.id}"

    assert_response :success
    assert_includes response.body, client.client_id
    refute_includes response.body, secret
    assert_includes response.body, "The secret was shown once."

    get "/admin/screens/oauth_clients/table", params: { anchor_url: "http://www.example.com/admin/screens/oauth_clients" }

    assert_response :success
    assert_includes response.body, "Staff Secret App"
    assert_includes response.body, "Has a secret"
    refute_includes response.body, secret

    secret_tooltip = css_select('[data-controller="flat-pack--tooltip"]').find do |element|
      element.at_css('[role="tooltip"]')&.text == "Lives on a server. Proves itself with a secret."
    end

    assert secret_tooltip, "expected a Has a secret tooltip"
    assert_includes secret_tooltip.text, "Has a secret"
    assert_includes secret_tooltip.at_css("span")["class"], "badge-info-background-color"
  end

  test "staff create rejects a redirect URL with a fragment" do
    assert_no_difference -> { RecordingStudioOauth::OauthClient.count } do
      post "/recording_studio_oauth/admin/oauth_clients", params: {
        oauth_client: {
          name: "Bad Redirect App",
          redirect_uris: "https://example.com/callback#fragment",
          secret: "public"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "New app"
  end

  test "staff can still revoke a registered app" do
    client = RecordingStudioOauth::OauthClient.find_by!(name: "Seed Demo App")

    post "/recording_studio_oauth/admin/oauth_clients/#{client.id}/revoke"

    assert_response :redirect
    assert_predicate client.reload, :revoked?

    get "/admin/screens/oauth_clients/table", params: { anchor_url: "http://www.example.com/admin/screens/oauth_clients" }

    assert_response :success
    row = css_select("tr, [role='row']").find { |element| element.text.include?("Seed Demo App") }
    assert row, "expected Seed Demo App in the registered apps table"
    revoked_badge = row.css("span").find do |element|
      element["class"].to_s.include?("badge-danger-background-color") && element.text.strip == "Revoked"
    end
    assert revoked_badge, "expected Seed Demo App to show a Revoked status badge"
    refute row.css("span").any? { |element|
      element["class"].to_s.include?("badge-success-background-color") && element.text.strip == "Active"
    }
    assert row.css('[role="tooltip"]').any? { |element|
      element.text == "Cannot hide a password. No secret. Uses PKCE."
    }
  end

  test "staff can save central relay rules and edit them later" do
    pattern = "https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
    exact = "https://shop.example.com/oauth/done"

    post "/recording_studio_oauth/admin/oauth_clients", params: {
      oauth_client: {
        name: "Relay Staff App",
        redirect_uris: "http://www.example.com/recording_studio_oauth/callback",
        secret: "public",
        use_central_relay: "1",
        allowed_return_patterns: pattern,
        exact_return_urls: exact
      }
    }

    client = RecordingStudioOauth::OauthClient.find_by!(name: "Relay Staff App")
    assert_redirected_to "/recording_studio_oauth/admin/oauth_clients/#{client.id}"
    assert client.use_central_relay?
    assert_equal [pattern], client.allowed_return_patterns
    assert_equal [exact], client.exact_return_urls

    follow_redirect!
    assert_includes response.body, "Edit app"

    get "/recording_studio_oauth/admin/oauth_clients/#{client.id}/edit"
    assert_response :success
    assert_includes response.body, "Allowed return patterns"
    rules = css_select("#central_relay_rules").first
    assert_nil rules["hidden"]

    patch "/recording_studio_oauth/admin/oauth_clients/#{client.id}", params: {
      oauth_client: {
        name: "Relay Staff App",
        redirect_uris: "http://www.example.com/recording_studio_oauth/callback",
        use_central_relay: "0",
        allowed_return_patterns: pattern,
        exact_return_urls: exact
      }
    }

    assert_redirected_to "/recording_studio_oauth/admin/oauth_clients/#{client.id}"
    client.reload
    refute client.use_central_relay?
    assert_equal [pattern], client.allowed_return_patterns
  end

  test "central relay on requires a return pattern or an exact URL" do
    assert_no_difference -> { RecordingStudioOauth::OauthClient.count } do
      post "/recording_studio_oauth/admin/oauth_clients", params: {
        oauth_client: {
          name: "Empty Relay",
          redirect_uris: "http://127.0.0.1/callback",
          secret: "public",
          use_central_relay: "1",
          allowed_return_patterns: "",
          exact_return_urls: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "needs a return pattern or an exact URL"
  end

  test "staff registered apps table links to edit" do
    get "/admin/screens/oauth_clients/table", params: { anchor_url: "http://www.example.com/admin/screens/oauth_clients" }

    assert_response :success
    assert_includes response.body, "Edit"
  end

  test "submit sits on its own row under use central relay" do
    get "/recording_studio_oauth/admin/oauth_clients/new"

    assert_response :success
    assert_submit_on_its_own_row("Create app")

    client = RecordingStudioOauth::OauthClient.find_by!(name: "Seed Demo App")
    get "/recording_studio_oauth/admin/oauth_clients/#{client.id}/edit"

    assert_response :success
    assert_submit_on_its_own_row("Save")
  end

  test "allow registration stacks above use central relay" do
    get "/recording_studio_oauth/admin/oauth_clients/new"

    assert_response :success
    assert_registration_stacks_above_central_relay

    client = RecordingStudioOauth::OauthClient.find_by!(name: "Seed Demo App")
    get "/recording_studio_oauth/admin/oauth_clients/#{client.id}/edit"

    assert_response :success
    assert_registration_stacks_above_central_relay
  end

  test "exact return urls uses the same stack gap as the rest of the form" do
    get "/recording_studio_oauth/admin/oauth_clients/new"

    assert_response :success
    assert_exact_return_urls_share_the_form_stack

    client = RecordingStudioOauth::OauthClient.find_by!(name: "Seed Demo App")
    get "/recording_studio_oauth/admin/oauth_clients/#{client.id}/edit"

    assert_response :success
    assert_exact_return_urls_share_the_form_stack
  end

  test "a new app starts from the initializer and the list has no site registration control" do
    previous = RecordingStudioOauth.configuration.allow_registration?
    RecordingStudioOauth.configuration.allow_registration = true

    get "/admin/screens/oauth_clients"

    assert_response :success
    assert_includes response.body, "Registered apps"
    assert_includes response.body, "New app"
    refute_includes response.body, "/recording_studio_oauth/admin/registration_setting"
    refute_includes response.body, "Allow registration"

    get "/recording_studio_oauth/admin/registration_setting"

    assert_response :not_found

    get "/recording_studio_oauth/admin/oauth_clients/new"

    checkbox = css_select("input[name='oauth_client[allow_registration]'][type=checkbox]").first
    assert_equal "checked", checkbox["checked"]

    post "/recording_studio_oauth/admin/oauth_clients", params: {
      oauth_client: {
        name: "Opt Out App",
        redirect_uris: "https://example.com/callback",
        secret: "public",
        allow_registration: "0"
      }
    }

    client = RecordingStudioOauth::OauthClient.find_by!(name: "Opt Out App")
    refute client.allow_registration?

    patch "/recording_studio_oauth/admin/oauth_clients/#{client.id}", params: {
      oauth_client: {
        name: "Opt Out App",
        redirect_uris: "https://example.com/callback",
        allow_registration: "1"
      }
    }

    assert client.reload.allow_registration?

    RecordingStudioOauth.configuration.allow_registration = false
    assert client.reload.allow_registration?
    assert RecordingStudioOauth.configuration.allow_registration? == false
  ensure
    RecordingStudioOauth.configuration.allow_registration = previous
  end

  test "create is forbidden without admin access" do
    outsider = create_user
    create_access_recording_for(user: outsider)
    sign_in outsider

    get "/recording_studio_oauth/admin/oauth_clients/new"

    assert_response :forbidden

    assert_no_difference -> { RecordingStudioOauth::OauthClient.count } do
      post "/recording_studio_oauth/admin/oauth_clients", params: {
        oauth_client: {
          name: "Blocked App",
          redirect_uris: "http://127.0.0.1/callback",
          secret: "public"
        }
      }
    end

    assert_response :forbidden
  end

  private

  def assert_submit_on_its_own_row(label)
    form = css_select("form").first
    button = form.at_css("button[type=submit]")
    rules = form.at_css("#central_relay_rules")

    assert_equal label, button.text.strip
    assert_equal "div", button.parent.name
    assert_equal rules, button.parent.previous_element
    parent_class = button.parent["class"].to_s
    refute_match(/inline|flex/, parent_class)
  end

  def assert_registration_stacks_above_central_relay
    form = css_select("form").first
    allow_row = form_row_for(form, "input[name='oauth_client[allow_registration]'][type=checkbox]")
    relay_row = form_row_for(form, "input[name='oauth_client[use_central_relay]'][type=checkbox]")

    assert_equal "div", allow_row.name
    assert_equal "div", relay_row.name
    refute_equal allow_row, relay_row
    assert_equal relay_row, allow_row.next_element
    assert_includes form["class"].to_s.split, "space-y-6"
    refute_includes allow_row["class"].to_s.split, "inline-flex"
    refute_includes relay_row["class"].to_s.split, "inline-flex"
  end

  def form_row_for(form, selector)
    node = form.at_css(selector)
    node = node.parent until node.parent == form
    node
  end

  def assert_exact_return_urls_share_the_form_stack
    form = css_select("form").first
    rules = form.at_css("#central_relay_rules")
    stack = form["class"].to_s.split

    assert_includes stack, "space-y-6"
    assert_includes rules["class"].to_s.split, "space-y-6"

    wrappers = rules.element_children.select { |child| child["class"].to_s.include?("flat-pack-input-wrapper") }

    assert_equal ["Allowed return patterns", "Exact return URLs"], wrappers.map { |wrapper| wrapper.at_css("label").text.strip }
  end
end
