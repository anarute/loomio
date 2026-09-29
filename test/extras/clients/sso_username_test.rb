require 'test_helper'

class SsoUsernameTest < ActiveSupport::TestCase
  test 'OAuth uses preferred_username by default' do
    previous = ENV.delete('OAUTH_ATTR_USERNAME')
    url_previous = ENV['OAUTH_PROFILE_URL']
    ENV['OAUTH_PROFILE_URL'] = 'https://provider.example/profile'
    client = Clients::Oauth.new(key: 'client', secret: 'secret', token: 'token')
    client.stub(:get, OpenStruct.new(json: { 'sub' => 'opaque-id', 'preferred_username' => 'person_one' })) do
      assert_equal 'person_one', client.fetch_identity_params[:username]
    end
  ensure
    previous.nil? ? ENV.delete('OAUTH_ATTR_USERNAME') : ENV['OAUTH_ATTR_USERNAME'] = previous
    url_previous.nil? ? ENV.delete('OAUTH_PROFILE_URL') : ENV['OAUTH_PROFILE_URL'] = url_previous
  end

  test 'Nextcloud maps its account ID to the username' do
    client = Clients::Nextcloud.new(key: 'client', secret: 'secret', token: 'token')
    client.stub(:get, OpenStruct.new(json: { 'ocs' => { 'data' => { 'id' => 'person_one' } } })) do
      assert_equal 'person_one', client.fetch_identity_params[:username]
    end
  end
end
