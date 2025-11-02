# Collaborative Markdown Editor - Architecture

This directory contains the frontend JavaScript modules for the collaborative Markdown editor with per-client undo functionality.

## Architecture Overview

The system follows **Clean Architecture** principles with clear separation of concerns:

```
┌─────────────────────────────────────────────┐
│           hooks.js (UI Layer)               │
│  - Phoenix LiveView integration             │
│  - Milkdown editor lifecycle                │
│  - Delegates to CollaborationManager        │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│    collaboration.js (Application Layer)     │
│  - Yjs document management                  │
│  - Update synchronization                   │
│  - Per-client undo via Y.UndoManager        │
│  - ProseMirror plugin configuration         │
└─────────────────────────────────────────────┘
```

## Core Modules

### hooks.js
**Responsibility**: UI lifecycle and Phoenix communication

- **Single Responsibility**: Only handles LiveView hooks and editor UI
- **Dependencies**: CollaborationManager (injected via composition)
- **Interface Adapter**: Translates between Phoenix events and collaboration logic

```javascript
// Usage
export const MilkdownEditor = {
  mounted() {
    this.collaborationManager = new CollaborationManager()
    this.collaborationManager.onLocalUpdate((update, userId) => {
      this.pushEvent('yjs_update', { update, user_id: userId })
    })
  }
}
```

### collaboration.js
**Responsibility**: Collaborative editing via Yjs

**Key Features**:
- Yjs document and XmlFragment management
- Local/remote update handling
- **Per-client undo via Y.UndoManager**
- ProseMirror plugin integration

**How Per-Client Undo Works**:

1. Create `ySyncPlugin` - synchronizes ProseMirror ↔ Yjs
2. Get the `binding` object from ySyncPlugin state
3. Create `Y.UndoManager` with `trackedOrigins: new Set([binding])`
4. Attach UndoManager to `binding.undoManager`
5. Add `yUndoPlugin` - uses the attached UndoManager
6. Add keyboard shortcuts via `prosemirror-keymap`

**Why This Works**:
- The `binding` object is used as the origin for all LOCAL edits
- REMOTE edits use a different origin (not the binding)
- Y.UndoManager only tracks operations with the binding origin
- Result: Each client only undos their own changes!

```javascript
// Simplified flow
const ySync = ySyncPlugin(yXmlFragment)
const binding = ySyncPluginKey.getState(view.state)?.binding

const undoManager = new Y.UndoManager(yXmlFragment, {
  trackedOrigins: new Set([binding]) // Only track this client's edits!
})

binding.undoManager = undoManager

const yUndo = yUndoPlugin() // Uses binding.undoManager
const keymap = keymap({ 'Mod-z': undo, 'Mod-y': redo })
```

## SOLID Principles Compliance

### Single Responsibility Principle (SRP)
✅ **hooks.js**: UI lifecycle and Phoenix communication only
✅ **collaboration.js**: Yjs collaboration and undo management only

### Open/Closed Principle (OCP)
✅ Open for extension: CollaborationManager can be extended for custom behaviors
✅ Closed for modification: Core collaboration logic is stable

### Liskov Substitution Principle (LSP)
✅ `CollaborationManager` can be mocked for testing
✅ Callback-based design allows substituting different implementations

### Interface Segregation Principle (ISP)
✅ Small, focused APIs:
  - `onLocalUpdate(callback)`
  - `applyRemoteUpdate(update)`
  - `configureProseMirrorPlugins(view, state)`

### Dependency Inversion Principle (DIP)
✅ Depends on abstractions (callbacks, not concrete implementations)
✅ `hooks.js` depends on `CollaborationManager` interface, not internals

## Testing

Run tests with:
```bash
npm test          # Run all tests once
npm run test:watch  # Watch mode
```

### Test Coverage
- **collaboration.test.js**: 10 tests covering initialization, updates, cleanup, SOLID compliance

## Key Design Decisions

### Why Not ProseMirror History?
- ProseMirror's history plugin doesn't naturally filter remote changes
- Y.UndoManager is built specifically for collaborative editing
- Simpler integration with y-prosemirror ecosystem

### Why Separate CollaborationManager?
- **Testability**: Can test collaboration logic without Phoenix or DOM
- **Reusability**: Can be used in different editor contexts
- **Separation of Concerns**: UI (hooks) vs. Business Logic (collaboration)

### Why Use Y.UndoManager Directly?
- **YAGNI** (You Aren't Gonna Need It): Don't add abstraction layers until needed
- Y.UndoManager from Yjs handles all current requirements
- Built specifically for collaborative editing with origin tracking
- No unnecessary wrapper classes - keeps code simple and maintainable

## Data Flow

### Local Edit Flow
```
User types
  → ProseMirror transaction
  → ySyncPlugin adds 'binding' as origin
  → Yjs update with binding origin
  → Y.UndoManager tracks it (binding in trackedOrigins)
  → CollaborationManager._handleYjsUpdate
  → onLocalUpdateCallback
  → pushEvent to Phoenix
  → Broadcast to other clients
```

### Remote Edit Flow
```
Other client types
  → Phoenix receives yjs_update
  → handleEvent in hook
  → CollaborationManager.applyRemoteUpdate
  → Y.applyUpdate with origin='remote'
  → ySyncPlugin applies to ProseMirror
  → Y.UndoManager ignores (origin ≠ binding)
  → Local undo history preserved!
```

### Undo Flow
```
User presses Ctrl+Z
  → Keymap plugin captures
  → y-prosemirror undo() command
  → Y.UndoManager.undo()
  → Only undoes local changes (binding origin)
  → ProseMirror transaction
  → ySyncPlugin syncs to Yjs
  → Broadcasts to other clients
```

## Future Enhancements

Potential areas for extension:

1. **Custom Undo Grouping**: Configure Y.UndoManager's `captureTimeout` for different grouping behaviors
2. **Undo UI**: Visual undo/redo stack display using Y.UndoManager events
3. **Selective Undo**: Undo specific ranges using Y.UndoManager's API
4. **Undo History Limits**: Configure Y.UndoManager's `captureMaxWait` and stack limits
5. **Undo Persistence**: Save/restore undo history across sessions

All can be implemented by extending CollaborationManager without touching core logic.

## Related Documentation

- [Phoenix Contexts Guide](https://hexdocs.pm/phoenix/contexts.html)
- [Yjs Documentation](https://docs.yjs.dev/)
- [y-prosemirror](https://github.com/yjs/y-prosemirror)
- [Milkdown](https://milkdown.dev/)
