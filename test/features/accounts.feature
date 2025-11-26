Feature: User Account Management
  As a user of the Jarga platform
  I want to register, authenticate, and manage my account
  So that I can securely access the application and maintain my profile

  # User Registration

  Scenario: User registers with valid credentials
    When I register with the following details:
      | Field       | Value                 |
      | email       | alice@example.com     |
      | password    | SecurePassword123!    |
      | first_name  | Alice                 |
      | last_name   | Smith                 |
    Then the registration should be successful
    And the user should have email "alice@example.com"
    And the user should have first name "Alice"
    And the user should have last name "Smith"
    And the user should have status "active"
    And the user should not be confirmed
    And the password should be hashed with bcrypt

  Scenario: User registers without required fields
    When I attempt to register with the following details:
      | Field       | Value                 |
      | email       | incomplete@example.com|
      | password    | SecurePassword123!    |
    Then the registration should fail
    And I should see validation errors for "first_name"
    And I should see validation errors for "last_name"

  Scenario: User registers with invalid email format
    When I attempt to register with the following details:
      | Field       | Value                 |
      | email       | invalid-email         |
      | password    | SecurePassword123!    |
      | first_name  | Bob                   |
      | last_name   | Jones                 |
    Then the registration should fail
    And I should see an email format validation error

  Scenario: User registers with short password
    When I attempt to register with the following details:
      | Field       | Value                 |
      | email       | bob@example.com       |
      | password    | short                 |
      | first_name  | Bob                   |
      | last_name   | Jones                 |
    Then the registration should fail
    And I should see a password length validation error

  Scenario: User registers with duplicate email
    Given a user exists with email "existing@example.com"
    When I attempt to register with the following details:
      | Field       | Value                 |
      | email       | existing@example.com  |
      | password    | SecurePassword123!    |
      | first_name  | Charlie               |
      | last_name   | Brown                 |
    Then the registration should fail
    And I should see a duplicate email error

  # Magic Link Authentication

  Scenario: Confirmed user logs in with magic link
    Given a confirmed user exists with email "alice@example.com"
    And a magic link token is generated for "alice@example.com"
    When I login with the magic link token
    Then the login should be successful
    And the magic link token should be deleted
    And no other tokens should be deleted

  Scenario: Unconfirmed user without password logs in with magic link
    Given an unconfirmed user exists with email "bob@example.com"
    And the user has no password set
    And a magic link token is generated for "bob@example.com"
    When I login with the magic link token
    Then the login should be successful
    And the user should be confirmed
    And all user tokens should be deleted for security
    And the confirmed_at timestamp should be set

  Scenario: Unconfirmed user with password logs in with magic link
    Given an unconfirmed user exists with email "charlie@example.com"
    And the user has a password set
    And a magic link token is generated for "charlie@example.com"
    When I login with the magic link token
    Then the login should be successful
    And the user should be confirmed
    And only the magic link token should be deleted
    And other session tokens should remain intact

  Scenario: User attempts login with invalid magic link token
    When I attempt to login with an invalid magic link token
    Then the login should fail with error "invalid_token"

  Scenario: User attempts login with expired magic link token
    Given a confirmed user exists with email "diana@example.com"
    And an expired magic link token exists for "diana@example.com"
    When I attempt to login with the expired token
    Then the login should fail with error "not_found"

  # Password-Based Authentication

  Scenario: Confirmed user logs in with email and password
    Given a confirmed user exists with email "alice@example.com" and password "SecurePassword123!"
    When I login with email "alice@example.com" and password "SecurePassword123!"
    Then the login should be successful
    And I should receive the user record

  Scenario: User logs in with correct password but unconfirmed email
    Given an unconfirmed user exists with email "bob@example.com" and password "SecurePassword123!"
    When I attempt to login with email "bob@example.com" and password "SecurePassword123!"
    Then the login should fail
    And I should not receive a user record

  Scenario: User logs in with incorrect password
    Given a confirmed user exists with email "alice@example.com" and password "CorrectPassword123!"
    When I attempt to login with email "alice@example.com" and password "WrongPassword123!"
    Then the login should fail
    And I should not receive a user record

  Scenario: User logs in with non-existent email
    When I attempt to login with email "nonexistent@example.com" and password "AnyPassword123!"
    Then the login should fail
    And I should not receive a user record

  # Session Management

  Scenario: User generates session token
    Given a confirmed user exists with email "alice@example.com"
    When I generate a session token for the user
    Then the session token should be created successfully
    And the token should be persisted in the database
    And the token context should be "session"
    And I should receive an encoded token binary

  Scenario: User retrieves account with valid session token
    Given a confirmed user exists with email "alice@example.com"
    And a valid session token exists for the user
    When I retrieve the user by session token
    Then I should receive the user record
    And I should receive the token inserted_at timestamp

  Scenario: User retrieves account with invalid session token
    When I attempt to retrieve a user with an invalid session token
    Then I should not receive a user record

  Scenario: User logs out and session token is deleted
    Given a confirmed user exists with email "alice@example.com"
    And a valid session token exists for the user
    When I delete the session token
    Then the token should be removed from the database
    And the operation should return :ok

  # Password Updates

  Scenario: User updates their password
    Given a confirmed user exists with email "alice@example.com" and password "OldPassword123!"
    When I update the password to "NewPassword123!" with confirmation "NewPassword123!"
    Then the password update should be successful
    And the password should be hashed with bcrypt
    And all user tokens should be deleted for security
    And I should receive a list of expired tokens

  Scenario: User updates password with mismatched confirmation
    Given a confirmed user exists with email "alice@example.com"
    When I attempt to update the password to "NewPassword123!" with confirmation "DifferentPassword123!"
    Then the password update should fail
    And I should see a password confirmation mismatch error

  Scenario: User updates password with short new password
    Given a confirmed user exists with email "alice@example.com"
    When I attempt to update the password to "short" with confirmation "short"
    Then the password update should fail
    And I should see a password length validation error

  # Email Updates

  Scenario: User requests email change with valid token
    Given a confirmed user exists with email "alice@example.com"
    And an email change token is generated for changing to "newalice@example.com"
    When I update the email using the change token
    Then the email update should be successful
    And the user email should be "newalice@example.com"
    And all email change tokens should be deleted

  Scenario: User requests email change with invalid token
    Given a confirmed user exists with email "alice@example.com"
    When I attempt to update the email with an invalid token
    Then the email update should fail with error "transaction_aborted"

  Scenario: User requests email change to duplicate email
    Given a confirmed user exists with email "alice@example.com"
    And a user exists with email "existing@example.com"
    And an email change token is generated for changing to "existing@example.com"
    When I attempt to update the email using the change token
    Then the email update should fail

  # Email and Magic Link Delivery

  Scenario: User requests magic link login instructions
    Given a confirmed user exists with email "alice@example.com"
    When I request login instructions for "alice@example.com"
    Then a login token should be generated with context "login"
    And the token should be persisted in the database
    And a magic link email should be sent to "alice@example.com"
    And the email should contain the magic link URL

  Scenario: User requests email change instructions
    Given a confirmed user exists with email "alice@example.com"
    When I request email update instructions for changing to "newalice@example.com"
    Then an email change token should be generated with context "change:alice@example.com"
    And the token should be persisted in the database
    And a confirmation email should be sent to "newalice@example.com"
    And the email should contain the confirmation URL

  # Sudo Mode (Recent Authentication Check)

  Scenario: User in sudo mode (authenticated within 20 minutes)
    Given a confirmed user exists with email "alice@example.com"
    And the user authenticated 10 minutes ago
    When I check if the user is in sudo mode
    Then the user should be in sudo mode

  Scenario: User not in sudo mode (authenticated over 20 minutes ago)
    Given a confirmed user exists with email "alice@example.com"
    And the user authenticated 30 minutes ago
    When I check if the user is in sudo mode
    Then the user should not be in sudo mode

  Scenario: User not in sudo mode (never authenticated)
    Given a confirmed user exists with email "alice@example.com"
    And the user has no authenticated_at timestamp
    When I check if the user is in sudo mode
    Then the user should not be in sudo mode

  Scenario: User in sudo mode with custom time limit
    Given a confirmed user exists with email "alice@example.com"
    And the user authenticated 8 minutes ago
    When I check if the user is in sudo mode with a 10 minute limit
    Then the user should be in sudo mode

  Scenario: User not in sudo mode with custom time limit
    Given a confirmed user exists with email "alice@example.com"
    And the user authenticated 15 minutes ago
    When I check if the user is in sudo mode with a 10 minute limit
    Then the user should not be in sudo mode

  # User Lookup Operations

  Scenario: Get user by email
    Given a confirmed user exists with email "alice@example.com"
    When I get the user by email "alice@example.com"
    Then I should receive the user record
    And the user email should be "alice@example.com"

  Scenario: Get user by email (case-insensitive)
    Given a confirmed user exists with email "alice@example.com"
    When I get the user by email "ALICE@EXAMPLE.COM" using case-insensitive search
    Then I should receive the user record
    And the user email should be "alice@example.com"

  Scenario: Get user by email when not found
    When I get the user by email "nonexistent@example.com"
    Then I should not receive a user record

  Scenario: Get user by ID
    Given a confirmed user exists with email "alice@example.com"
    When I get the user by ID
    Then I should receive the user record
    And the user email should be "alice@example.com"

  Scenario: Get user by ID when not found raises error
    When I attempt to get a user with non-existent ID
    Then an Ecto.NoResultsError should be raised

  # Changeset Helpers

  Scenario: Generate email changeset for user
    Given a confirmed user exists with email "alice@example.com"
    When I generate an email changeset with new email "newalice@example.com"
    Then the changeset should include the new email
    And the changeset should have email validation rules

  Scenario: Generate password changeset for user
    Given a confirmed user exists with email "alice@example.com"
    When I generate a password changeset with new password "NewPassword123!"
    Then the changeset should include the new password
    And the changeset should have password validation rules

  # Edge Cases and Security

  Scenario: Password verification with timing attack protection
    When I verify a password for a non-existent user
    Then Bcrypt.no_user_verify should be called
    And the result should be false

  Scenario: Email is normalized to lowercase during registration
    When I register with email "UPPERCASE@EXAMPLE.COM"
    Then the user email should be stored as "uppercase@example.com"

  Scenario: Registration sets date_created timestamp
    When I register a new user
    Then the user should have a date_created timestamp
    And the timestamp should be within 5 seconds of now

  Scenario: User token expires after period
    Given a confirmed user exists with email "alice@example.com"
    And a session token was created 90 days ago
    When I attempt to retrieve the user by that session token
    Then I should not receive a user record

  Scenario: Magic link token cannot be used as session token
    Given a confirmed user exists with email "alice@example.com"
    And a magic link token is generated for "alice@example.com"
    When I attempt to retrieve the user by session token using the magic link token
    Then I should not receive a user record

  Scenario: Transaction rollback on password update failure
    Given a confirmed user exists with email "alice@example.com"
    When the password update fails during transaction
    Then the user password should remain unchanged
    And no tokens should be deleted

  Scenario: Magic link confirmation sets confirmed_at timestamp
    Given an unconfirmed user exists with email "bob@example.com"
    And a magic link token is generated for "bob@example.com"
    When I login with the magic link token
    Then the confirmed_at timestamp should be set to current time
    And the timestamp should be in UTC
