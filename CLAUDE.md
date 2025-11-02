# CLAUDE.md

This file provides guidance to Claude Code when working with Elixir and Phoenix code in this repository.

## Core Principles

### SOLID Principles in Elixir/Phoenix

#### Single Responsibility Principle (SRP)

- **Modules should have one reason to change**: Each module should handle one specific domain concept or responsibility
- **Separate concerns**: Keep business logic, data access, validation, and presentation separate

#### Open/Closed Principle (OCP)

- **Use behaviors and protocols**: Design for extension through protocols and behaviors rather than modification
- **Pattern matching for extensibility**: Leverage Elixir's pattern matching to add new cases without modifying existing code

#### Liskov Substitution Principle (LSP)

- **Behaviors must be reliable**: Any module implementing a behavior should be substitutable without breaking functionality
- **Protocol implementations**: Ensure protocol implementations maintain expected contracts
- **Consistent return types**: Functions implementing the same behavior should return consistent data structures

#### Interface Segregation Principle (ISP)

- **Small, focused behaviors**: Create small behaviors with minimal required callbacks
- **Context-specific APIs**: Design context modules with focused public APIs

#### Dependency Inversion Principle (DIP)

- **Depend on abstractions**: Use behaviors and protocols instead of concrete implementations
- **Inject dependencies**: Pass dependencies as function arguments or use application config

## Clean Architecture for Phoenix

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

### Architecture Guidelines

#### 1. Domain Layer (Core Business Logic)

- **Pure business logic**: No dependencies on Phoenix, Ecto, or external frameworks
- **Domain entities**: Represent core business concepts
- **Value objects**: Immutable types representing domain values

#### 2. Application Layer (Use Cases)

- **Orchestrates domain logic**: Coordinates domain entities and infrastructure
- **Transaction boundaries**: Defines where database transactions occur

#### 3. Infrastructure Layer

- **Data persistence**: Ecto schemas, repos, and queries
- **External integrations**: API clients, message queues
- **Keep separate from domain**: Infrastructure should depend on domain, not vice versa

#### 4. Interface Layer (Phoenix Web)

- **Thin controllers**: Controllers only handle HTTP concerns (parsing, validation, rendering)
- **Delegate to use cases**: Business logic lives in application layer

### Context Organization

#### Phoenix Contexts as Application Boundaries

- **Contexts represent business domains**: Each context encapsulates a specific area of the business
- **Public API only**: Only expose necessary functions through context module

## Best Practices

### 1. Separation of Ecto Schemas and Domain Logic

- Keep Ecto schemas in the infrastructure layer for data persistence
- Keep domain logic in separate domain modules
- Use changesets only for data validation, not business rules
- Domain entities should not depend on Ecto

### 2. Dependency Injection Patterns

- Use application config for swappable dependencies at compile time
- Pass dependencies explicitly as function arguments for runtime flexibility
- Provide default implementations while allowing overrides for testing
- Use keyword lists for multiple optional dependencies

### 3. Use Cases Pattern

- Create a behavior for standardized use case interface
- Each use case implements a single business operation
- Use cases orchestrate domain logic and infrastructure
- Return consistent result tuples: `{:ok, result}` or `{:error, reason}`
- Accept dependencies as keyword arguments for testability

### 4. Query Objects

- Extract complex queries into dedicated query modules
- Keep repositories thin by delegating to query objects
- Make queries composable and reusable
- Organize queries by domain entity
- Query modules return Ecto queryables, not results

### 5. Testing Strategy

- **Domain layer**: Unit tests without database, pure logic testing
- **Application layer**: Test use cases with mocked dependencies using Mox
- **Infrastructure layer**: Integration tests with database
- **Interface layer**: Controller/LiveView tests using ConnCase
- Keep tests fast by testing at the appropriate layer
- Use dependency injection to make tests deterministic

## Anti-Patterns to Avoid

### 1. Fat Contexts

- **Problem**: Context modules that contain dozens of functions handling many different concerns
- **Solution**: Split large contexts into smaller, focused modules using use cases
- Delegate from context to specific use case modules
- Separate cross-cutting concerns (like notifications) into their own contexts

### 2. Business Logic in Controllers

- **Problem**: Controllers containing business rules, database operations, and complex logic
- **Solution**: Controllers should only handle HTTP concerns (parsing, validation, rendering)
- Move all business logic to use cases or contexts
- Controllers delegate to the application layer
- Keep controllers thin and focused on request/response handling

### 3. Mixing Concerns in Schemas

- **Problem**: Ecto schemas containing business logic, external service calls, and complex operations
- **Solution**: Schemas should only define data structure and simple validations
- Move business logic to domain modules
- Move orchestration to use cases
- Move external service calls to dedicated service modules
- Keep schemas focused on data persistence concerns only

## Phoenix-Specific Guidelines

### LiveView Organization

- Treat LiveViews as interface adapters in the presentation layer
- LiveViews should delegate to contexts/use cases for business logic
- Keep LiveView callbacks focused on UI state management
- Use assigns for view state, not business state
- Handle events by calling context functions and updating UI accordingly

### Channel Organization

- Treat channels as interface adapters for WebSocket communication
- Channels should delegate to contexts/use cases for business operations
- Keep join/handle_in callbacks focused on message handling
- Use socket assigns for connection state
- Broadcast events after successful business operations

## Additional Resources

- Phoenix Contexts Guide: <https://hexdocs.pm/phoenix/contexts.html>
- Elixir Protocols: <https://elixir-lang.org/getting-started/protocols.html>
- Ecto Best Practices: <https://hexdocs.pm/ecto/Ecto.html>
