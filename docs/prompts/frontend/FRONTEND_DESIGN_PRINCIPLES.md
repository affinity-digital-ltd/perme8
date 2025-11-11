# Frontend Design Principles: SOLID and Clean Architecture

This document outlines the core design principles for frontend development in this project, focusing on SOLID principles and Clean Architecture patterns as they apply to TypeScript/JavaScript and Phoenix LiveView integration.

## Table of Contents

- [Technology Stack](#technology-stack)
- [SOLID Principles in TypeScript/JavaScript](#solid-principles-in-typescriptjavascript)
- [Clean Architecture for Frontend](#clean-architecture-for-frontend)
- [Best Practices](#best-practices)

---

## Technology Stack

- **TypeScript**: Type-safe JavaScript with compile-time checking
- **Vitest**: Fast unit test framework with native ESM support
- **Tailwind CSS**: Utility-first CSS framework
- **DaisyUI**: Component library built on Tailwind CSS
- **Phoenix Hooks**: JavaScript interop with Phoenix LiveView

---

## SOLID Principles in TypeScript/JavaScript

### Single Responsibility Principle (SRP)

**A function or module should have one reason to change.**

- **Functions/modules should have one reason to change**: Each module should handle one specific responsibility
- **Separate concerns**: Keep business logic, DOM manipulation, state management, and presentation separate
- **Small, focused functions**: Break complex operations into smaller, testable units

**Example:**
```typescript
// BAD - Multiple responsibilities
class UserForm {
  validateEmail(email: string): boolean {
    // Validation logic
  }

  saveToDatabase(user: User): void {
    // Database logic
  }

  updateUI(message: string): void {
    // DOM manipulation
  }
}

// GOOD - Single responsibility
class EmailValidator {
  validate(email: string): boolean {
    // Only validation logic
  }
}

class UserRepository {
  save(user: User): Promise<void> {
    // Only database operations
  }
}

class UserFormUI {
  showMessage(message: string): void {
    // Only DOM manipulation
  }
}
```

### Open/Closed Principle (OCP)

**Software entities should be open for extension but closed for modification.**

- **Use interfaces and abstractions**: Design for extension through TypeScript interfaces and abstract classes
- **Composition over inheritance**: Prefer composing behavior from smaller units
- **Plugin patterns**: Use hooks and callbacks for extensibility

**Example:**
```typescript
// Using interfaces for extension
interface PaymentProcessor {
  process(amount: number): Promise<PaymentResult>
}

class StripeProcessor implements PaymentProcessor {
  async process(amount: number): Promise<PaymentResult> {
    // Stripe-specific implementation
  }
}

class PayPalProcessor implements PaymentProcessor {
  async process(amount: number): Promise<PaymentResult> {
    // PayPal-specific implementation
  }
}

// Client code doesn't need to change when adding new processors
class CheckoutService {
  constructor(private processor: PaymentProcessor) {}

  async checkout(amount: number): Promise<void> {
    const result = await this.processor.process(amount)
    // Handle result
  }
}
```

### Liskov Substitution Principle (LSP)

**Objects should be replaceable with instances of their subtypes without altering correctness.**

- **Interfaces must be reliable**: Any implementation of an interface should be substitutable
- **Consistent contracts**: Functions implementing the same interface should behave consistently
- **Type safety**: Use TypeScript to enforce contracts at compile time

**Example:**
```typescript
// All implementations must maintain the same contract
interface Storage {
  save(key: string, value: string): Promise<void>
  load(key: string): Promise<string | null>
}

class LocalStorageAdapter implements Storage {
  async save(key: string, value: string): Promise<void> {
    localStorage.setItem(key, value)
  }

  async load(key: string): Promise<string | null> {
    return localStorage.getItem(key)
  }
}

class SessionStorageAdapter implements Storage {
  async save(key: string, value: string): Promise<void> {
    sessionStorage.setItem(key, value)
  }

  async load(key: string): Promise<string | null> {
    return sessionStorage.getItem(key)
  }
}

// Both implementations are substitutable
function useStorage(storage: Storage) {
  // Works with any Storage implementation
}
```

### Interface Segregation Principle (ISP)

**Clients should not be forced to depend on interfaces they don't use.**

- **Small, focused interfaces**: Create minimal interfaces with only necessary methods
- **Avoid fat interfaces**: Don't force clients to depend on methods they don't use
- **Role-based interfaces**: Design interfaces around specific client needs

**Example:**
```typescript
// BAD - Fat interface
interface DataService {
  read(id: string): Promise<Data>
  write(data: Data): Promise<void>
  delete(id: string): Promise<void>
  subscribe(callback: (data: Data) => void): void
  unsubscribe(): void
}

// GOOD - Segregated interfaces
interface Readable {
  read(id: string): Promise<Data>
}

interface Writable {
  write(data: Data): Promise<void>
  delete(id: string): Promise<void>
}

interface Observable {
  subscribe(callback: (data: Data) => void): void
  unsubscribe(): void
}

// Clients only depend on what they need
class ReadOnlyViewer {
  constructor(private service: Readable) {}
}

class Editor {
  constructor(private service: Readable & Writable) {}
}
```

### Dependency Inversion Principle (DIP)

**Depend on abstractions, not concretions.**

- **Depend on abstractions**: Use interfaces instead of concrete implementations
- **Inject dependencies**: Pass dependencies as function arguments or constructor parameters
- **Use dependency injection**: Make code testable by injecting dependencies

**Example:**
```typescript
// BAD - Depends on concrete implementation
class OrderProcessor {
  process(order: Order): void {
    const stripe = new StripeClient()  // Tightly coupled
    stripe.charge(order.amount)
  }
}

// GOOD - Depends on abstraction
interface PaymentClient {
  charge(amount: number): Promise<void>
}

class OrderProcessor {
  constructor(private paymentClient: PaymentClient) {}

  async process(order: Order): Promise<void> {
    await this.paymentClient.charge(order.amount)
  }
}

// Easy to test with mocks
const mockPayment: PaymentClient = {
  charge: async (amount) => { /* mock implementation */ }
}
const processor = new OrderProcessor(mockPayment)
```

---

## Clean Architecture for Frontend

Clean Architecture organizes frontend code into layers with clear dependencies, keeping business logic pure and framework-agnostic.

### Layer Structure

```
assets/
├── js/
│   ├── domain/              # Domain Layer (Business Logic)
│   │   ├── entities/        # Pure business objects
│   │   ├── value-objects/   # Immutable value types
│   │   └── policies/        # Business rules and validation
│   ├── application/         # Application Layer (Use Cases)
│   │   └── use-cases/       # Application-specific operations
│   ├── infrastructure/      # Infrastructure Layer
│   │   ├── api/             # HTTP clients, API adapters
│   │   ├── storage/         # LocalStorage, SessionStorage
│   │   └── events/          # Event emitters, observers
│   ├── presentation/        # Presentation Layer
│   │   ├── hooks/           # Phoenix LiveView hooks
│   │   ├── components/      # Reusable UI components
│   │   └── utils/           # DOM utilities, formatters
│   ├── app.js               # Application entry point
│   └── app.d.ts             # Global type definitions
├── css/
│   ├── app.css              # Main stylesheet (Tailwind imports)
│   └── components/          # Component-specific styles
└── vendor/                  # Third-party libraries
```

### Dependency Rule

**Dependencies should point inward only:**

```
Presentation Layer (Hooks, UI) → Application Layer (Use Cases) → Domain Layer (Business Logic)
                               ↘ Infrastructure Layer (API, Storage)
```

- Outer layers depend on inner layers
- Inner layers never depend on outer layers
- Domain layer has no dependencies on frameworks or external libraries

### Architecture Guidelines

#### 1. Domain Layer (Pure JavaScript)

The innermost layer containing pure business logic.

**Characteristics:**
- **No framework dependencies**: Pure TypeScript/JavaScript with no Phoenix, DOM, or external dependencies
- **Testable business logic**: All business rules should be unit testable in isolation
- **Immutable data**: Prefer immutable operations and functional patterns

**Example:**
```typescript
// domain/entities/cart.ts
export class ShoppingCart {
  constructor(
    public readonly items: CartItem[],
    public readonly discount: number = 0
  ) {}

  // Pure business logic - no side effects
  addItem(item: CartItem): ShoppingCart {
    return new ShoppingCart([...this.items, item], this.discount)
  }

  calculateTotal(): number {
    const subtotal = this.items.reduce(
      (sum, item) => sum + item.price * item.quantity,
      0
    )
    return subtotal * (1 - this.discount)
  }

  canCheckout(): boolean {
    return this.items.length > 0 && this.calculateTotal() > 0
  }
}
```

#### 2. Application Layer (Use Cases)

Orchestrates business logic and handles application-specific operations.

**Characteristics:**
- **Orchestrates domain and infrastructure**: Coordinates business logic with external services
- **Side effect management**: Centralizes async operations, API calls, and state changes
- **One use case per operation**: Each use case handles a single business operation

**Example:**
```typescript
// application/use-cases/add-to-cart.ts
import { ShoppingCart } from '../../domain/entities/cart'
import { CartRepository } from '../../infrastructure/storage/cart-repository'

export class AddToCart {
  constructor(private repository: CartRepository) {}

  async execute(productId: string, quantity: number): Promise<void> {
    // Load current cart
    const cart = await this.repository.load()

    // Apply domain logic
    const item = { productId, quantity, price: await this.getPrice(productId) }
    const updatedCart = cart.addItem(item)

    // Persist changes
    await this.repository.save(updatedCart)
  }

  private async getPrice(productId: string): Promise<number> {
    // Fetch price from infrastructure layer
  }
}
```

#### 3. Infrastructure Layer

Handles technical details like API calls, storage, and external services.

**Characteristics:**
- **External integrations**: API clients, browser storage, Phoenix channels
- **Keep separate from domain**: Infrastructure should depend on domain, not vice versa
- **Adapter pattern**: Wrap external services behind interfaces

**Example:**
```typescript
// infrastructure/storage/cart-repository.ts
import { ShoppingCart } from '../../domain/entities/cart'

export interface CartRepository {
  load(): Promise<ShoppingCart>
  save(cart: ShoppingCart): Promise<void>
}

export class LocalStorageCartRepository implements CartRepository {
  private readonly key = 'shopping-cart'

  async load(): Promise<ShoppingCart> {
    const data = localStorage.getItem(this.key)
    if (!data) return new ShoppingCart([])

    const parsed = JSON.parse(data)
    return new ShoppingCart(parsed.items, parsed.discount)
  }

  async save(cart: ShoppingCart): Promise<void> {
    const data = JSON.stringify({
      items: cart.items,
      discount: cart.discount
    })
    localStorage.setItem(this.key, data)
  }
}
```

#### 4. Presentation Layer (Phoenix Hooks & UI)

Handles user interactions and LiveView integration.

**Characteristics:**
- **Thin hooks**: Phoenix hooks should only handle LiveView interop, delegate to use cases
- **No business logic**: Keep hooks focused on DOM manipulation and event handling
- **Declarative when possible**: Use data attributes and CSS for behavior when suitable

**Example:**
```typescript
// presentation/hooks/cart-updater.ts
import { AddToCart } from '../../application/use-cases/add-to-cart'
import { LocalStorageCartRepository } from '../../infrastructure/storage/cart-repository'

export class CartUpdater {
  private useCase: AddToCart

  mounted() {
    const repository = new LocalStorageCartRepository()
    this.useCase = new AddToCart(repository)

    this.el.addEventListener('click', this.handleAddToCart)
  }

  handleAddToCart = async (event: Event) => {
    const button = event.target as HTMLButtonElement
    const productId = button.dataset.productId!
    const quantity = parseInt(button.dataset.quantity || '1')

    try {
      // Delegate to use case
      await this.useCase.execute(productId, quantity)

      // Update UI
      this.showSuccess()

      // Notify LiveView server
      this.pushEvent('cart-updated', { productId, quantity })
    } catch (error) {
      this.showError(error)
    }
  }

  showSuccess(): void {
    // Update DOM to show success message
  }

  showError(error: Error): void {
    // Update DOM to show error message
  }

  destroyed() {
    this.el.removeEventListener('click', this.handleAddToCart)
  }
}
```

---

## Best Practices

### 1. TypeScript Type Safety

Leverage TypeScript's type system for compile-time safety.

**Principles:**
- **Enable strict mode**: Use `"strict": true` in `tsconfig.json`
- **Avoid `any`**: Use proper types or `unknown` if truly needed
- **Define interfaces**: Create interfaces for all data structures
- **Use type guards**: Implement runtime type checking when needed

**Example:**
```typescript
// Good: Strict typing
interface UserProfile {
  id: string
  email: string
  name: string
}

type ValidationResult =
  | { valid: true; data: UserProfile }
  | { valid: false; errors: string[] }

function validateUser(data: unknown): ValidationResult {
  // Type guard
  if (!isValidUserData(data)) {
    return { valid: false, errors: ['Invalid user data'] }
  }

  return { valid: true, data }
}

function isValidUserData(data: unknown): data is UserProfile {
  return (
    typeof data === 'object' &&
    data !== null &&
    'id' in data &&
    'email' in data &&
    'name' in data
  )
}
```

### 2. Phoenix Hook Patterns

Keep Phoenix hooks thin and focused on interop.

**Principles:**
- **Delegate to use cases**: Hooks should call application layer functions
- **No business logic**: Keep hooks focused on DOM and LiveView interop
- **Clean up**: Always implement `destroyed()` to clean up listeners/timers
- **Type safe**: Use TypeScript interfaces for hook data

**Example:**
```typescript
// Good: Hook delegates to use case
import { validateForm } from '../../application/use-cases/validate-form'

export class FormValidator {
  mounted() {
    this.el.addEventListener('input', this.handleInput)
  }

  handleInput = (event: Event) => {
    const input = event.target as HTMLInputElement
    const result = validateForm(input.value) // Delegate to use case
    this.updateUI(result)
  }

  updateUI(result: ValidationResult) {
    // Update DOM based on result
    if (result.valid) {
      this.el.classList.remove('error')
      this.el.classList.add('success')
    } else {
      this.el.classList.remove('success')
      this.el.classList.add('error')
    }
  }

  destroyed() {
    this.el.removeEventListener('input', this.handleInput)
  }
}
```

### 3. Dependency Injection for Testability

Make code testable by injecting dependencies.

**Techniques:**
- Pass dependencies as constructor arguments or function parameters
- Provide default implementations while allowing overrides for testing
- Use interfaces to define contracts

**Example:**
```typescript
// Production code
class UserService {
  constructor(
    private api: ApiClient = new HttpApiClient(),
    private cache: Cache = new LocalStorageCache()
  ) {}

  async getUser(id: string): Promise<User> {
    const cached = await this.cache.get(id)
    if (cached) return cached

    const user = await this.api.fetch(`/users/${id}`)
    await this.cache.set(id, user)
    return user
  }
}

// Test code
const mockApi: ApiClient = {
  fetch: async (url) => ({ id: '1', name: 'Test User' })
}

const mockCache: Cache = {
  get: async (key) => null,
  set: async (key, value) => {}
}

const service = new UserService(mockApi, mockCache)
```

### 4. Immutable Data Patterns

Prefer immutable operations for predictable behavior.

**Principles:**
- Use `const` for all variables that don't need reassignment
- Return new objects instead of mutating existing ones
- Use spread operators for copying objects/arrays
- Consider using libraries like Immer for complex state

**Example:**
```typescript
// Good: Immutable operations
class TodoList {
  constructor(public readonly items: Todo[]) {}

  addTodo(todo: Todo): TodoList {
    return new TodoList([...this.items, todo])
  }

  toggleTodo(id: string): TodoList {
    const items = this.items.map(item =>
      item.id === id
        ? { ...item, completed: !item.completed }
        : item
    )
    return new TodoList(items)
  }

  removeTodo(id: string): TodoList {
    const items = this.items.filter(item => item.id !== id)
    return new TodoList(items)
  }
}
```

### 5. Tailwind CSS Organization

Use Tailwind utilities effectively and consistently.

**Principles:**
- **Utility-first**: Use Tailwind utility classes for styling
- **Component extraction**: Extract repeated patterns into components (3+ occurrences)
- **DaisyUI integration**: Use DaisyUI components when appropriate
- **Responsive design**: Use responsive modifiers (`sm:`, `md:`, `lg:`, etc.)
- **Dark mode support**: Use `dark:` modifier for dark mode variants

**Example:**
```html
<!-- Good: Organized Tailwind classes -->
<!-- Group logically: layout, spacing, colors, typography, states -->
<div class="
  flex items-center justify-between
  p-4 space-x-2
  bg-white dark:bg-gray-800
  text-gray-900 dark:text-gray-100
  hover:bg-gray-50 dark:hover:bg-gray-700
  rounded-lg shadow-md
">
  <span class="font-semibold">Item</span>
  <button class="btn btn-primary">Action</button>
</div>
```

**Avoid:**
```html
<!-- Bad: Inline styles -->
<div style="margin-top: 20px; color: blue;">

<!-- Bad: Custom CSS classes -->
<style>
.my-button {
  @apply bg-blue-500 text-white px-4 py-2 rounded;
}
</style>

<!-- Bad: Arbitrary values -->
<div class="p-[13px] text-[#1a2b3c]">
```

### 6. Module Organization

Keep code organized and maintainable.

**Principles:**
- Use named exports for better refactoring
- Group imports: external, internal, types
- Use kebab-case for file names
- Collocate tests with source files

**Example:**
```typescript
// Good: Organized imports
import { describe, test, expect } from 'vitest'

import { validateEmail } from '../domain/validators'
import { FormData } from '../types'

import type { ValidationResult } from '../types'

// Good: Named exports
export { validateEmail } from './email-validator'
export { processForm } from './form-processor'

// Avoid: Default exports (harder to refactor)
// export default validateEmail
```

### 7. LiveView Event Handling

Communicate effectively between client and server.

**Pattern:**
```typescript
// Push events to LiveView server
this.pushEvent('item-updated', {
  id: 123,
  value: 'new value'
})

// Handle events from LiveView server
this.handleEvent('update-chart', (payload) => {
  // Update client-side state or DOM
  updateChart(payload.data)
})
```

### 8. LiveView Streams Integration

When working with LiveView streams from the client side, understand the critical limitations.

#### Streams and Conditional Rendering

**⚠️ CRITICAL LIMITATION**: Streams do NOT work inside conditional rendering blocks.

**❌ WRONG - Stream inside conditional**:
```heex
<%= if @show_dropdown do %>
  <div id="notifications" phx-update="stream">
    <div :for={{id, item} <- @streams.notifications} id={id}>
      {item.text}
    </div>
  </div>
<% end %>
```

This appears to compile but **stream items will not render**. Phoenix LiveView cannot properly track stream changes when the parent element is conditionally rendered.

**✅ CORRECT - CSS-based visibility**:
```heex
<div
  id="notifications-dropdown"
  class={"#{if !@show_dropdown, do: "hidden"}"}
>
  <div id="notifications" phx-update="stream">
    <div :for={{id, item} <- @streams.notifications} id={id}>
      {item.text}
    </div>
  </div>
</div>
```

**Solution**: Use CSS to show/hide the container instead of conditional rendering:
- Keep the stream container always in the DOM
- Use `hidden` class or similar to toggle visibility
- Stream updates work correctly because the element always exists

**Why this happens**:
- Streams require a stable DOM element with `phx-update="stream"`
- Conditional rendering removes/adds the element from the DOM tree
- LiveView loses track of the stream's state when the parent is removed
- This is a known limitation of Phoenix LiveView streams

#### Empty States with Streams

Use Tailwind's `only:` pseudo-class for empty states:

```heex
<div id="items" phx-update="stream">
  <div id="items-empty-state" class="hidden only:block">
    No items yet
  </div>
  <div :for={{id, item} <- @streams.items} id={id}>
    {item.name}
  </div>
</div>
```

The `only:` selector displays the empty state only when it's the only child of the stream container.

#### Client-Side Hooks with Streams

When implementing hooks that interact with stream elements:

**Principles:**
- Always account for elements being added/removed dynamically
- Use event delegation on the stream container
- Don't cache references to stream elements
- Listen for `phx:update` events to detect stream changes

**Example:**
```typescript
// Good: Event delegation for stream items
export class StreamInteractionHook {
  mounted() {
    // Delegate to the stream container
    this.el.addEventListener('click', this.handleClick)
  }

  handleClick = (event: Event) => {
    const target = event.target as HTMLElement
    const streamItem = target.closest('[id^="items-"]')

    if (streamItem) {
      // Handle interaction with stream item
      const itemId = streamItem.id.replace('items-', '')
      this.processItem(itemId)
    }
  }

  destroyed() {
    this.el.removeEventListener('click', this.handleClick)
  }
}
```

---

## Summary

By following SOLID principles and Clean Architecture patterns in frontend code:

- **Maintainability**: Code is easier to understand, modify, and extend
- **Testability**: Each component can be tested in isolation
- **Type Safety**: TypeScript catches errors at compile time
- **Framework Independence**: Business logic is independent of Phoenix/LiveView
- **Performance**: Clean separation enables better optimization

**Key Takeaways:**

1. Keep business logic pure in the domain layer (no DOM, no frameworks)
2. Use the application layer to orchestrate operations and handle side effects
3. Isolate infrastructure concerns (API, storage) from business logic
4. Make the presentation layer (hooks) thin - only DOM and LiveView interop
5. Depend on abstractions (interfaces) rather than concrete implementations
6. Inject dependencies to make code testable and flexible
7. Use TypeScript's type system for safety and better tooling
8. Leverage Tailwind utilities for consistent, maintainable styling
