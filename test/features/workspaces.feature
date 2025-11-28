Feature: Workspace Management
  As a workspace user
  I want to create, manage, and collaborate in workspaces
  So that I can organize my team's work and control access

  Background:
    Given a workspace exists with name "Product Team" and slug "product-team"
    And the following users exist:
      | Email              | Role   |
      | alice@example.com  | owner  |
      | bob@example.com    | admin  |
      | charlie@example.com| member |
      | diana@example.com  | guest   |

  Scenario: Owner creates a new workspace
    Given I am logged in as "alice@example.com"
    When I navigate to the workspaces page
    And I click "New Workspace"
    And I fill in the workspace form with:
      | Field        | Value              |
      | Name         | Marketing Team     |
      | Description  | Marketing campaigns |
      | Color        | #FF6B6B            |
    And I submit the form
    Then I should see "Workspace created successfully"
    And I should see "Marketing Team" in the workspace list
    And the workspace should have slug "marketing-team"

  Scenario: Member views workspace details
    Given I am logged in as "charlie@example.com"
    When I navigate to workspace "product-team"
    Then I should see "Product Team"
    And I should see the workspace description
    And I should see the projects section
    And I should see the documents section
    And I should see the agents section

  Scenario: Admin edits workspace details
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Edit Workspace"
    And I fill in the workspace form with:
      | Field        | Value                    |
      | Name         | Product Team Updated     |
      | Description  | Updated description      |
      | Color        | #4A90E2                 |
    And I submit the form
    Then I should see "Workspace updated successfully"
    And I should see "Product Team Updated"

  Scenario: Member cannot edit workspace
    Given I am logged in as "charlie@example.com"
    When I navigate to workspace "product-team"
    Then I should not see "Edit Workspace"
    And I attempt to edit workspace "product-team"
    Then I should receive a forbidden error

  Scenario: Guest cannot edit workspace
    Given I am logged in as "diana@example.com"
    When I navigate to workspace "product-team"
    Then I should not see "Edit Workspace"
    And I attempt to edit workspace "product-team"
    Then I should receive a forbidden error

  Scenario: Owner deletes workspace
    Given I am logged in as "alice@example.com"
    And I navigate to workspace "product-team"
    When I click "Delete Workspace"
    And I confirm the deletion
    Then I should see "Workspace deleted successfully"
    And I should be redirected to the workspaces page
    And I should not see "Product Team" in the workspace list

  Scenario: Admin cannot delete workspace
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    Then I should not see "Delete Workspace"
    And I attempt to delete workspace "product-team"
    Then I should receive a forbidden error

  Scenario: Admin invites new member (non-Jarga user)
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Manage Members"
    And I invite "eve@example.com" as "member"
    Then I should see "eve@example.com" in the members list with status "Pending"
    And an invitation email should be queued

  Scenario: Admin adds existing Jarga user as member
    Given a user "frank@example.com" exists but is not a member of workspace "product-team"
    And I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Manage Members"
    And I invite "frank@example.com" as "admin"
    Then I should see "frank@example.com" in the members list with status "Active"
    And a notification email should be queued

  Scenario: Member cannot invite other members
    Given I am logged in as "charlie@example.com"
    When I navigate to workspace "product-team"
    Then I should not see "Manage Members"
    And I attempt to invite "new@example.com" as "member" to workspace "product-team"
    Then I should receive a forbidden error

  Scenario: Admin changes member role
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Manage Members"
    And I change "charlie@example.com"'s role to "admin"
    Then I should see "Member role updated successfully"
    And "charlie@example.com" should have role "admin" in the members list

  Scenario: Admin cannot change owner's role
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Manage Members"
    And I attempt to change "alice@example.com"'s role
    Then I should not see a role selector for "alice@example.com"
    And the owner role should be read-only

  Scenario: Admin removes member
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Manage Members"
    And I remove "charlie@example.com" from the workspace
    Then I should see "Member removed successfully"
    And I should not see "charlie@example.com" in the members list

  Scenario: Admin cannot remove owner
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Manage Members"
    And I attempt to remove "alice@example.com" from the workspace
    Then I should not see a remove button for "alice@example.com"
    And I should receive a "cannot remove owner" error

  Scenario: Non-member cannot access workspace
    Given a user "outsider@example.com" exists but is not a member of workspace "product-team"
    And I am logged in as "outsider@example.com"
    When I attempt to navigate to workspace "product-team"
    Then I should receive an unauthorized error
    And I should be redirected to the workspaces page

  Scenario: Guest can view workspace but limited actions
    Given I am logged in as "diana@example.com"
    When I navigate to workspace "product-team"
    Then I should see "Product Team"
    And I should not see "New Project" button
    And I should not see "New Document" button
    And I should not see "Manage Members"

  Scenario: Member can create projects and documents
    Given I am logged in as "charlie@example.com"
    When I navigate to workspace "product-team"
    Then I should see "New Project" button
    And I should see "New Document" button
    And I should be able to create a project
    And I should be able to create a document

  Scenario: Workspace list shows all user workspaces
    Given a workspace exists with name "Engineering" and slug "engineering"
    And a user "alice@example.com" exists as owner of workspace "engineering"
    And I am logged in as "alice@example.com"
    When I navigate to the workspaces page
    Then I should see "Product Team" in the workspace list
    And I should see "Engineering" in the workspace list
    And each workspace should show its description
    And each workspace should be clickable

  Scenario: Empty workspace list shows helpful message
    Given a user "newuser@example.com" exists but is not a member of any workspace
    And I am logged in as "newuser@example.com"
    When I navigate to the workspaces page
    Then I should see "No workspaces yet"
    And I should see "Create your first workspace to get started"
    And I should see a "Create Workspace" button

  Scenario: Workspace with color displays correctly
    Given I am logged in as "alice@example.com"
    And a workspace exists with name "Design Team" and slug "design-team" and color "#FF6B6B"
    And a user "alice@example.com" exists as owner of workspace "design-team"
    When I navigate to the workspaces page
    Then I should see "Design Team" in the workspace list
    And I should see a color bar with color "#FF6B6B" for the workspace

  Scenario: Invalid workspace creation shows errors
    Given I am logged in as "alice@example.com"
    When I navigate to the workspaces page
    And I click "New Workspace"
    And I fill in the workspace form with:
      | Field        | Value |
      | Name         |       |
      | Description  | Test  |
    And I submit the form
    Then I should see validation errors
    And I should not see "Workspace created successfully"
    And I should remain on the new workspace page