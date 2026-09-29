# Preserve usernames from single sign-on

People signing in through OAuth, SAML, or Nextcloud now keep the username supplied by their provider. This also replaces a generated invitation username on their next SSO login. Providers that supply no username keep the existing behavior.

OAuth uses `preferred_username` by default, with an `OAUTH_ATTR_USERNAME` override. SAML supports common username attributes and a `SAML_ATTR_USERNAME` override. Nextcloud uses its account ID. Username synchronization applies on every SSO login, independently of the optional name and email synchronization settings.

Provider usernames must meet Loomio's username requirements and must not belong to another account. A conflict stops sign-in instead of adding a random suffix or linking accounts by username. See [SSO profile settings](/en/user_manual/integrations/api/server-api#sso-profile-sync-settings) for configuration details.
