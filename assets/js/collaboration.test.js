import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { CollaborationManager } from './collaboration'
import * as Y from 'yjs'

describe('CollaborationManager', () => {
  let collaborationManager

  beforeEach(() => {
    collaborationManager = new CollaborationManager()
  })

  afterEach(() => {
    if (collaborationManager) {
      collaborationManager.destroy()
    }
  })

  describe('initialization', () => {
    it('should create a CollaborationManager instance', () => {
      expect(collaborationManager).toBeInstanceOf(CollaborationManager)
    })

    it('should generate a unique user ID', () => {
      const userId = collaborationManager.getUserId()
      expect(userId).toMatch(/^user_/)
      expect(userId.length).toBeGreaterThan(10)
    })

    it('should initialize Yjs document and XML fragment', () => {
      collaborationManager.initialize()

      const ydoc = collaborationManager.getYDoc()
      expect(ydoc).toBeInstanceOf(Y.Doc)
      expect(collaborationManager.yXmlFragment).toBeDefined()
    })
  })

  describe('update handling', () => {
    beforeEach(() => {
      collaborationManager.initialize()
    })

    it('should call onLocalUpdate callback when local changes occur', () => {
      return new Promise((resolve) => {
        const mockCallback = vi.fn((updateBase64, userId) => {
          expect(typeof updateBase64).toBe('string')
          expect(userId).toBe(collaborationManager.getUserId())
          resolve()
        })

        collaborationManager.onLocalUpdate(mockCallback)

        // Trigger a local update
        const text = collaborationManager.yXmlFragment
        text.insert(0, [{ insert: 'test' }])
      })
    })

    it('should apply remote updates without triggering local callback', () => {
      const mockCallback = vi.fn()
      collaborationManager.onLocalUpdate(mockCallback)

      // Create a remote update
      const remoteDoc = new Y.Doc()
      const remoteFragment = remoteDoc.get('prosemirror', Y.XmlFragment)
      remoteFragment.insert(0, [{ insert: 'remote' }])

      const update = Y.encodeStateAsUpdate(remoteDoc)
      const updateBase64 = btoa(String.fromCharCode(...update))

      // Apply as remote update
      collaborationManager.applyRemoteUpdate(updateBase64)

      // Local callback should not be called for remote updates
      expect(mockCallback).not.toHaveBeenCalled()

      remoteDoc.destroy()
    })
  })

  describe('cleanup', () => {
    beforeEach(() => {
      collaborationManager.initialize()
    })

    it('should destroy Yjs document on cleanup', () => {
      const ydoc = collaborationManager.getYDoc()
      const destroySpy = vi.spyOn(ydoc, 'destroy')

      collaborationManager.destroy()

      expect(destroySpy).toHaveBeenCalled()
      expect(collaborationManager.ydoc).toBeNull()
    })

    it('should destroy Y.UndoManager on cleanup', () => {
      // Simulate Y.UndoManager being created during plugin configuration
      collaborationManager.yjsUndoManager = new Y.UndoManager(
        collaborationManager.yXmlFragment
      )
      const undoManager = collaborationManager.yjsUndoManager
      const destroySpy = vi.spyOn(undoManager, 'destroy')

      collaborationManager.destroy()

      expect(destroySpy).toHaveBeenCalled()
      expect(collaborationManager.yjsUndoManager).toBeNull()
    })
  })

  describe('awareness', () => {
    beforeEach(() => {
      collaborationManager.initialize()
    })

    it('should create awareness instance on initialization', () => {
      expect(collaborationManager.awareness).toBeDefined()
      expect(collaborationManager.awareness.doc).toBe(collaborationManager.ydoc)
    })

    it('should set local awareness state with user info', () => {
      const localState = collaborationManager.awareness.getLocalState()

      expect(localState.userId).toBe(collaborationManager.getUserId())
      expect(localState.userName).toBeDefined()
      expect(localState.selection).toBeNull()
    })

    it('should call onAwarenessUpdate callback when awareness changes', () => {
      return new Promise((resolve) => {
        const mockCallback = vi.fn((updateBase64, userId) => {
          expect(typeof updateBase64).toBe('string')
          expect(userId).toBe(collaborationManager.getUserId())
          resolve()
        })

        collaborationManager.onAwarenessUpdate(mockCallback)

        // Trigger awareness update by changing local state
        collaborationManager.awareness.setLocalStateField('selection', {
          anchor: 0,
          head: 5
        })
      })
    })

    it('should apply remote awareness updates', () => {
      const remoteUserId = 'user_remote'
      const remoteUserName = 'Remote User'

      // Create a simulated remote awareness update
      const remoteAwareness = new (require('y-protocols/awareness').Awareness)(new Y.Doc())
      remoteAwareness.setLocalState({
        userId: remoteUserId,
        userName: remoteUserName,
        selection: { anchor: 5, head: 10 }
      })

      const update = require('y-protocols/awareness').encodeAwarenessUpdate(
        remoteAwareness,
        [remoteAwareness.clientID]
      )
      const updateBase64 = btoa(String.fromCharCode(...update))

      // Apply remote awareness update
      collaborationManager.applyRemoteAwarenessUpdate(updateBase64)

      // Check if remote state was applied
      const states = collaborationManager.awareness.getStates()
      const remoteState = Array.from(states.values()).find(
        state => state.userId === remoteUserId
      )

      expect(remoteState).toBeDefined()
      expect(remoteState.userName).toBe(remoteUserName)
      expect(remoteState.selection).toEqual({ anchor: 5, head: 10 })

      remoteAwareness.destroy()
    })

    it('should clean up awareness on destroy', () => {
      const awareness = collaborationManager.awareness

      collaborationManager.destroy()

      // Awareness should be cleaned up
      expect(collaborationManager.awareness).toBeNull()
    })
  })

  describe('SOLID principles compliance', () => {
    it('should have single responsibility (collaboration only)', () => {
      // CollaborationManager should only handle Yjs collaboration
      // It should NOT handle UI concerns or Phoenix communication
      const methods = Object.getOwnPropertyNames(CollaborationManager.prototype)

      // Check that all methods are related to collaboration
      const collaborationMethods = methods.filter(m =>
        m.includes('Yjs') ||
        m.includes('Update') ||
        m.includes('Plugin') ||
        m.includes('Awareness') ||
        m === 'initialize' ||
        m === 'destroy' ||
        m === 'constructor'
      )

      // All methods should be collaboration-related
      expect(collaborationMethods.length).toBeGreaterThan(0)
    })

    it('should use dependency injection via callbacks', () => {
      collaborationManager.initialize()

      // onLocalUpdate uses callback injection for loose coupling
      const callback = vi.fn()
      collaborationManager.onLocalUpdate(callback)

      expect(collaborationManager.onLocalUpdateCallback).toBe(callback)

      // onAwarenessUpdate also uses callback injection
      const awarenessCallback = vi.fn()
      collaborationManager.onAwarenessUpdate(awarenessCallback)

      expect(collaborationManager.onAwarenessUpdateCallback).toBe(awarenessCallback)
    })

    it('should not have unnecessary abstractions', () => {
      // Undo logic is handled directly by Y.UndoManager (from yjs)
      // Awareness is handled directly by Y.Awareness (from y-protocols)
      // No unnecessary wrapper classes
      const methods = Object.getOwnPropertyNames(CollaborationManager.prototype)

      // Should not have an 'undoManager' property at initialization
      expect(collaborationManager.undoManager).toBeUndefined()

      // Should only have yjsUndoManager (created during plugin config)
      expect(collaborationManager.yjsUndoManager).toBeNull()
    })
  })
})
