# Backend Design Principles: SOLID and Clean Architecture

This document outlines the core design principles used in this project, focusing on SOLID principles and Clean Architecture patterns as they apply to Elixir and Phoenix applications.

## Table of Contents

- [Boundary Library Enforcement](#boundary-library-enforcement)
- [SOLID Principles in Elixir/Phoenix](#solid-principles-in-elixirphoenix)
- [Clean Architecture for Phoenix](#clean-architecture-for-phoenix)
- [Best Practices](#best-practices)

---

## Boundary Library Enforcement

**This project enforces architectural boundaries using the [Boundary](https://hexdocs.pm/boundary) library.**

The Boundary library provides compile-time enforcement of architectural rules, preventing:
- Web layer calling into context internals
- Contexts accessing each other's private modules
- Circular dependencies between contexts

### Core Principles

#### 1. Core vs Interface Separation

The codebase is organized into two main layers:

**Core Layer** (`lib/jarga/`)
- Contains all business logic and domain rules
- Independent of how clients access the system (REST, GraphQL, WebSocket)
- Cannot depend on the web layer
- Contexts are the public API of the core

**Interface Layer** (`lib/jarga_web/`)
- Adapts external requests to core operations
- Handles protocol-specific concerns (HTTP, WebSocket)
- Normalizes and validates input before passing to core
- Can depend on core, but not vice versa

#### 2. The Dependency Rule

```
Interface Layer (JargaWeb)
    ↓ can call
Core Layer (Contexts: Accounts, Workspaces, Projects)
    ↓ can use
Shared Infrastructure (Repo, Mailer)
```

**Dependencies flow inward**:
- Interface depends on Core
- Core depends on Infrastructure
- Core never depends on Interface
- Infrastructure depends on nothing

#### 3. Context Independence

Each context is a **boundary** that:
- Encapsulates a specific domain area
- Exposes a minimal public API
- Hides internal implementation details
- Communicates with other contexts only through public APIs

### Boundary Configuration

#### Interface Layer: `JargaWeb`

**Location**: `lib/jarga_web.ex:21`

```elixir
use Boundary,
  deps: [Jarga.Accounts, Jarga.Workspaces, Jarga.Projects, Jarga.Repo, Jarga.Mailer],
  exports: []
```

- **Can depend on**: All core contexts and shared infrastructure
- **Exports**: Nothing (web modules are never imported by core)
- **Contains**: Controllers, LiveViews, Components, Channels, Plugs

#### Core Context: `Jarga.Accounts`

**Location**: `lib/jarga/accounts.ex:9`

```elixir
use Boundary,
  deps: [Jarga.Repo, Jarga.Mailer],
  exports: [{User, []}, {Scope, []}]
```

- **Can depend on**: Shared infrastructure only
- **Exports**: `User` and `Scope` schemas (used by other contexts)
- **Private**: `UserToken`, `UserNotifier` (internal implementation)

#### Core Context: `Jarga.Workspaces`

**Location**: `lib/jarga/workspaces.ex:14`

```elixir
use Boundary,
  deps: [Jarga.Accounts, Jarga.Repo],
  exports: [{Workspace, []}]
```

- **Can depend on**: Accounts context and shared infrastructure
- **Exports**: `Workspace` schema
- **Private**:
  - `WorkspaceMember` (schema)
  - `Queries` (infrastructure - query objects)
  - `Policies.MembershipPolicy` (domain - business rules)
  - `UseCases.*` (application - orchestration)
  - `Infrastructure.MembershipRepository` (infrastructure - data access)
  - `Services.*` (infrastructure - external services)

#### Core Context: `Jarga.Projects`

**Location**: `lib/jarga/projects.ex:14`

```elixir
use Boundary,
  deps: [Jarga.Accounts, Jarga.Workspaces, Jarga.Repo],
  exports: [{Project, []}]
```

- **Can depend on**: Accounts, Workspaces, and shared infrastructure
- **Exports**: `Project` schema
- **Private**: `Queries`, `Policies`

#### Shared Infrastructure: `Jarga.Repo` and `Jarga.Mailer`

**Location**: `lib/jarga/repo.ex:4`, `lib/jarga/mailer.ex:4`

```elixir
use Boundary, top_level?: true, deps: []
```

- **Can depend on**: Nothing (foundation layer)
- **Available to**: All contexts and web layer
- **Purpose**: Shared technical infrastructure

### Verifying Architecture

#### Compile-Time Checks

Boundary violations are caught during compilation:

```bash
mix compile
```

**Production code has no boundary warnings** when running `mix compile`. All boundaries are properly declared:

- `Jarga` - Root namespace (top-level, documentation only)
- `JargaApp` - OTP application supervisor
- `Jarga.Accounts`, `Jarga.Workspaces`, `Jarga.Projects` - Domain contexts (top-level boundaries)
- `Jarga.Repo`, `Jarga.Mailer` - Shared infrastructure (top-level boundaries)
- `JargaWeb` - Web interface layer

**Test-related warnings** may appear for test support modules (DataCase, Fixtures) but these don't affect production code.

If you see warnings like:

```
warning: forbidden reference to Jarga.Workspaces.Policies.Authorization
  (module Jarga.Workspaces.Policies.Authorization is not exported by its owner boundary Jarga.Workspaces)
  lib/jarga/projects.ex:62
```

This means you're accessing an internal module. Use the context's public API instead.

#### Pre-commit Checks

The precommit task includes boundary verification:

```bash
mix precommit
```

This runs:
- Compilation with warnings as errors
- Boundary checks (automatic during compilation)
- Code formatting
- Credo (style guide)
- Test suite

### Troubleshooting Boundary Violations

#### "Forbidden reference" warning

**Problem**: You're accessing a module that's not exported by its boundary.

**Solution**:
1. Check if the target context has a public function for what you need
2. If not, add one to the context's public API
3. Never directly access internal modules (Queries, Policies, etc.)

#### "Module is not exported" warning

**Problem**: You're trying to use a schema or module not exported by its boundary.

**Solution**:
1. If the schema needs to be shared, add it to the `exports` list
2. If it's internal-only, access it through context functions instead

**Example**:

```elixir
# Add to exports if needed by other boundaries
use Boundary,
  exports: [{MySchema, []}]
```

#### "Cannot be listed as a dependency" warning

**Problem**: You're listing a module that's not a valid dependency (wrong hierarchy).

**Solution**:
1. Only list sibling boundaries or top-level boundaries as dependencies
2. Don't list parent or child modules

#### Circular dependency

**Problem**: Context A depends on B, and B depends on A.

**Solution**:
1. Extract shared functionality into a third context
2. Or refactor one context to not need the other
3. Consider if both contexts should be merged

### Adding New Contexts

When creating a new context:

1. **Define the boundary** in the context module:

```elixir
defmodule Jarga.NewContext do
  use Boundary,
    deps: [Jarga.Repo, Jarga.Accounts],  # List dependencies
    exports: [{NewContext.Entity, []}]    # Export only what's needed

  # Public API functions
end
```

2. **Update dependent boundaries**:

```elixir
# lib/jarga_web.ex - if web needs access
use Boundary,
  deps: [..., Jarga.NewContext],
  exports: []
```

3. **Create internal organization**:
   - `new_context/entity.ex` - Schema
   - `new_context/queries.ex` - Query objects
   - `new_context/policies/*.ex` - Business rules
   - `new_context/use_cases/*.ex` - Application operations
   - `new_context/infrastructure/*.ex` - Data access

### Best Practices for Boundaries

1. **Keep Contexts Focused**
   - ✅ Accounts, Workspaces, Projects (clear domains)
   - ❌ Helpers, Utils, Common (vague, attract unrelated code)

2. **Minimize Exports**
   - ✅ Schemas used in function signatures
   - ✅ Public context module (implicit)
   - ❌ Internal query modules
   - ❌ Policy modules
   - ❌ Private helper modules

3. **Document Public APIs**
   - Every exported function should have clear documentation
   - Use precise type specs
   - Include usage examples

---

## SOLID Principles in Elixir/Phoenix

### Single Responsibility Principle (SRP)

**A module should have one reason to change.**

- **Modules should have one reason to change**: Each module should handle one specific domain concept or responsibility
- **Separate concerns**: Keep business logic, data access, validation, and presentation separate

**Example:**
```elixir
# BAD - Multiple responsibilities
defmodule UserManager do
  def create_user(attrs) do
    # Validation logic
    # Database persistence
    # Email sending
    # Logging
  end
end

# GOOD - Single responsibility
defmodule User.Creator do
  def create(attrs) do
    # Only orchestrates the creation process
  end
end

defmodule User.Validator do
  def validate(attrs) do
    # Only validates user data
  end
end

defmodule User.Repository do
  def insert(user) do
    # Only handles database operations
  end
end
```

### Open/Closed Principle (OCP)

**Software entities should be open for extension but closed for modification.**

- **Use behaviors and protocols**: Design for extension through protocols and behaviors rather than modification
- **Pattern matching for extensibility**: Leverage Elixir's pattern matching to add new cases without modifying existing code

**Example:**
```elixir
# Using behaviors for extension
defmodule PaymentProcessor do
  @callback process(amount :: Money.t(), details :: map()) :: {:ok, Transaction.t()} | {:error, term()}
end

defmodule StripePaymentProcessor do
  @behaviour PaymentProcessor

  def process(amount, details) do
    # Stripe-specific implementation
  end
end

defmodule PayPalPaymentProcessor do
  @behaviour PaymentProcessor

  def process(amount, details) do
    # PayPal-specific implementation
  end
end
```

### Liskov Substitution Principle (LSP)

**Objects should be replaceable with instances of their subtypes without altering correctness.**

- **Behaviors must be reliable**: Any module implementing a behavior should be substitutable without breaking functionality
- **Protocol implementations**: Ensure protocol implementations maintain expected contracts
- **Consistent return types**: Functions implementing the same behavior should return consistent data structures

**Example:**
```elixir
# All implementations return consistent {:ok, result} | {:error, reason}
defmodule Notifier do
  @callback notify(user :: User.t(), message :: String.t()) :: {:ok, term()} | {:error, term()}
end

defmodule EmailNotifier do
  @behaviour Notifier

  def notify(user, message) do
    {:ok, %{sent_via: :email}}  # Consistent return structure
  end
end

defmodule SMSNotifier do
  @behaviour Notifier

  def notify(user, message) do
    {:ok, %{sent_via: :sms}}  # Consistent return structure
  end
end
```

### Interface Segregation Principle (ISP)

**Clients should not be forced to depend on interfaces they don't use.**

- **Small, focused behaviors**: Create small behaviors with minimal required callbacks
- **Context-specific APIs**: Design context modules with focused public APIs

**Example:**
```elixir
# BAD - Fat interface
defmodule DataStore do
  @callback read(key :: String.t()) :: {:ok, term()} | {:error, term()}
  @callback write(key :: String.t(), value :: term()) :: :ok | {:error, term()}
  @callback delete(key :: String.t()) :: :ok | {:error, term()}
  @callback subscribe(key :: String.t()) :: :ok
  @callback unsubscribe(key :: String.t()) :: :ok
end

# GOOD - Segregated interfaces
defmodule ReadableStore do
  @callback read(key :: String.t()) :: {:ok, term()} | {:error, term()}
end

defmodule WritableStore do
  @callback write(key :: String.t(), value :: term()) :: :ok | {:error, term()}
  @callback delete(key :: String.t()) :: :ok | {:error, term()}
end

defmodule SubscribableStore do
  @callback subscribe(key :: String.t()) :: :ok
  @callback unsubscribe(key :: String.t()) :: :ok
end
```

### Dependency Inversion Principle (DIP)

**Depend on abstractions, not concretions.**

- **Depend on abstractions**: Use behaviors and protocols instead of concrete implementations
- **Inject dependencies**: Pass dependencies as function arguments or use application config

**Example:**
```elixir
# BAD - Depends on concrete implementation
defmodule OrderProcessor do
  def process(order) do
    StripePaymentProcessor.charge(order.amount)  # Tightly coupled
  end
end

# GOOD - Depends on abstraction
defmodule OrderProcessor do
  def process(order, payment_processor \\ default_processor()) do
    payment_processor.process(order.amount, order.details)
  end

  defp default_processor do
    Application.get_env(:my_app, :payment_processor, StripePaymentProcessor)
  end
end
```

---

## Clean Architecture for Phoenix

Clean Architecture organizes code into layers with clear dependencies, where inner layers contain business logic and outer layers contain implementation details.

### Layer Structure

```
lib/
├── my_app/               # Core Domain Layer (Business Logic)
│   ├── domain/           # Domain entities and business rules
│   │   ├── entities/     # Pure business objects
│   │   ├── value_objects/ # Immutable value types
│   │   └── policies/     # Business rules and policies
│   ├── application/      # Application Use Cases
│   │   └── use_cases/    # Application-specific business rules
│   └── infrastructure/   # Infrastructure Layer
│       ├── persistence/  # Database repos and queries
│       ├── external/     # External API clients
│       └── messaging/    # Message queues, pub/sub
├── my_app_web/           # Interface Adapters (Presentation)
│   ├── controllers/      # HTTP request handlers
│   ├── views/            # Response rendering
│   ├── live/             # LiveView modules
│   ├── components/       # Reusable UI components
│   └── channels/         # WebSocket channels
└── my_app.ex             # Application boundary
```

### Dependency Rule

**Dependencies should point inward only:**

```
Interface Layer (Web) → Application Layer (Use Cases) → Domain Layer (Business Logic)
                    ↘ Infrastructure Layer (Persistence, External Services)
```

- Outer layers depend on inner layers
- Inner layers never depend on outer layers
- Domain layer has no dependencies on frameworks

### Architecture Guidelines

#### 1. Domain Layer (Core Business Logic)

The innermost layer containing pure business logic.

**Characteristics:**
- **Pure business logic**: No dependencies on Phoenix, Ecto, or external frameworks
- **Domain entities**: Represent core business concepts
- **Value objects**: Immutable types representing domain values

**Example:**
```elixir
# lib/my_app/domain/entities/order.ex
defmodule MyApp.Domain.Entities.Order do
  @enforce_keys [:id, :customer_id, :items, :status]
  defstruct [:id, :customer_id, :items, :status, :total]

  # Pure business logic - no database, no framework dependencies
  def calculate_total(%__MODULE__{items: items}) do
    Enum.reduce(items, Money.new(0), fn item, acc ->
      Money.add(acc, Money.multiply(item.price, item.quantity))
    end)
  end

  def can_cancel?(%__MODULE__{status: status}) do
    status in [:pending, :confirmed]
  end
end
```

#### 2. Application Layer (Use Cases)

Orchestrates business logic and defines application-specific operations.

**Characteristics:**
- **Orchestrates domain logic**: Coordinates domain entities and infrastructure
- **Transaction boundaries**: Defines where database transactions occur
- **Use case per operation**: Each use case handles one business operation

**Example:**
```elixir
# lib/my_app/application/use_cases/place_order.ex
defmodule MyApp.Application.UseCases.PlaceOrder do
  alias MyApp.Domain.Entities.Order
  alias MyApp.Infrastructure.Persistence.OrderRepo

  def execute(customer_id, items, opts \\ []) do
    repo = Keyword.get(opts, :repo, OrderRepo)

    with {:ok, order} <- build_order(customer_id, items),
         {:ok, saved_order} <- repo.insert(order),
         :ok <- notify_customer(saved_order) do
      {:ok, saved_order}
    end
  end

  defp build_order(customer_id, items) do
    # Domain logic here
  end

  defp notify_customer(order) do
    # Infrastructure call here
  end
end
```

#### 3. Infrastructure Layer

Handles technical details like database access and external services.

**Characteristics:**
- **Data persistence**: Ecto schemas, repos, and queries
- **External integrations**: API clients, message queues
- **Keep separate from domain**: Infrastructure should depend on domain, not vice versa

**Example:**
```elixir
# lib/my_app/infrastructure/persistence/order_repo.ex
defmodule MyApp.Infrastructure.Persistence.OrderRepo do
  alias MyApp.Domain.Entities.Order
  alias MyApp.Infrastructure.Persistence.Schemas.OrderSchema
  alias MyApp.Repo

  def insert(order) do
    order
    |> to_schema()
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, to_entity(schema)}
      error -> error
    end
  end

  defp to_schema(%Order{} = order) do
    # Convert domain entity to Ecto schema
  end

  defp to_entity(%OrderSchema{} = schema) do
    # Convert Ecto schema to domain entity
  end
end
```

#### 4. Interface Layer (Phoenix Web)

Handles user interactions and external interfaces.

**Characteristics:**
- **Thin controllers**: Controllers only handle HTTP concerns (parsing, validation, rendering)
- **Delegate to use cases**: Business logic lives in application layer
- **No business logic**: Only transformation between HTTP and application layer

**Example:**
```elixir
# lib/my_app_web/controllers/order_controller.ex
defmodule MyAppWeb.OrderController do
  use MyAppWeb, :controller

  alias MyApp.Application.UseCases.PlaceOrder

  def create(conn, %{"order" => order_params}) do
    customer_id = conn.assigns.current_user.id

    case PlaceOrder.execute(customer_id, order_params["items"]) do
      {:ok, order} ->
        conn
        |> put_status(:created)
        |> render(:show, order: order)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, reason: reason)
    end
  end
end
```

### Context Organization

#### Phoenix Contexts as Application Boundaries

Phoenix contexts align well with Clean Architecture's application layer.

- **Contexts represent business domains**: Each context encapsulates a specific area of the business
- **Public API only**: Only expose necessary functions through context module
- **Hide implementation details**: Internal queries, policies, and schemas are private

**Example:**
```elixir
# lib/my_app/orders.ex - Public context API
defmodule MyApp.Orders do
  @moduledoc """
  The Orders context - public API for order management.
  """

  alias MyApp.Application.UseCases.PlaceOrder
  alias MyApp.Application.UseCases.CancelOrder
  alias MyApp.Infrastructure.Persistence.OrderRepo

  # Public API
  def place_order(customer_id, items) do
    PlaceOrder.execute(customer_id, items)
  end

  def cancel_order(order_id, reason) do
    CancelOrder.execute(order_id, reason)
  end

  def get_order(id) do
    OrderRepo.get(id)
  end

  # Internal modules are not exposed
  # - MyApp.Orders.Queries
  # - MyApp.Orders.Policies
  # - MyApp.Orders.Schemas
end
```

---

## Best Practices

### 1. Separation of Ecto Schemas and Domain Logic

Keep your domain logic independent of database concerns.

**Principle:**
- Keep Ecto schemas in the infrastructure layer for data persistence
- Keep domain logic in separate domain modules
- Use changesets only for data validation, not business rules
- Domain entities should not depend on Ecto

**Example:**
```elixir
# BAD - Business logic in Ecto schema
defmodule MyApp.Order do
  use Ecto.Schema

  schema "orders" do
    field :status, :string
    field :total, :integer
  end

  def can_cancel?(%__MODULE__{status: status}), do: status == "pending"
end

# GOOD - Separation of concerns
# Infrastructure layer - database schema
defmodule MyApp.Infrastructure.Schemas.OrderSchema do
  use Ecto.Schema

  schema "orders" do
    field :status, :string
    field :total, :integer
  end

  def changeset(schema, attrs) do
    # Only validation logic
  end
end

# Domain layer - business logic
defmodule MyApp.Domain.Order do
  defstruct [:id, :status, :total]

  def can_cancel?(%__MODULE__{status: status}), do: status == :pending
end
```

### 2. Dependency Injection Patterns

Make your code testable and flexible by injecting dependencies.

**Techniques:**
- Use application config for swappable dependencies at compile time
- Pass dependencies explicitly as function arguments for runtime flexibility
- Provide default implementations while allowing overrides for testing
- Use keyword lists for multiple optional dependencies

**Example:**
```elixir
defmodule MyApp.Orders.PlaceOrder do
  def execute(customer_id, items, opts \\ []) do
    repo = Keyword.get(opts, :repo, MyApp.OrderRepo)
    notifier = Keyword.get(opts, :notifier, MyApp.EmailNotifier)

    with {:ok, order} <- build_order(customer_id, items),
         {:ok, saved} <- repo.insert(order),
         :ok <- notifier.notify(customer_id, "Order placed") do
      {:ok, saved}
    end
  end
end

# In tests
test "places order successfully" do
  PlaceOrder.execute(123, items, repo: MockRepo, notifier: MockNotifier)
end
```

### 3. Use Cases Pattern

Encapsulate each business operation in a dedicated use case module.

**Principles:**
- Create a behavior for standardized use case interface
- Each use case implements a single business operation
- Use cases orchestrate domain logic and infrastructure
- Return consistent result tuples: `{:ok, result}` or `{:error, reason}`
- Accept dependencies as keyword arguments for testability

**Example:**
```elixir
# Define a common use case behavior
defmodule MyApp.UseCase do
  @callback execute(params :: map(), opts :: keyword()) :: {:ok, term()} | {:error, term()}
end

# Implement specific use cases
defmodule MyApp.Orders.PlaceOrder do
  @behaviour MyApp.UseCase

  def execute(params, opts \\ []) do
    repo = Keyword.get(opts, :repo, MyApp.Repo)

    Repo.transaction(fn ->
      with {:ok, order} <- create_order(params),
           {:ok, _payment} <- process_payment(order),
           :ok <- send_confirmation(order) do
        {:ok, order}
      else
        error -> Repo.rollback(error)
      end
    end)
  end
end
```

### 4. Query Objects Pattern

Keep your repositories clean by extracting complex queries into dedicated query modules within contexts.

**Principles:**
- Extract complex queries into dedicated query modules
- Keep repositories thin by delegating to query objects
- Make queries composable and reusable
- Organize queries by domain entity
- Query modules return Ecto queryables, not results
- Query modules are internal to the context (not exported)

**Example:**
```elixir
# lib/my_app/orders/queries.ex
defmodule MyApp.Orders.Queries do
  @moduledoc """
  Query objects for order data access.
  This module is internal to the Orders context.
  """

  import Ecto.Query
  alias MyApp.Orders.Order

  def base do
    from(o in Order)
  end

  def by_customer(query, customer_id) do
    where(query, [o], o.customer_id == ^customer_id)
  end

  def active(query) do
    where(query, [o], o.status in ["pending", "confirmed"])
  end

  def recent(query, days \\ 30) do
    where(query, [o], o.created_at > ago(^days, "day"))
  end

  def with_details(query) do
    preload(query, [:items, :customer])
  end

  def ordered(query) do
    order_by(query, [o], desc: o.inserted_at)
  end
end
```

**Usage in context**:
```elixir
# lib/my_app/orders.ex
defmodule MyApp.Orders do
  alias MyApp.Orders.Queries
  alias MyApp.Repo

  def list_active_orders_for_customer(customer_id) do
    Queries.base()
    |> Queries.by_customer(customer_id)
    |> Queries.active()
    |> Queries.recent()
    |> Queries.with_details()
    |> Queries.ordered()
    |> Repo.all()
  end
end
```

**Benefits:**
- Composable queries
- Reusable across context functions
- Testable in isolation
- Clear separation from business logic

### 5. Domain Policy Pattern

**Pure domain policies** contain business rules with no infrastructure dependencies.

**Principles:**
- No external dependencies (no Repo, no Ecto.Query, no HTTP)
- Pure functions only - deterministic and side-effect free
- Fast unit tests (no database needed)
- Encapsulate business rules and validation logic

**Example:**
```elixir
# lib/my_app/workspaces/policies/membership_policy.ex
defmodule MyApp.Workspaces.Policies.MembershipPolicy do
  @moduledoc """
  Pure domain policy for workspace membership business rules.

  No infrastructure dependencies - pure functions only.
  """

  @allowed_invitation_roles [:admin, :member, :guest]
  @protected_roles [:owner]

  def valid_invitation_role?(role), do: role in @allowed_invitation_roles
  def valid_role_change?(role), do: role in @allowed_invitation_roles
  def can_change_role?(member_role), do: member_role not in @protected_roles
  def can_remove_member?(member_role), do: member_role not in @protected_roles
end
```

**Benefits:**
- Testable without database
- No side effects
- Clear, focused business rules
- Fast unit tests

### 6. Repository Pattern

**Infrastructure repositories** handle data access and abstract database queries.

**Principles:**
- Encapsulate data access logic
- Allow dependency injection for testing
- Clear separation from business logic
- Reusable across use cases
- Use query objects for complex queries

**Example:**
```elixir
# lib/my_app/workspaces/infrastructure/membership_repository.ex
defmodule MyApp.Workspaces.Infrastructure.MembershipRepository do
  @moduledoc """
  Repository for workspace membership data access.

  Infrastructure layer - handles database queries.
  """

  alias MyApp.Repo
  alias MyApp.Workspaces.Queries

  def get_workspace_for_user(user, workspace_id, repo \\ Repo) do
    Queries.for_user_by_id(user, workspace_id)
    |> repo.one()
  end

  def workspace_exists?(workspace_id, repo \\ Repo) do
    case Queries.exists?(workspace_id) |> repo.one() do
      count when count > 0 -> true
      _ -> false
    end
  end

  def find_member_by_email(workspace_id, email, repo \\ Repo) do
    Queries.find_member_by_email(workspace_id, email)
    |> repo.one()
  end
end
```

**Benefits:**
- Encapsulates data access
- Allows dependency injection for testing
- Clear separation from business logic
- Reusable across use cases

### 7. Use Cases Pattern

**Use cases** implement business operations by orchestrating domain policies and infrastructure.

**Principles:**
- Single Responsibility: Each use case handles one business operation
- Testable: Can inject mock repositories and notifiers
- Clear flow: Read top-to-bottom what the operation does
- Transaction boundaries: Define where database transactions occur
- Return consistent result tuples: `{:ok, result}` or `{:error, reason}`

**Example:**
```elixir
# lib/my_app/workspaces/use_cases/use_case.ex
defmodule MyApp.Workspaces.UseCases.UseCase do
  @moduledoc """
  Behavior for use cases in the application layer.

  Use cases encapsulate business operations and orchestrate domain logic,
  infrastructure services, and side effects.
  """

  @callback execute(params :: map(), opts :: keyword()) :: {:ok, term()} | {:error, term()}
end

# lib/my_app/workspaces/use_cases/invite_member.ex
defmodule MyApp.Workspaces.UseCases.InviteMember do
  @behaviour MyApp.Workspaces.UseCases.UseCase

  alias MyApp.Workspaces.Policies.MembershipPolicy
  alias MyApp.Workspaces.Infrastructure.MembershipRepository

  @impl true
  def execute(params, opts \\ []) do
    with :ok <- validate_role(params.role),                      # Domain policy
         {:ok, workspace} <- verify_membership(...),              # Infrastructure
         :ok <- check_not_already_member(...),                   # Infrastructure
         user <- find_user(...) do                               # Infrastructure
      add_member_and_notify(workspace, user, params, opts)       # Infrastructure + side effects
    end
  end

  # Apply pure domain policy
  defp validate_role(role) do
    if MembershipPolicy.valid_invitation_role?(role) do
      :ok
    else
      {:error, :invalid_role}
    end
  end

  # Use infrastructure for data access
  defp verify_membership(inviter, workspace_id) do
    case MembershipRepository.get_workspace_for_user(inviter, workspace_id) do
      nil -> {:error, :unauthorized}
      workspace -> {:ok, workspace}
    end
  end
end
```

**Context delegates to use cases**:
```elixir
# lib/my_app/workspaces.ex
def invite_member(inviter, workspace_id, email, role, opts \\ []) do
  params = %{
    inviter: inviter,
    workspace_id: workspace_id,
    email: email,
    role: role
  }

  InviteMember.execute(params, opts)
end
```

### 8. Authorization Error Handling Pattern

Context functions should provide both safe and unsafe versions for authorization checks.

**Principles:**
- **Distinguish authorization from existence**: Return `:unauthorized` when resource exists but user lacks access, `:resource_not_found` when it doesn't exist
- **Provide both safe and unsafe versions**: Safe for user-facing operations, unsafe for system operations where access is guaranteed
- **Handle all error cases in interface**: Never let technical errors (like `Ecto.NoResultsError`) reach the user
- **Consistent error semantics**: Use atoms like `:unauthorized`, `:workspace_not_found`, `:invalid_role` for business errors
- **User-friendly messages**: Convert technical error atoms to readable flash messages in the interface layer

**Safe version** - Returns error tuples:
```elixir
# lib/my_app/workspaces.ex
@spec get_workspace(User.t(), binary()) ::
  {:ok, Workspace.t()} | {:error, :unauthorized | :workspace_not_found}
def get_workspace(%User{} = user, id) do
  # Uses infrastructure repository for data access
  case MembershipRepository.get_workspace_for_user(user, id) do
    nil ->
      if MembershipRepository.workspace_exists?(id) do
        {:error, :unauthorized}
      else
        {:error, :workspace_not_found}
      end

    workspace ->
      {:ok, workspace}
  end
end
```

**Unsafe version** - Raises on error (for cases where user must have access):
```elixir
@spec get_workspace!(User.t(), binary()) :: Workspace.t()
def get_workspace!(%User{} = user, id) do
  Queries.for_user_by_id(user, id)
  |> Repo.one!()
end
```

**Interface layer handling** - LiveViews should use safe versions and handle errors gracefully:

```elixir
# lib/my_app_web/live/app_live/workspaces/show.ex
def mount(%{"id" => workspace_id}, _session, socket) do
  user = socket.assigns.current_scope.user

  case Workspaces.get_workspace(user, workspace_id) do
    {:ok, workspace} ->
      # Load data and render page
      {:ok, assign(socket, :workspace, workspace)}

    {:error, :unauthorized} ->
      {:ok,
       socket
       |> put_flash(:error, "You don't have access to this workspace")
       |> push_navigate(to: ~p"/app/workspaces")}

    {:error, :workspace_not_found} ->
      {:ok,
       socket
       |> put_flash(:error, "Workspace not found")
       |> push_navigate(to: ~p"/app/workspaces")}
  end
end
```

**Testing authorization**:

Test authorization at three levels:

1. **Domain policy level** - Fast unit tests for business rules (no database):
```elixir
# test/my_app/workspaces/policies/membership_policy_test.exs
test "valid_invitation_role?/1 returns true for admin, member, guest" do
  assert MembershipPolicy.valid_invitation_role?(:admin)
  assert MembershipPolicy.valid_invitation_role?(:member)
  assert MembershipPolicy.valid_invitation_role?(:guest)
  refute MembershipPolicy.valid_invitation_role?(:owner)
end

test "can_change_role?/1 prevents changing owner role" do
  refute MembershipPolicy.can_change_role?(:owner)
  assert MembershipPolicy.can_change_role?(:admin)
  assert MembershipPolicy.can_change_role?(:member)
end
```

2. **Context level** - Integration tests for safe/unsafe versions (with database):
```elixir
# test/my_app/workspaces_test.exs
test "get_workspace/2 returns :unauthorized when user is not a member" do
  user = user_fixture()
  other_user = user_fixture()
  workspace = workspace_fixture(other_user)

  assert {:error, :unauthorized} = Workspaces.get_workspace(user, workspace.id)
end

test "get_workspace!/2 raises when user is not a member" do
  user = user_fixture()
  other_user = user_fixture()
  workspace = workspace_fixture(other_user)

  assert_raise Ecto.NoResultsError, fn ->
    Workspaces.get_workspace!(user, workspace.id)
  end
end
```

3. **Interface level** - End-to-end tests for user experience:
```elixir
# test/my_app_web/live/app_live/workspaces_test.exs
test "redirects with error when user is not a member of workspace" do
  user = user_fixture()
  other_user = user_fixture()
  workspace = workspace_fixture(other_user)
  conn = build_conn() |> log_in_user(user)

  {:error, {:live_redirect, %{to: path, flash: flash}}} =
    live(conn, ~p"/app/workspaces/#{workspace.id}")

  assert path == ~p"/app/workspaces"
  assert %{"error" => "You don't have access to this workspace"} = flash
end
```

### 9. Cross-Context Communication Pattern

When one context needs functionality from another, use the public API only.

**Principles:**
- Never access internal modules (Queries, Policies, Repositories) from other contexts
- Always use the context's public API
- Export only what's necessary through the context module
- Contexts are boundaries enforced by the Boundary library

**❌ BAD - Accessing internal modules**:

```elixir
# DON'T DO THIS
alias MyApp.Workspaces.Policies.Authorization, as: WorkspaceAuth

def create_project(user, workspace_id, attrs) do
  # Directly accessing internal policy module
  case WorkspaceAuth.verify_membership(user, workspace_id) do
    # ...
  end
end
```

**✅ GOOD - Using public API**:

```elixir
# lib/my_app/projects.ex
alias MyApp.Workspaces

def create_project(user, workspace_id, attrs) do
  # Call public context API
  case Workspaces.verify_membership(user, workspace_id) do
    {:ok, _workspace} ->
      # Create project
    {:error, reason} ->
      {:error, reason}
  end
end
```

The Workspaces context exposes this as a public function:

```elixir
# lib/my_app/workspaces.ex
@doc """
Verifies that a user is a member of a workspace.

This is a public API for other contexts to verify workspace membership.
"""
def verify_membership(%User{} = user, workspace_id) do
  get_workspace(user, workspace_id)
end
```

### 10. Phoenix-Specific Patterns

#### LiveView Organization

**Principles:**
- Treat LiveViews as interface adapters in the presentation layer
- LiveViews should delegate to contexts/use cases for business logic
- Keep LiveView callbacks focused on UI state management
- Use assigns for view state, not business state
- Handle events by calling context functions and updating UI accordingly

**Example:**
```elixir
defmodule MyAppWeb.OrderLive.New do
  use MyAppWeb, :live_view

  alias MyApp.Orders  # Context/Use Case

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}), errors: [])}
  end

  def handle_event("place_order", %{"order" => order_params}, socket) do
    customer_id = socket.assigns.current_user.id

    case Orders.place_order(customer_id, order_params) do
      {:ok, order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Order placed successfully")
         |> push_navigate(to: ~p"/orders/#{order.id}")}

      {:error, reason} ->
        {:noreply, assign(socket, errors: [reason])}
    end
  end
end
```

#### PubSub and Transactions

**Critical Rule:** Always broadcast AFTER transactions commit to avoid race conditions.

**Why:** If you broadcast inside a transaction, listeners may query the database before the transaction commits, seeing stale data.

**Pattern:**
```elixir
def create_order(attrs) do
  result = Repo.transaction(fn ->
    # ... database operations
    {:ok, order}
  end)

  # Broadcast AFTER transaction commits
  case result do
    {:ok, order} ->
      Phoenix.PubSub.broadcast(MyApp.PubSub, "orders", {:order_created, order})
      {:ok, order}
    error ->
      error
  end
end
```

---

## Summary

By following SOLID principles and Clean Architecture patterns:

- **Maintainability**: Code is easier to understand, modify, and extend
- **Testability**: Each component can be tested in isolation
- **Flexibility**: Easy to swap implementations and adapt to changing requirements
- **Scalability**: Clear boundaries allow teams to work independently
- **Reliability**: Business logic is protected from framework changes

**Key Takeaways:**

1. Keep business logic pure and framework-independent in the domain layer
2. Use the application layer to orchestrate complex operations
3. Isolate infrastructure concerns (database, external APIs) from business logic
4. Make the web layer thin - it should only translate between HTTP and your application
5. Depend on abstractions (behaviors/protocols) rather than concrete implementations
6. Inject dependencies to make code testable and flexible
7. Use contexts as public APIs that hide implementation details
