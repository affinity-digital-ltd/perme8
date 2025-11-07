# SendGrid Click Tracking Fix for Confirmation Emails

## Problem

Confirmation email links in production were being rewritten by SendGrid's click tracking feature to go through a tracking subdomain (e.g., `url3308.jarga.ai`), causing the links to fail with "invalid subdomain" errors.

**Example broken link:**
```
http://url3308.jarga.ai/ls/click?upn=u001.VfS4SfxWgitNTgnnT56YB9Z...
```

## Root Cause

SendGrid automatically enables click tracking by default, which:
1. Rewrites all URLs in emails to go through their tracking domain
2. Uses a randomly assigned subdomain like `url3308.jarga.ai`
3. These tracking subdomains are not automatically configured in your DNS
4. Results in broken links when users click them

## Solution Implemented ✅

**Disabled click tracking for authentication emails** by adding SendGrid-specific headers.

### Code Changes

**File:** `lib/jarga/accounts/user_notifier.ex`

Added tracking control:
```elixir
# Disables SendGrid click tracking for authentication emails
defp maybe_disable_tracking(email, opts) do
  if Keyword.get(opts, :disable_tracking, false) do
    email
    |> put_provider_option(:click_tracking, %{enable: false})
    |> put_provider_option(:open_tracking, %{enable: false})
  else
    email
  end
end
```

Applied to all authentication emails:
- ✅ Confirmation emails (`deliver_confirmation_instructions`)
- ✅ Magic link emails (`deliver_magic_link_instructions`)
- ✅ Email update instructions (`deliver_update_email_instructions`)

### Why This Solution?

**Security**: Authentication links should never be tracked
- Prevents leaking authentication tokens to third-party tracking services
- Avoids potential MITM attacks through tracking redirects
- Ensures links work reliably without DNS configuration

**Best Practice**: Many email services recommend disabling tracking for transactional/security emails

## Alternative Solutions (Not Implemented)

### Option 2: Configure Custom Tracking Domain in SendGrid

If you want to keep tracking for marketing emails:

1. **In SendGrid Dashboard:**
   - Go to Settings → Sender Authentication → Link Branding
   - Set up a custom subdomain (e.g., `track.jarga.ai`)
   - Follow DNS configuration instructions

2. **Add DNS Records:**
   ```
   CNAME: track.jarga.ai → sendgrid.net
   ```

3. **Pros:**
   - Keep tracking for analytics
   - Custom branded tracking domain

4. **Cons:**
   - Requires DNS configuration
   - Still exposes auth tokens to tracking
   - More maintenance overhead

### Option 3: Disable Click Tracking Globally

**In SendGrid Dashboard:**
- Settings → Tracking → Click Tracking → Disable

**Pros:**
- Simple one-time configuration
- Works for all emails

**Cons:**
- Loses tracking for ALL emails (including marketing)
- Can't selectively enable for non-auth emails

## Verification

### Local Testing

```bash
# Tests pass
mix test test/jarga/accounts_test.exs
mix test test/jarga_web/integration/user_signup_and_confirmation_test.exs
```

### Production Verification

1. **Trigger a confirmation email:**
   ```bash
   # In production console
   user = Jarga.Accounts.get_user_by_email("test@example.com")
   Jarga.Accounts.deliver_login_instructions(user, fn token ->
     "https://jarga.ai/users/log-in/#{token}"
   end)
   ```

2. **Check the email source:**
   - Open the email in your email client
   - View source/raw message
   - Verify the link is NOT rewritten
   - Should see: `https://jarga.ai/users/log-in/TOKEN`
   - Should NOT see: `http://url3308.jarga.ai/ls/click?...`

3. **Click the link:**
   - Should go directly to your domain
   - Should successfully confirm account

## SendGrid Headers Added

The implementation adds these provider-specific options to authentication emails:

```elixir
%{
  click_tracking: %{enable: false},  # Disables link rewriting
  open_tracking: %{enable: false}    # Disables open tracking pixel
}
```

## Impact

### Before Fix
- ❌ Confirmation links routed through `url3308.jarga.ai`
- ❌ Links failed with "invalid subdomain"
- ❌ Users couldn't confirm accounts
- ❌ Security risk from link tracking

### After Fix
- ✅ Confirmation links go directly to `jarga.ai`
- ✅ Links work immediately without DNS config
- ✅ Users can confirm accounts successfully
- ✅ Better security (no tracking of auth tokens)

## For Other Email Types

If you want to add tracking to marketing/non-auth emails:

```elixir
# In user_notifier.ex

def deliver_marketing_email(user, content) do
  deliver(
    user.email,
    "Marketing Subject",
    content,
    # Don't pass disable_tracking: true
    # Tracking will be enabled by default
    []
  )
end
```

## Environment Variables

Make sure these are set in production:

```bash
# SendGrid Configuration
SENDGRID_API_KEY=SG.xxxxxxxxxxxxx
SENDGRID_FROM_EMAIL=noreply@jarga.ai
SENDGRID_FROM_NAME=Jarga
```

## Related Files

- Implementation: `lib/jarga/accounts/user_notifier.ex:29-39`
- Configuration: `config/runtime.exs:144-149`
- Tests: `test/jarga/accounts_test.exs`, `test/jarga_web/integration/user_signup_and_confirmation_test.exs`

## Additional Resources

- [SendGrid Click Tracking Documentation](https://docs.sendgrid.com/ui/analytics-and-reporting/click-tracking)
- [SendGrid Link Branding](https://docs.sendgrid.com/ui/account-and-settings/how-to-set-up-link-branding)
- [Swoosh SendGrid Adapter](https://hexdocs.pm/swoosh/Swoosh.Adapters.Sendgrid.html)
