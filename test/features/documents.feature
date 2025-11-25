Feature: Document Management
  As a workspace member
  I want to create, view, edit, and manage documents
  So that I can collaborate with my team on shared content

  Background:
    Given a workspace exists with name "Product Team" and slug "product-team"
    And a user "alice@example.com" exists as owner of workspace "product-team"
    And a user "bob@example.com" exists as admin of workspace "product-team"
    And a user "charlie@example.com" exists as member of workspace "product-team"
    And a user "diana@example.com" exists as guest of workspace "product-team"
    And a user "eve@example.com" exists but is not a member of workspace "product-team"

  # Document Creation

  Scenario: Owner creates a document in workspace
    Given I am logged in as "alice@example.com"
    When I create a document with title "Product Roadmap" in workspace "product-team"
    Then the document should be created successfully
    And the document should have slug "product-roadmap"
    And the document should be owned by "alice@example.com"
    And the document should be private by default
    And the document should have an embedded note component

  Scenario: Admin creates a document in workspace
    Given I am logged in as "bob@example.com"
    When I create a document with title "Architecture Doc" in workspace "product-team"
    Then the document should be created successfully
    And the document should be owned by "bob@example.com"

  Scenario: Member creates a document in workspace
    Given I am logged in as "charlie@example.com"
    When I create a document with title "Meeting Notes" in workspace "product-team"
    Then the document should be created successfully
    And the document should be owned by "charlie@example.com"

  Scenario: Guest cannot create documents
    Given I am logged in as "diana@example.com"
    When I attempt to create a document with title "Unauthorized Doc" in workspace "product-team"
    Then I should receive a forbidden error

  Scenario: Non-member cannot create documents
    Given I am logged in as "eve@example.com"
    When I attempt to create a document with title "Outsider Doc" in workspace "product-team"
    Then I should receive an unauthorized error

  Scenario: Create document with project association
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" in workspace "product-team"
    When I create a document with title "Mobile Specs" in project "Mobile App"
    Then the document should be created successfully
    And the document should be associated with project "Mobile App"

  Scenario: Cannot create document with project from different workspace
    Given I am logged in as "alice@example.com"
    And a workspace exists with name "Marketing Team" and slug "marketing-team"
    And user "alice@example.com" is owner of workspace "marketing-team"
    And a project exists with name "Campaign" in workspace "marketing-team"
    When I attempt to create a document in workspace "product-team" with project from "marketing-team"
    Then I should receive a project not in workspace error

  Scenario: Document slug is unique within workspace
    Given I am logged in as "alice@example.com"
    And a document exists with title "Roadmap" in workspace "product-team"
    When I create a document with title "Roadmap" in workspace "product-team"
    Then the document should be created successfully
    And the document should have a unique slug like "roadmap-*"

  # Document Viewing and Access Control

  Scenario: Owner views their own private document
    Given I am logged in as "alice@example.com"
    And a private document exists with title "Private Notes" owned by "alice@example.com"
    When I view document "Private Notes" in workspace "product-team"
    Then I should see the document content
    And I should be able to edit the document

  Scenario: Member cannot view another user's private document
    Given I am logged in as "charlie@example.com"
    And a private document exists with title "Alice's Private Notes" owned by "alice@example.com"
    When I attempt to view document "Alice's Private Notes" in workspace "product-team"
    Then I should receive a document not found error

  Scenario: Admin cannot view another user's private document
    Given I am logged in as "bob@example.com"
    And a private document exists with title "Alice's Private Notes" owned by "alice@example.com"
    When I attempt to view document "Alice's Private Notes" in workspace "product-team"
    Then I should receive a document not found error

  Scenario: Member views public document created by another user
    Given I am logged in as "charlie@example.com"
    And a public document exists with title "Team Guidelines" owned by "alice@example.com"
    When I view document "Team Guidelines" in workspace "product-team"
    Then I should see the document content
    And I should be able to edit the document

  Scenario: Guest views public document in read-only mode
    Given I am logged in as "diana@example.com"
    And a public document exists with title "Team Guidelines" owned by "alice@example.com"
    When I view document "Team Guidelines" in workspace "product-team"
    Then I should see the document content
    And I should see a read-only indicator
    And I should not be able to edit the document

  Scenario: Guest cannot view private documents
    Given I am logged in as "diana@example.com"
    And a private document exists with title "Private Roadmap" owned by "alice@example.com"
    When I attempt to view document "Private Roadmap" in workspace "product-team"
    Then I should receive a document not found error

  Scenario: Non-member cannot view any documents
    Given I am logged in as "eve@example.com"
    And a public document exists with title "Team Guidelines" owned by "alice@example.com"
    When I attempt to view document "Team Guidelines" in workspace "product-team"
    Then I should receive an unauthorized error

  # Document Listing

  Scenario: User sees their own documents and public documents
    Given I am logged in as "charlie@example.com"
    And the following documents exist in workspace "product-team":
      | title              | owner              | visibility |
      | Charlie's Private  | charlie@example.com | private   |
      | Alice's Private    | alice@example.com  | private   |
      | Alice's Public     | alice@example.com  | public    |
      | Bob's Public       | bob@example.com    | public    |
    When I list documents in workspace "product-team"
    Then I should see documents:
      | title              |
      | Charlie's Private  |
      | Alice's Public     |
      | Bob's Public       |
    And I should not see documents:
      | title              |
      | Alice's Private    |

  Scenario: Workspace page shows only workspace-level documents (not project documents)
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" in workspace "product-team"
    And a document exists with title "Workspace Doc" in workspace "product-team"
    And a document exists with title "Project Doc" in project "Mobile App"
    When I list documents in workspace "product-team"
    Then I should see documents:
      | title           |
      | Workspace Doc   |
    And I should not see "Project Doc"

  Scenario: List documents filtered by project
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" in workspace "product-team"
    And a project exists with name "Web App" in workspace "product-team"
    And the following documents exist:
      | title           | project     |
      | Mobile Specs    | Mobile App  |
      | Mobile Design   | Mobile App  |
      | Web Architecture| Web App     |
    When I list documents for project "Mobile App"
    Then I should see documents:
      | title           |
      | Mobile Specs    |
      | Mobile Design   |
    And I should not see "Web Architecture"

  # Document Updates

  Scenario: Owner updates their own document title
    Given I am logged in as "alice@example.com"
    And a document exists with title "Draft Roadmap" owned by "alice@example.com"
    When I update the document title to "Product Roadmap Q1"
    Then the document title should be "Product Roadmap Q1"
    And the document slug should remain unchanged

  Scenario: Owner changes document visibility to public
    Given I am logged in as "alice@example.com"
    And a private document exists with title "Private Doc" owned by "alice@example.com"
    When I make the document public
    Then the document should be public
    And a visibility changed notification should be broadcast

  Scenario: Owner changes document visibility to private
    Given I am logged in as "alice@example.com"
    And a public document exists with title "Public Doc" owned by "alice@example.com"
    When I make the document private
    Then the document should be private
    And a visibility changed notification should be broadcast

  Scenario: Member edits public document they don't own
    Given I am logged in as "charlie@example.com"
    And a public document exists with title "Team Doc" owned by "alice@example.com"
    When I update the document title to "Updated Team Doc"
    Then the document title should be "Updated Team Doc"

  Scenario: Member cannot edit private document they don't own
    Given I am logged in as "charlie@example.com"
    And a private document exists with title "Alice's Doc" owned by "alice@example.com"
    When I attempt to update the document title to "Hacked"
    Then I should receive a forbidden error

  Scenario: Admin can edit public documents
    Given I am logged in as "bob@example.com"
    And a public document exists with title "Team Guidelines" owned by "charlie@example.com"
    When I update the document title to "Updated Guidelines"
    Then the document title should be "Updated Guidelines"

  Scenario: Admin cannot edit private documents they don't own
    Given I am logged in as "bob@example.com"
    And a private document exists with title "Charlie's Private" owned by "charlie@example.com"
    When I attempt to update the document title to "Admin Override"
    Then I should receive a forbidden error

  Scenario: Guest cannot edit any documents
    Given I am logged in as "diana@example.com"
    And a public document exists with title "Public Doc" owned by "alice@example.com"
    When I attempt to update the document title to "Guest Edit"
    Then I should receive a forbidden error

  # Document Pinning

  Scenario: Owner pins their own document
    Given I am logged in as "alice@example.com"
    And a document exists with title "Important Doc" owned by "alice@example.com"
    When I pin the document
    Then the document should be pinned
    And a pin status changed notification should be broadcast

  Scenario: Owner unpins their own document
    Given I am logged in as "alice@example.com"
    And a pinned document exists with title "Pinned Doc" owned by "alice@example.com"
    When I unpin the document
    Then the document should not be pinned

  Scenario: Member pins public document
    Given I am logged in as "charlie@example.com"
    And a public document exists with title "Team Doc" owned by "alice@example.com"
    When I pin the document
    Then the document should be pinned

  Scenario: Member cannot pin private document they don't own
    Given I am logged in as "charlie@example.com"
    And a private document exists with title "Private Doc" owned by "alice@example.com"
    When I attempt to pin the document
    Then I should receive a forbidden error

  Scenario: Guest cannot pin any documents
    Given I am logged in as "diana@example.com"
    And a public document exists with title "Public Doc" owned by "alice@example.com"
    When I attempt to pin the document
    Then I should receive a forbidden error

  # Document Deletion

  Scenario: Owner deletes their own document
    Given I am logged in as "alice@example.com"
    And a document exists with title "Old Doc" owned by "alice@example.com"
    When I delete the document
    Then the document should be deleted successfully
    And the embedded note should also be deleted
    And a document deleted notification should be broadcast

  Scenario: Admin deletes public document
    Given I am logged in as "bob@example.com"
    And a public document exists with title "Outdated Public Doc" owned by "charlie@example.com"
    When I delete the document
    Then the document should be deleted successfully

  Scenario: Admin cannot delete private documents they don't own
    Given I am logged in as "bob@example.com"
    And a private document exists with title "Charlie's Private" owned by "charlie@example.com"
    When I attempt to delete the document
    Then I should receive a forbidden error

  Scenario: Member cannot delete documents they don't own
    Given I am logged in as "charlie@example.com"
    And a public document exists with title "Team Doc" owned by "alice@example.com"
    When I attempt to delete the document
    Then I should receive a forbidden error

  Scenario: Guest cannot delete any documents
    Given I am logged in as "diana@example.com"
    And a public document exists with title "Public Doc" owned by "alice@example.com"
    When I attempt to delete the document
    Then I should receive a forbidden error

  # Collaborative Editing

  @javascript
  Scenario: Multiple users edit document simultaneously
    Given I am logged in as "alice@example.com"
    And a public document exists with title "Collaborative Doc" owned by "alice@example.com"
    And user "charlie@example.com" is also viewing the document
    When I make changes to the document content
    Then user "charlie@example.com" should see my changes in real-time via PubSub
    And the changes should be synced using Yjs CRDT

  @javascript
  Scenario: User saves document content
    Given I am logged in as "alice@example.com"
    And a document exists with title "My Notes" owned by "alice@example.com"
    When I edit the document content
    Then the changes should be broadcast immediately to other users
    And the changes should be debounced before saving to database
    And the Yjs state should be persisted

  @javascript
  Scenario: User force saves on tab close
    Given I am logged in as "alice@example.com"
    And a document exists with title "My Doc" owned by "alice@example.com"
    And I have unsaved changes
    When I close the browser tab
    Then the changes should be force saved immediately
    And the Yjs state should be updated

  # Real-time Notifications

  Scenario: Document title change notification
    Given I am logged in as "alice@example.com"
    And a public document exists with title "Team Doc" owned by "alice@example.com"
    And user "charlie@example.com" is viewing the document
    When I update the document title to "Updated Team Doc"
    Then user "charlie@example.com" should receive a real-time title update
    And the title should update in their UI without refresh

  Scenario: Document visibility change notification
    Given I am logged in as "alice@example.com"
    And a public document exists with title "Shared Doc" owned by "alice@example.com"
    And user "charlie@example.com" is viewing the document
    When I make the document private
    Then user "charlie@example.com" should receive a visibility changed notification
    And user "charlie@example.com" should lose access to the document

  Scenario: Document pin status change notification
    Given I am logged in as "alice@example.com"
    And a public document exists with title "Important Doc" owned by "alice@example.com"
    And user "charlie@example.com" is viewing the workspace
    When I pin the document
    Then user "charlie@example.com" should see the document marked as pinned

  # Document Components

  Scenario: Document has embedded note component by default
    Given I am logged in as "alice@example.com"
    When I create a document with title "New Doc" in workspace "product-team"
    Then the document should have one note component
    And the note component should be at position 0
    And the note component type should be "note"

  Scenario: Access document's embedded note
    Given I am logged in as "alice@example.com"
    And a document exists with title "My Doc" owned by "alice@example.com"
    When I retrieve the document's note component
    Then I should receive the associated Note record
    And the note should be editable

  # Edge Cases

  Scenario: Create document without title
    Given I am logged in as "alice@example.com"
    When I attempt to create a document without a title in workspace "product-team"
    Then I should receive a validation error
    And the document should not be created

  Scenario: Update document with empty title
    Given I am logged in as "alice@example.com"
    And a document exists with title "Valid Title" owned by "alice@example.com"
    When I attempt to update the document title to ""
    Then I should receive a validation error
    And the document title should remain "Valid Title"

  Scenario: Transaction rollback on note creation failure
    Given I am logged in as "alice@example.com"
    When document creation fails due to note creation error
    Then the document should not be created
    And the database should be in consistent state

  Scenario: Document slug handles special characters
    Given I am logged in as "alice@example.com"
    When I create a document with title "Product & Services (2024)" in workspace "product-team"
    Then the document should be created successfully
    And the document slug should be URL-safe

  # Workspace and Project Integration

  Scenario: Document inherits project from note
    Given I am logged in as "alice@example.com"
    And a project exists with name "Research" in workspace "product-team"
    When I create a document with title "Research Doc" in project "Research"
    Then the document should be associated with project "Research"
    And the embedded note should also be associated with project "Research"

  Scenario: Breadcrumb navigation in document view
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" in workspace "product-team"
    And a document exists with title "Specs" in project "Mobile App"
    When I view the document
    Then I should see breadcrumbs showing "Product Team > Mobile App > Specs"

  Scenario: Workspace name updates in document view
    Given I am logged in as "alice@example.com"
    And a document exists with title "My Doc" owned by "alice@example.com"
    And I am viewing the document
    When user "alice@example.com" updates workspace name to "Engineering Team"
    Then I should see the workspace name updated to "Engineering Team" in breadcrumbs

  Scenario: Project name updates in document view
    Given I am logged in as "alice@example.com"
    And a project exists with name "App" in workspace "product-team"
    And a document exists with title "Specs" in project "App"
    And I am viewing the document
    When user "alice@example.com" updates project name to "Mobile Application"
    Then I should see the project name updated to "Mobile Application" in breadcrumbs

  # Authorization Summary
  
  # NOTE: Scenario Outline is NOT supported by Cucumber 0.4.1
  # The presence of this Scenario Outline causes Cucumber to misreport errors
  # in the previous scenario ("Project name updates in document view").
  # Commenting out to prevent test interference.
  # TODO: Uncomment when upgrading to a Cucumber version that supports Scenario Outline
  
  # Scenario Outline: Document operation permissions by role
  #   Given I am logged in as a "<role>" user
  #   And a <visibility> document exists owned by another user
  #   When I attempt to <operation> the document
  #   Then I should <result>
  
  #   Examples:
  #     | role   | visibility | operation | result                  |
  #     | owner  | private    | view      | be able to view my own  |
  #     | owner  | public     | view      | be able to view my own  |
  #     | admin  | private    | view      | receive forbidden       |
  #     | admin  | public     | view      | be able to view         |
  #     | admin  | public     | edit      | be able to edit         |
  #     | admin  | private    | edit      | receive forbidden       |
  #     | admin  | public     | delete    | be able to delete       |
  #     | admin  | private    | delete    | receive forbidden       |
  #     | member | private    | view      | receive forbidden       |
  #     | member | public     | view      | be able to view         |
  #     | member | public     | edit      | be able to edit         |
  #     | member | private    | edit      | receive forbidden       |
  #     | member | public     | delete    | receive forbidden       |
  #     | guest  | public     | view      | be able to view readonly|
  #     | guest  | private    | view      | receive forbidden       |
  #     | guest  | public     | edit      | receive forbidden       |
  #     | guest  | public     | delete    | receive forbidden       |
