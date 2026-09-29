require 'test_helper'

class SamlIdentityParamsTest < ActiveSupport::TestCase
  test 'maps common and configured SAML usernames without normalizing them' do
    previous = ENV.delete('SAML_ATTR_USERNAME')
    %w[username preferred_username uid urn:oid:0.9.2342.19200300.100.1.1].each do |attribute|
      response = OpenStruct.new(nameid: 'person@example.com', attributes: { attribute => ['Exact_Handle'] })
      assert_equal 'Exact_Handle', SamlIdentityParams.from_response(response)[:username]
    end
    ENV['SAML_ATTR_USERNAME'] = 'login'
    response = OpenStruct.new(nameid: 'person@example.com', attributes: { 'login' => ['custom_handle'], 'uid' => ['other'] })
    assert_equal 'custom_handle', SamlIdentityParams.from_response(response)[:username]
    response.attributes = { 'uid' => ['other'] }
    assert_nil SamlIdentityParams.from_response(response)[:username]
  ensure
    previous.nil? ? ENV.delete('SAML_ATTR_USERNAME') : ENV['SAML_ATTR_USERNAME'] = previous
  end

  test 'does not mistake a persistent name ID for a username' do
    response = OpenStruct.new(nameid: 'opaque-provider-id', attributes: {})
    assert_nil SamlIdentityParams.from_response(response)[:username]
  end
end
