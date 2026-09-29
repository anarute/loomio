require 'test_helper'

class IdentityServiceTest < ActiveSupport::TestCase
  setup do
    @identity_params = {
      identity_type: 'oauth',
      uid: 'oauth_user_123',
      email: 'oauthuser@example.com',
      name: 'OAuth User',
      access_token: 'token_123'
    }
  end

  test "uses the exact provider username for a new account" do
    identity = IdentityService.link_or_create(identity_params: @identity_params.merge(username: 'sso_person-one'), current_user: nil)
    assert_equal 'sso_person-one', identity.user.reload.username
    assert_equal 'sso_person-one', identity.reload.username
  end

  test "replaces an invitation username on first and subsequent SSO logins" do
    UserInviter.send(:users_insert_all, emails: [@identity_params[:email]], actor: users(:member_loud))
    user = User.find_by!(email: @identity_params[:email])
    assert_match(/oauthuser[a-z0-9]{12}/, user.username)

    IdentityService.stub(:update_user_profile_on_login?, false) do
      ['sso_person', 'sso_person_new'].each do |username|
        identity = IdentityService.link_or_create(identity_params: @identity_params.merge(username: username), current_user: nil)
        assert_equal user.id, identity.user_id
        assert_equal username, user.reload.username
      end
    end
  end

  test "missing provider username preserves an existing handle" do
    user = User.create!(email: @identity_params[:email], name: 'Existing', username: 'existing_handle')
    IdentityService.link_or_create(identity_params: @identity_params, current_user: nil)
    assert_equal 'existing_handle', user.reload.username
  end

  test "a later login without a username does not reapply a stale provider handle" do
    identity = IdentityService.link_or_create(identity_params: @identity_params.merge(username: 'provider_handle'), current_user: nil)
    identity.user.update!(username: 'local_handle')
    IdentityService.link_or_create(identity_params: @identity_params, current_user: nil)
    assert_equal 'local_handle', identity.user.reload.username
    assert_nil identity.reload.username
  end

  test "username collisions do not link another account or partially verify an invitation" do
    owner = users(:member_loud)
    invited = User.create!(email: @identity_params[:email], username: 'invited_handle')
    assert_no_difference ['Identity.count', 'User.count'] do
      assert_raises(ActiveRecord::RecordInvalid) do
        IdentityService.link_or_create(identity_params: @identity_params.merge(username: owner.username), current_user: nil)
      end
    end
    assert_equal 'invited_handle', invited.reload.username
    assert_not invited.email_verified?
    assert_nil invited.name
    assert_equal owner.username, owner.reload.username
  end

  test "invalid provider usernames are rejected without alteration or partial accounts" do
    ['MixedCase', 'has space', 'a' * 31].each do |username|
      assert_no_difference ['Identity.count', 'User.count'] do
        assert_raises(ActiveRecord::RecordInvalid) do
          IdentityService.link_or_create(identity_params: @identity_params.merge(username: username), current_user: nil)
        end
      end
    end
  end

  test "rejected returning username rolls back provider email and identity changes" do
    identity = IdentityService.link_or_create(identity_params: @identity_params.merge(username: 'original_handle'), current_user: nil)
    IdentityService.stub(:update_user_profile_on_login?, true) do
      assert_raises(ActiveRecord::RecordInvalid) do
        IdentityService.link_or_create(identity_params: @identity_params.merge(username: users(:member_loud).username, email: 'changed@example.com'), current_user: nil)
      end
    end
    assert_equal @identity_params[:email], identity.reload.email
    assert_equal @identity_params[:email], identity.user.reload.email
    assert_equal 'original_handle', identity.user.username
  end

  test "signed in account is unchanged until pending identity is explicitly linked" do
    user = users(:member_loud)
    original = user.username
    identity = IdentityService.link_or_create(identity_params: @identity_params.merge(username: 'pending_handle'), current_user: user)
    assert_nil identity.user_id
    assert_equal original, user.reload.username
    assert identity.link_to_user!(user)
    assert_equal 'pending_handle', user.reload.username
  end

  test "creates new identity and new user when no user exists" do
    identity = IdentityService.link_or_create(
      identity_params: @identity_params,
      current_user: nil
    )

    assert_equal 'oauth_user_123', identity.uid
    assert_equal 'oauthuser@example.com', identity.email
    assert_not_nil identity.user
    assert_equal 'oauthuser@example.com', identity.user.email
    assert_equal 'OAuth User', identity.user.name
    assert_equal true, identity.user.email_verified
  end

  test "links identity to existing verified user" do
    existing_user = User.create!(
      email: 'existing@example.com',
      name: 'Existing User',
      email_verified: true,
      username: 'existinguser'
    )

    identity_params = @identity_params.merge(email: 'existing@example.com')

    identity = IdentityService.link_or_create(
      identity_params: identity_params,
      current_user: nil
    )

    assert_equal existing_user, identity.user
    assert_equal true, existing_user.reload.email_verified
    assert_equal 1, existing_user.identities.count
  end

  test "links identity to unverified user and marks email verified" do
    unverified_user = User.create!(
      email: 'unverified@example.com',
      name: 'Unverified User',
      email_verified: false,
      username: 'unverifieduser'
    )

    identity_params = @identity_params.merge(email: 'unverified@example.com')

    identity = IdentityService.link_or_create(
      identity_params: identity_params,
      current_user: nil
    )

    assert_equal unverified_user, identity.user
    assert_equal true, unverified_user.reload.email_verified
  end

  test "initializes an invited user's name from the identity before verifying them" do
    invited_user = User.create!(
      email: "invited@example.com",
      email_verified: false,
      username: "inviteduser"
    )

    identity = IdentityService.link_or_create(
      identity_params: @identity_params.merge(email: invited_user.email),
      current_user: nil
    )

    assert_equal invited_user, identity.user
    assert_equal "OAuth User", invited_user.reload.name
    assert_predicate invited_user, :email_verified?
  end

  test "repairs a nameless user from their existing identity" do
    user = User.create!(email: "existing@example.com", email_verified: true)
    Identity.create!(
      user: user,
      uid: @identity_params[:uid],
      identity_type: @identity_params[:identity_type],
      email: user.email,
      name: "Original identity name"
    )

    IdentityService.link_or_create(
      identity_params: @identity_params.merge(email: user.email),
      current_user: nil
    )

    assert_equal "OAuth User", user.reload.name
  end

  test "creates an incomplete account when the provider supplies no name" do
    identity = nil
    assert_difference ["Identity.count", "User.count"], 1 do
      identity = IdentityService.link_or_create(
        identity_params: @identity_params.except(:name),
        current_user: nil
      )
    end

    assert_nil identity.user.name
    assert_predicate identity.user, :incomplete?
  end

  test "retains an existing user's name when the provider supplies no name" do
    user = User.create!(
      email: @identity_params[:email],
      name: "Existing User",
      email_verified: true
    )

    assert_difference "Identity.count", 1 do
      assert_no_difference "User.count" do
        IdentityService.link_or_create(
          identity_params: @identity_params.except(:name),
          current_user: nil
        )
      end
    end

    assert_equal "Existing User", user.reload.name
  end

  test "creates pending identity when user already signed in" do
    current_user = users(:user)

    identity = IdentityService.link_or_create(
      identity_params: @identity_params,
      current_user: current_user
    )

    assert_nil identity.user_id  # Pending, not linked
    assert_equal 'oauthuser@example.com', identity.email
    assert_equal 0, current_user.identities.count  # Not linked to current user
  end

  test "returns existing identity if it exists" do
    user = users(:user)
    existing_identity = Identity.create!(
      user: user,
      uid: 'oauth_user_123',
      identity_type: 'oauth',
      email: 'oauthuser@example.com',
      name: 'OAuth User'
    )

    identity = IdentityService.link_or_create(
      identity_params: @identity_params,
      current_user: nil
    )

    assert_equal existing_identity.id, identity.id
    assert_equal user, identity.user
  end

  test "returns identity created by a competing login" do
    user = users(:user)
    existing_identity = Identity.create!(
      user: user,
      uid: 'oauth_user_123',
      identity_type: 'oauth',
      email: 'oauthuser@example.com',
      name: 'Original Name',
      access_token: 'old_token'
    )

    assert_no_difference ['Identity.count', 'User.count'] do
      IdentityService.stub :find_identity, nil do
        identity = IdentityService.link_or_create(
          identity_params: @identity_params,
          current_user: nil
        )

        assert_equal existing_identity.id, identity.id
        assert_equal user, identity.user
        assert_equal 'OAuth User', identity.name
        assert_equal 'token_123', identity.access_token
      end
    end
  end
end
