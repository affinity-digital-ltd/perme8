# Full Stack Test-Driven Development (TDD)

**This project follows a strict Test-Driven Development approach for both backend (Phoenix/Elixir) and frontend (TypeScript/JavaScript) code.**

## Overview

Test-Driven Development is a software development methodology where tests are written before implementation code. This ensures better designed, more testable code with complete test coverage, living documentation, confidence in refactoring, and fewer bugs in production.

This document covers TDD practices for the entire stack:
- **Backend**: Phoenix, Elixir, Ecto
- **Frontend**: TypeScript, Vitest, Phoenix Hooks
- **Integration**: LiveView, Channels, end-to-end flows

---

## Table of Contents

- [The TDD Cycle](#the-tdd-cycle-red-green-refactor)
- [TDD Best Practices](#tdd-best-practices)
- [Backend Testing Strategy](#backend-testing-strategy)
- [Frontend Testing Strategy](#frontend-testing-strategy)
- [Full Stack Integration Testing](#full-stack-integration-testing)
- [Test Organization](#test-organization)
- [Running Tests](#running-tests)
- [Benefits of TDD](#benefits-of-tdd)

---

## The TDD Cycle: Red-Green-Refactor

Follow this cycle for **all** new code, both backend and frontend:

### 1. Red: Write a Failing Test

- Start by writing a test that describes the desired behavior
- Run the test and confirm it fails (RED)
- The test should fail for the right reason (e.g., function doesn't exist, wrong behavior)

### 2. Green: Make the Test Pass

- Write the minimal code needed to make the test pass
- Don't worry about perfect design at this stage
- Focus on making the test GREEN as quickly as possible

### 3. Refactor: Improve the Code

- Clean up the code while keeping tests green
- Apply SOLID principles and design patterns
- Remove duplication and improve naming
- Tests provide safety net for refactoring

---

## TDD Best Practices

These principles apply to both backend and frontend code:

### Always Write Tests First

- **Before writing any production code**, write the test
- Resist the temptation to write code first and test later
- Tests written first are better designed and more focused

### Start with the Simplest Test

- Begin with the easiest case (happy path)
- Add edge cases and error cases incrementally
- Build complexity gradually

### One Test at a Time

- Write one test, make it pass, then write the next
- Don't write multiple failing tests at once
- Commit after each green cycle if possible

### Test Behavior, Not Implementation

- Focus on **what** the code should do, not **how**
- Tests should not break when refactoring internal implementation
- Test the public API, not private functions

### Keep Tests Fast

- Domain tests should run in milliseconds (no I/O)
- Use mocks/stubs for external dependencies
- Reserve integration tests for critical paths only
- Fast tests encourage running them frequently

### Make Tests Readable

- Use descriptive test names that explain the scenario
- Follow Arrange-Act-Assert pattern
- One assertion per test when possible
- Use setup blocks to reduce duplication

---

## Backend Testing Strategy

### Test Pyramid

Follow the test pyramid - more tests at the bottom, fewer at the top:

```
        /\
       /  \      Few: UI/Integration Tests (LiveView)
      /----\
     /      \    More: Use Case Tests
    /--------\
   /          \  Most: Domain Tests (Fast, Pure Logic)
  /------------\
```

### Testing by Layer (TDD Order)

#### 1. Domain Layer (Start Here)

**Pure business logic with no dependencies on Phoenix, Ecto, or external frameworks.**

- Write tests first using `ExUnit.Case`
- No database, no external dependencies
- Pure logic testing - fastest tests
- Tests should run in milliseconds
- Test edge cases and business rules thoroughly

**Example:**
```elixir
# test/my_app/domain/shipping_calculator_test.exs
defmodule MyApp.Domain.ShippingCalculatorTest do
  use ExUnit.Case, async: true

  alias MyApp.Domain.ShippingCalculator

  describe "calculate/2" do
    test "calculates shipping for 5kg over 100km" do
      assert {:ok, cost} = ShippingCalculator.calculate(5, 100)
      assert cost == 50.0
    end

    test "returns error for negative weight" do
      assert {:error, :invalid_weight} = ShippingCalculator.calculate(-1, 100)
    end

    test "returns error for zero distance" do
      assert {:error, :invalid_distance} = ShippingCalculator.calculate(5, 0)
    end

    test "applies distance multiplier correctly" do
      assert {:ok, cost} = ShippingCalculator.calculate(10, 50)
      assert cost == 25.0  # 10kg * 50km * 0.05
    end
  end
end
```

**Implementation:**
```elixir
# lib/my_app/domain/shipping_calculator.ex
defmodule MyApp.Domain.ShippingCalculator do
  @moduledoc """
  Pure business logic for calculating shipping costs.
  No dependencies on Ecto, Phoenix, or external services.
  """

  @rate_per_kg_per_km 0.05

  @doc """
  Calculates shipping cost based on weight (kg) and distance (km).
  """
  def calculate(weight, distance) when weight <= 0, do: {:error, :invalid_weight}
  def calculate(weight, distance) when distance <= 0, do: {:error, :invalid_distance}

  def calculate(weight, distance) do
    cost = weight * distance * @rate_per_kg_per_km
    {:ok, cost}
  end
end
```

#### 2. Application Layer (Use Cases)

**Orchestrates business logic and handles transactions.**

- Write tests first using `MyApp.DataCase`
- Use Mox for external dependencies
- Test orchestration and workflows
- Mock infrastructure services
- Test transaction boundaries

**Example:**
```elixir
# test/my_app/application/calculate_shipping_test.exs
defmodule MyApp.Application.CalculateShippingTest do
  use MyApp.DataCase, async: true

  import Mox

  alias MyApp.Application.CalculateShipping
  alias MyApp.Accounts.User

  setup :verify_on_exit!

  describe "execute/2" do
    test "calculates shipping and applies user discount" do
      user = insert(:user, discount: 0.1)

      assert {:ok, %{cost: cost}} =
        CalculateShipping.execute(user.id, weight: 5, distance: 100)

      assert cost == 22.5  # (5 * 100 * 0.05) * 0.9
    end

    test "returns error when user not found" do
      assert {:error, :user_not_found} =
        CalculateShipping.execute(999, weight: 5, distance: 100)
    end

    test "saves shipment record on success" do
      user = insert(:user)

      assert {:ok, result} =
        CalculateShipping.execute(user.id, weight: 5, distance: 100)

      assert result.shipment_id
      shipment = Repo.get(Shipment, result.shipment_id)
      assert shipment.weight == 5
    end

    test "does not save shipment when calculation fails" do
      user = insert(:user)

      assert {:error, _} =
        CalculateShipping.execute(user.id, weight: -1, distance: 100)

      assert Repo.aggregate(Shipment, :count) == 0
    end
  end
end
```

**Implementation:**
```elixir
# lib/my_app/application/calculate_shipping.ex
defmodule MyApp.Application.CalculateShipping do
  @moduledoc """
  Use case for calculating shipping costs with user discounts.
  Orchestrates domain logic and infrastructure.
  """

  alias MyApp.Domain.ShippingCalculator
  alias MyApp.Repo
  alias MyApp.Accounts.User
  alias MyApp.Shipping.Shipment

  def execute(user_id, opts) do
    weight = Keyword.fetch!(opts, :weight)
    distance = Keyword.fetch!(opts, :distance)

    with {:ok, user} <- fetch_user(user_id),
         {:ok, base_cost} <- ShippingCalculator.calculate(weight, distance),
         final_cost <- apply_discount(base_cost, user.discount),
         {:ok, shipment} <- create_shipment(user_id, weight, distance, final_cost) do
      {:ok, %{cost: final_cost, shipment_id: shipment.id}}
    end
  end

  defp fetch_user(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp apply_discount(cost, discount) do
    cost * (1 - discount)
  end

  defp create_shipment(user_id, weight, distance, cost) do
    %Shipment{}
    |> Shipment.changeset(%{
      user_id: user_id,
      weight: weight,
      distance: distance,
      cost: cost
    })
    |> Repo.insert()
  end
end
```

#### 3. Infrastructure Layer

**Data persistence, queries, and external integrations.**

- Write tests first using `MyApp.DataCase`
- Integration tests with real database
- Test queries, repos, and external services
- Use database sandbox for isolation
- Keep these tests fast but thorough

**Example:**
```elixir
# test/my_app/shipping/queries_test.exs
defmodule MyApp.Shipping.QueriesTest do
  use MyApp.DataCase, async: true

  alias MyApp.Shipping.Queries
  alias MyApp.Shipping.Shipment

  describe "for_user/1" do
    test "returns shipments for specific user" do
      user1 = insert(:user)
      user2 = insert(:user)

      shipment1 = insert(:shipment, user_id: user1.id)
      shipment2 = insert(:shipment, user_id: user1.id)
      _shipment3 = insert(:shipment, user_id: user2.id)

      results =
        Shipment
        |> Queries.for_user(user1.id)
        |> Repo.all()

      assert length(results) == 2
      assert shipment1 in results
      assert shipment2 in results
    end
  end

  describe "recent/1" do
    test "returns shipments ordered by most recent" do
      old = insert(:shipment, inserted_at: ~N[2024-01-01 00:00:00])
      new = insert(:shipment, inserted_at: ~N[2024-01-02 00:00:00])

      results =
        Shipment
        |> Queries.recent()
        |> Repo.all()

      assert [^new, ^old] = results
    end

    test "limits results to specified count" do
      insert_list(5, :shipment)

      results =
        Shipment
        |> Queries.recent(3)
        |> Repo.all()

      assert length(results) == 3
    end
  end
end
```

#### 4. Interface Layer (LiveView/Controllers)

**HTTP concerns, rendering, and user interactions.**

- Write tests first using `MyAppWeb.ConnCase`
- Test controllers and LiveViews
- Test HTTP concerns (status, redirects, rendering)
- Mock or use test doubles for business logic
- Focus on user interactions and UI state

**Example:**
```elixir
# test/my_app_web/live/shipping_live_test.exs
defmodule MyAppWeb.ShippingLiveTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "shipping calculator page" do
    test "displays form on mount", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/shipping")

      assert html =~ "Calculate Shipping"
      assert has_element?(view, "#shipping-form")
    end

    test "calculates and displays shipping cost", %{conn: conn} do
      user = insert(:user, discount: 0)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/shipping")

      view
      |> form("#shipping-form", %{weight: "5", distance: "100"})
      |> render_submit()

      assert render(view) =~ "Cost: $25.00"
    end

    test "shows error for invalid input", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/shipping")

      view
      |> form("#shipping-form", %{weight: "-1", distance: "100"})
      |> render_submit()

      assert render(view) =~ "Invalid weight"
    end

    test "updates shipment history after calculation", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/shipping")

      view
      |> form("#shipping-form", %{weight: "5", distance: "100"})
      |> render_submit()

      assert has_element?(view, "#shipment-history")
      assert render(view) =~ "5 kg"
      assert render(view) =~ "100 km"
    end
  end
end
```

---

## Frontend Testing Strategy

### Test Pyramid

```
        /\
       /  \      Few: E2E/Integration Tests
      /----\
     /      \    More: Hook/Component Tests
    /--------\
   /          \  Most: Domain/Use Case Tests (Fast, Pure)
  /------------\
```

### Testing by Layer (TDD Order)

#### 1. Domain Layer (Pure JavaScript)

**Pure business logic with no dependencies on DOM, Phoenix, or external libraries.**

- Write tests first using Vitest
- No DOM, no external dependencies, no side effects
- Pure logic testing - fastest tests
- Tests should run in milliseconds
- Test edge cases and business rules thoroughly

**Example:**
```typescript
// assets/js/domain/entities/shopping-cart.test.ts
import { describe, test, expect } from 'vitest'
import { ShoppingCart } from './shopping-cart'

describe('ShoppingCart', () => {
  describe('addItem', () => {
    test('adds item to empty cart', () => {
      const cart = new ShoppingCart([])
      const item = { id: '1', name: 'Product', price: 10, quantity: 1 }

      const updatedCart = cart.addItem(item)

      expect(updatedCart.items).toHaveLength(1)
      expect(updatedCart.items[0]).toEqual(item)
    })

    test('returns new cart instance (immutability)', () => {
      const cart = new ShoppingCart([])
      const item = { id: '1', name: 'Product', price: 10, quantity: 1 }

      const updatedCart = cart.addItem(item)

      expect(updatedCart).not.toBe(cart)
      expect(cart.items).toHaveLength(0)
    })

    test('throws error for negative quantity', () => {
      const cart = new ShoppingCart([])
      const item = { id: '1', name: 'Product', price: 10, quantity: -1 }

      expect(() => cart.addItem(item)).toThrow('Quantity must be positive')
    })
  })

  describe('calculateTotal', () => {
    test('calculates total for multiple items', () => {
      const items = [
        { id: '1', name: 'Product A', price: 10, quantity: 2 },
        { id: '2', name: 'Product B', price: 15, quantity: 1 }
      ]
      const cart = new ShoppingCart(items)

      expect(cart.calculateTotal()).toBe(35)
    })

    test('applies discount to total', () => {
      const items = [{ id: '1', name: 'Product', price: 100, quantity: 1 }]
      const cart = new ShoppingCart(items, 0.1) // 10% discount

      expect(cart.calculateTotal()).toBe(90)
    })
  })
})
```

**Implementation:**
```typescript
// assets/js/domain/entities/shopping-cart.ts
export interface CartItem {
  id: string
  name: string
  price: number
  quantity: number
}

export class ShoppingCart {
  constructor(
    public readonly items: CartItem[],
    public readonly discount: number = 0
  ) {}

  addItem(item: CartItem): ShoppingCart {
    if (item.quantity <= 0) {
      throw new Error('Quantity must be positive')
    }
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

**Orchestrates business logic and handles side effects.**

- Write tests first using Vitest
- Mock infrastructure dependencies (API, storage)
- Test orchestration and workflows
- Test async operations and error handling

**Example:**
```typescript
// assets/js/application/use-cases/add-to-cart.test.ts
import { describe, test, expect, vi, beforeEach } from 'vitest'
import { AddToCart } from './add-to-cart'
import type { CartRepository } from '../../infrastructure/storage/cart-repository'
import type { PriceService } from '../../infrastructure/api/price-service'
import { ShoppingCart } from '../../domain/entities/shopping-cart'

describe('AddToCart', () => {
  let mockRepository: CartRepository
  let mockPriceService: PriceService
  let useCase: AddToCart

  beforeEach(() => {
    mockRepository = {
      load: vi.fn(),
      save: vi.fn()
    }
    mockPriceService = {
      getPrice: vi.fn()
    }
    useCase = new AddToCart(mockRepository, mockPriceService)
  })

  test('adds item to existing cart', async () => {
    const existingCart = new ShoppingCart([
      { id: '1', name: 'Product 1', price: 10, quantity: 1 }
    ])
    vi.mocked(mockRepository.load).mockResolvedValue(existingCart)
    vi.mocked(mockPriceService.getPrice).mockResolvedValue(20)

    await useCase.execute('2', 2)

    expect(mockRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        items: expect.arrayContaining([
          expect.objectContaining({ id: '1' }),
          expect.objectContaining({ id: '2', quantity: 2, price: 20 })
        ])
      })
    )
  })

  test('throws error when price service fails', async () => {
    vi.mocked(mockRepository.load).mockResolvedValue(new ShoppingCart([]))
    vi.mocked(mockPriceService.getPrice).mockRejectedValue(
      new Error('Price not found')
    )

    await expect(useCase.execute('1', 1)).rejects.toThrow('Price not found')
    expect(mockRepository.save).not.toHaveBeenCalled()
  })
})
```

#### 3. Infrastructure Layer

**Handles external dependencies like APIs, storage, and browser APIs.**

- Write tests first using Vitest
- Mock browser APIs (localStorage, fetch, etc.)
- Test adapters and integration points
- Test error handling and edge cases

**Example:**
```typescript
// assets/js/infrastructure/storage/local-storage-cart-repository.test.ts
import { describe, test, expect, beforeEach, vi } from 'vitest'
import { LocalStorageCartRepository } from './local-storage-cart-repository'
import { ShoppingCart } from '../../domain/entities/shopping-cart'

describe('LocalStorageCartRepository', () => {
  let repository: LocalStorageCartRepository
  let mockStorage: Record<string, string>

  beforeEach(() => {
    mockStorage = {}

    global.localStorage = {
      getItem: vi.fn((key: string) => mockStorage[key] ?? null),
      setItem: vi.fn((key: string, value: string) => {
        mockStorage[key] = value
      }),
      removeItem: vi.fn(),
      clear: vi.fn(),
      length: 0,
      key: vi.fn()
    }

    repository = new LocalStorageCartRepository()
  })

  test('loads cart from localStorage', async () => {
    const cartData = {
      items: [{ id: '1', name: 'Product', price: 10, quantity: 1 }],
      discount: 0.1
    }
    mockStorage['shopping-cart'] = JSON.stringify(cartData)

    const cart = await repository.load()

    expect(cart.items).toHaveLength(1)
    expect(cart.discount).toBe(0.1)
  })

  test('returns empty cart when no data exists', async () => {
    const cart = await repository.load()

    expect(cart.items).toHaveLength(0)
  })

  test('saves cart to localStorage', async () => {
    const items = [{ id: '1', name: 'Product', price: 10, quantity: 1 }]
    const cart = new ShoppingCart(items)

    await repository.save(cart)

    const saved = JSON.parse(mockStorage['shopping-cart'])
    expect(saved.items).toHaveLength(1)
  })
})
```

#### 4. Presentation Layer (Phoenix Hooks)

**Handles DOM interactions and LiveView integration.**

- Write tests first (for testable logic, extract to use cases)
- Test DOM manipulation and event handling
- Test LiveView event communication
- Keep hooks thin - delegate to use cases

**Example:**
```typescript
// assets/js/presentation/hooks/cart-updater.test.ts
import { describe, test, expect, vi, beforeEach } from 'vitest'
import { CartUpdater } from './cart-updater'

describe('CartUpdater Hook', () => {
  let hook: CartUpdater
  let mockElement: HTMLElement
  let mockPushEvent: ReturnType<typeof vi.fn>

  beforeEach(() => {
    mockElement = document.createElement('button')
    mockElement.dataset.productId = '123'
    mockElement.dataset.quantity = '2'

    hook = new CartUpdater()
    hook.el = mockElement
    hook.pushEvent = mockPushEvent = vi.fn()
  })

  test('pushes event to LiveView on success', async () => {
    // Mock successful use case execution
    vi.spyOn(hook as any, 'executeUseCase').mockResolvedValue()

    await mockElement.click()
    await new Promise(resolve => setTimeout(resolve, 0))

    expect(mockPushEvent).toHaveBeenCalledWith('cart-updated', {
      productId: '123',
      quantity: 2
    })
  })

  test('shows error message on failure', async () => {
    vi.spyOn(hook as any, 'executeUseCase').mockRejectedValue(
      new Error('Failed')
    )
    const showErrorSpy = vi.spyOn(hook as any, 'showError')

    await mockElement.click()
    await new Promise(resolve => setTimeout(resolve, 0))

    expect(showErrorSpy).toHaveBeenCalled()
    expect(mockPushEvent).not.toHaveBeenCalled()
  })
})
```

---

## Full Stack Integration Testing

### End-to-End Workflows

Test complete user flows that span backend and frontend.

**Example: Complete Add to Cart Flow**

```elixir
# test/my_app_web/integration/cart_flow_test.exs
defmodule MyAppWeb.Integration.CartFlowTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "complete cart workflow" do
    test "user can add item, view cart, and checkout", %{conn: conn} do
      user = insert(:user, discount: 0.1)
      product = insert(:product, name: "Test Product", price: 100)
      conn = log_in_user(conn, user)

      # Navigate to product page
      {:ok, product_view, _html} = live(conn, ~p"/products/#{product.id}")

      # Add to cart via JavaScript hook
      product_view
      |> element("#add-to-cart-btn")
      |> render_hook("cart-updated", %{
        "productId" => product.id,
        "quantity" => 2
      })

      # Navigate to cart
      {:ok, cart_view, _html} = live(conn, ~p"/cart")

      # Verify cart contents
      assert render(cart_view) =~ "Test Product"
      assert render(cart_view) =~ "Quantity: 2"
      assert render(cart_view) =~ "$180.00"  # $200 with 10% discount

      # Proceed to checkout
      cart_view
      |> element("#checkout-btn")
      |> render_click()

      # Verify order created
      assert_redirect(cart_view, ~p"/orders/confirmation")

      order = Repo.get_by(Order, user_id: user.id)
      assert order
      assert order.total == Decimal.new("180.00")
    end
  end
end
```

### Testing Phoenix Channels

**Backend Channel Test:**
```elixir
# test/my_app_web/channels/cart_channel_test.exs
defmodule MyAppWeb.CartChannelTest do
  use MyAppWeb.ChannelCase

  describe "join/3" do
    test "user can join their own cart channel" do
      user = insert(:user)
      {:ok, socket} = connect(MyAppWeb.UserSocket, %{"user_id" => user.id})

      assert {:ok, _, _socket} = subscribe_and_join(socket, "cart:#{user.id}", %{})
    end

    test "user cannot join another user's cart channel" do
      user1 = insert(:user)
      user2 = insert(:user)
      {:ok, socket} = connect(MyAppWeb.UserSocket, %{"user_id" => user1.id})

      assert {:error, _} = subscribe_and_join(socket, "cart:#{user2.id}", %{})
    end
  end

  describe "handle_in update_item" do
    test "broadcasts cart update to all subscribers" do
      user = insert(:user)
      {:ok, socket} = connect(MyAppWeb.UserSocket, %{"user_id" => user.id})
      {:ok, _, socket} = subscribe_and_join(socket, "cart:#{user.id}", %{})

      ref = push(socket, "update_item", %{
        "product_id" => "123",
        "quantity" => 3
      })

      assert_reply ref, :ok, %{cart: cart}
      assert_broadcast "cart_updated", %{cart: ^cart}
    end
  end
end
```

**Frontend Hook with Channel:**
```typescript
// assets/js/presentation/hooks/cart-sync.test.ts
import { describe, test, expect, vi, beforeEach } from 'vitest'
import { CartSync } from './cart-sync'

describe('CartSync Hook', () => {
  test('subscribes to cart channel on mount', () => {
    const hook = new CartSync()
    const mockChannel = { join: vi.fn(() => ({ receive: vi.fn() })) }
    hook.channel = mockChannel as any

    hook.mounted()

    expect(mockChannel.join).toHaveBeenCalled()
  })

  test('updates UI when cart_updated event received', () => {
    const hook = new CartSync()
    const mockEl = document.createElement('div')
    hook.el = mockEl

    const cartData = { items: [{ id: '1', quantity: 2 }], total: 50 }
    hook.handleCartUpdate(cartData)

    expect(mockEl.dataset.itemCount).toBe('1')
  })
})
```

---

## Test Organization

### Backend Tests

```
test/
├── jarga/
│   ├── domain/              # Pure unit tests (write first)
│   │   ├── shipping_calculator_test.exs
│   │   └── discount_policy_test.exs
│   ├── application/         # Use case tests with mocks
│   │   ├── calculate_shipping_test.exs
│   │   └── process_order_test.exs
│   ├── accounts/            # Context tests
│   │   ├── accounts_test.exs
│   │   └── queries_test.exs
│   └── shipping/            # Infrastructure tests
│       ├── queries_test.exs
│       └── repository_test.exs
├── jarga_web/
│   ├── live/                # LiveView tests
│   │   ├── cart_live_test.exs
│   │   └── shipping_live_test.exs
│   ├── channels/            # Channel tests
│   │   └── cart_channel_test.exs
│   └── integration/         # Full stack integration tests
│       └── cart_flow_test.exs
└── support/
    ├── fixtures/            # Test data builders
    ├── conn_case.ex
    └── data_case.ex
```

### Frontend Tests

```
assets/
├── js/
│   ├── domain/
│   │   └── entities/
│   │       ├── shopping-cart.ts
│   │       └── shopping-cart.test.ts
│   ├── application/
│   │   └── use-cases/
│   │       ├── add-to-cart.ts
│   │       └── add-to-cart.test.ts
│   ├── infrastructure/
│   │   ├── storage/
│   │   │   ├── cart-repository.ts
│   │   │   └── cart-repository.test.ts
│   │   └── api/
│   │       ├── price-service.ts
│   │       └── price-service.test.ts
│   └── presentation/
│       └── hooks/
│           ├── cart-updater.ts
│           ├── cart-updater.test.ts
│           ├── cart-sync.ts
│           └── cart-sync.test.ts
└── test/
    ├── setup.ts             # Vitest setup
    └── helpers/             # Test utilities
```

---

## Running Tests

### Backend Tests (Elixir)

```bash
# Run tests continuously (recommended during TDD)
mix test.watch

# Run all tests
mix test

# Run specific test file
mix test test/jarga/domain/shipping_calculator_test.exs

# Run specific test
mix test test/jarga/domain/shipping_calculator_test.exs:25

# Run tests with coverage
mix test --cover

# Run only domain tests (fast)
mix test test/jarga/domain/

# Run integration tests
mix test test/jarga_web/integration/
```

### Frontend Tests (TypeScript)

```bash
# Run tests in watch mode (recommended during TDD)
npm run test:watch

# Run all tests
npm run test

# Run specific test file
npm run test shopping-cart.test.ts

# Run tests with coverage
npm run test:coverage

# Run tests in CI mode
npm run test:ci
```

### Running All Tests

```bash
# Run backend and frontend tests together
mix test && npm run test

# Or create a convenience script in package.json:
npm run test:all
```

---

## Full Stack TDD Workflow Example

### Feature Request: "Add real-time cart synchronization across browser tabs"

#### Step 1: Backend - Write Domain Tests

```elixir
# test/jarga/domain/cart_sync_test.exs
defmodule Jarga.Domain.CartSyncTest do
  use ExUnit.Case, async: true

  test "merges cart items from different sessions"
  test "resolves conflicts by taking most recent update"
  test "preserves cart totals after merge"
end
```

#### Step 2: Backend - Implement Domain Logic

```elixir
# lib/jarga/domain/cart_sync.ex
defmodule Jarga.Domain.CartSync do
  def merge(cart1, cart2), do: # implementation
end
```

#### Step 3: Frontend - Write Domain Tests

```typescript
// assets/js/domain/cart-merger.test.ts
describe('CartMerger', () => {
  test('combines items from two carts')
  test('handles duplicate items')
  test('preserves discount settings')
})
```

#### Step 4: Frontend - Implement Domain Logic

```typescript
// assets/js/domain/cart-merger.ts
export class CartMerger {
  merge(cart1: ShoppingCart, cart2: ShoppingCart): ShoppingCart {
    // implementation
  }
}
```

#### Step 5: Backend - Write Channel Tests

```elixir
# test/jarga_web/channels/cart_channel_test.exs
test "broadcasts to all connected tabs when cart updates"
test "syncs cart state when new tab joins"
```

#### Step 6: Backend - Implement Channel

```elixir
# lib/jarga_web/channels/cart_channel.ex
defmodule JargaWeb.CartChannel do
  # implementation
end
```

#### Step 7: Frontend - Write Hook Tests

```typescript
// assets/js/presentation/hooks/cart-sync.test.ts
test('subscribes to channel on mount')
test('updates local cart when receiving sync event')
test('pushes changes to channel')
```

#### Step 8: Frontend - Implement Hook

```typescript
// assets/js/presentation/hooks/cart-sync.ts
export class CartSync {
  // implementation
}
```

#### Step 9: Write Integration Test

```elixir
# test/jarga_web/integration/cart_sync_test.exs
test "cart syncs across multiple browser tabs"
```

---

## TDD Anti-Patterns to Avoid

### Don't Skip Tests

❌ **Bad:**
```elixir
# "I'll write the test later..."
def calculate_shipping(weight, distance) do
  # implementation without test
end
```

✅ **Good:**
```elixir
# Write test first
test "calculates shipping for 5kg over 100km" do
  assert {:ok, 25.0} = ShippingCalculator.calculate(5, 100)
end

# Then implement
def calculate_shipping(weight, distance), do: # implementation
```

### Don't Test Implementation Details

❌ **Bad:**
```typescript
test('uses specific algorithm to sort items', () => {
  const cart = new ShoppingCart([...])
  // Testing internal sorting implementation
  expect(cart['sortItems']()).toBe(...)
})
```

✅ **Good:**
```typescript
test('returns items in correct order', () => {
  const cart = new ShoppingCart([...])
  const items = cart.getItems()
  expect(items[0].id).toBe('1')
})
```

### Don't Write Tests After Implementation

❌ **Bad:**
```
1. Write feature code
2. Feature works
3. Write tests to match implementation
```

✅ **Good:**
```
1. Write failing test (RED)
2. Write minimal code to pass (GREEN)
3. Refactor while keeping green
```

### Don't Mock Everything

❌ **Bad:**
```elixir
# Mocking domain logic
test "calculates total" do
  mock(Cart, :calculate_total, fn _ -> 100 end)
  # This doesn't test anything!
end
```

✅ **Good:**
```elixir
# Test real domain logic, mock infrastructure
test "calculates total" do
  cart = Cart.new([item1, item2])
  assert Cart.calculate_total(cart) == 100
end
```

---

## Benefits of Full Stack TDD

When following TDD across the entire stack, you gain:

### Backend Benefits
1. **Better API Design**: Tests force you to think about function interfaces
2. **Transaction Safety**: Caught early through use case testing
3. **Database Performance**: Query tests identify N+1 problems
4. **Business Logic Correctness**: Domain tests catch edge cases

### Frontend Benefits
1. **Type Safety**: TypeScript + tests catch errors at compile time
2. **Modular Code**: TDD encourages small, focused, testable functions
3. **Browser Compatibility**: Infrastructure tests catch API differences
4. **UI Reliability**: Hook tests ensure proper LiveView integration

### Integration Benefits
1. **Contract Validation**: Tests ensure backend/frontend communicate correctly
2. **Real-time Features**: Channel tests validate pub/sub behavior
3. **User Experience**: Integration tests catch workflow issues
4. **Deployment Confidence**: Full test suite validates entire system

### Overall Benefits
1. **Complete Test Coverage**: Every piece of code has a test
2. **Living Documentation**: Tests serve as executable documentation
3. **Confidence in Refactoring**: Comprehensive test suite catches regressions
4. **Fewer Bugs in Production**: Issues caught early in development cycle
5. **Faster Development**: While seeming slower initially, prevents debugging time later
6. **Better Design**: Writing tests first forces better architecture decisions

---

## Summary

Full Stack Test-Driven Development is not optional in this project - it's the standard approach for both backend and frontend code:

### The Core Cycle

1. ✅ **RED**: Write a failing test first
2. ✅ **GREEN**: Write minimal code to pass the test
3. ✅ **REFACTOR**: Improve code while keeping tests green

### Testing Order (Both Backend and Frontend)

1. **Domain Layer** (Start Here) - Pure business logic, no dependencies
2. **Application Layer** (Use Cases) - Orchestration with mocked dependencies
3. **Infrastructure Layer** - Integration with real/mocked external systems
4. **Presentation Layer** (Last) - UI and LiveView integration

### Key Principles

- **Always write tests before implementation**
- Start with the simplest test and build complexity gradually
- Test behavior, not implementation
- Keep tests fast - domain tests in milliseconds
- Mock at architectural boundaries (infrastructure layer)
- Follow SOLID principles in both test and production code
- Use types (Elixir specs, TypeScript) for additional safety
- Write integration tests for critical full-stack workflows

### Technology-Specific Guidelines

**Backend (Phoenix/Elixir):**
- Use `ExUnit.Case` for domain tests
- Use `DataCase` for database tests
- Use `ConnCase` for LiveView/controller tests
- Use Mox for mocking behaviors
- Keep LiveViews thin - delegate to contexts

**Frontend (TypeScript):**
- Use Vitest for all JavaScript tests
- Mock browser APIs at infrastructure boundaries
- Keep hooks thin - delegate to use cases
- Use TypeScript for compile-time safety
- Test channel integration separately

By following TDD across the full stack, you create maintainable, testable, and reliable applications with confidence to refactor and evolve the codebase over time.
