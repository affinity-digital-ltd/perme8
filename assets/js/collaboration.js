import * as Y from 'yjs'
import { ySyncPlugin, yUndoPlugin, ySyncPluginKey, undo, redo } from 'y-prosemirror'
import { keymap } from 'prosemirror-keymap'

/**
 * CollaborationManager handles all Yjs collaboration logic.
 *
 * Responsibilities:
 * - Manages Yjs document lifecycle
 * - Handles local and remote updates
 * - Configures ProseMirror plugins for collaboration
 * - Manages per-client undo/redo via Y.UndoManager
 *
 * @class CollaborationManager
 */
export class CollaborationManager {
  constructor(config = {}) {
    this.userId = this._generateUserId()
    this.ydoc = null
    this.yXmlFragment = null
    this.onLocalUpdateCallback = null
    this.yjsUndoManager = null

    // Configuration
    this.config = {
      captureTimeout: config.captureTimeout || 500,
      ...config
    }
  }

  /**
   * Initialize the collaboration manager with a Yjs document.
   * @returns {void}
   */
  initialize() {
    this.ydoc = new Y.Doc()
    this.yXmlFragment = this.ydoc.get('prosemirror', Y.XmlFragment)

    // Listen for local Yjs updates
    this.ydoc.on('update', this._handleYjsUpdate.bind(this))
  }

  /**
   * Configure ProseMirror editor with collaboration plugins.
   *
   * Strategy:
   * - Apply ySyncPlugin for Yjs collaboration
   * - Apply history and keymap plugins AFTER ySyncPlugin so they can filter properly
   *
   * @param {EditorView} view - ProseMirror editor view
   * @param {EditorState} state - ProseMirror editor state
   * @returns {EditorState} New editor state with collaboration plugins
   */
  configureProseMirrorPlugins(view, state) {
    if (!this.ydoc || !this.yXmlFragment) {
      throw new Error('CollaborationManager not initialized. Call initialize() first.')
    }

    // Step 1: Apply ySyncPlugin for collaboration
    const ySync = ySyncPlugin(this.yXmlFragment)
    let newState = state.reconfigure({
      plugins: [...state.plugins, ySync]
    })
    view.updateState(newState)

    // Step 2: Get the binding from ySyncPlugin
    const ySyncState = ySyncPluginKey.getState(view.state)
    const binding = ySyncState?.binding

    if (!binding) {
      throw new Error('No binding found after adding ySyncPlugin')
    }

    // Step 3: Create UndoManager that tracks only this binding's changes
    // The binding object is used as the origin for local edits
    // Remote changes use a different origin and won't be tracked
    const undoManager = new Y.UndoManager(this.yXmlFragment, {
      trackedOrigins: new Set([binding])
    })

    // Step 4: Attach UndoManager to binding so yUndoPlugin can use it
    binding.undoManager = undoManager
    this.yjsUndoManager = undoManager

    // Step 5: Add yUndoPlugin for undo/redo state management
    const yUndo = yUndoPlugin()

    // Step 6: Add keyboard shortcuts for undo/redo
    const undoRedoKeymap = keymap({
      'Mod-z': undo,
      'Mod-y': redo,
      'Mod-Shift-z': redo
    })

    // Step 7: Apply both plugins
    newState = view.state.reconfigure({
      plugins: [...view.state.plugins, yUndo, undoRedoKeymap]
    })

    return newState
  }

  /**
   * Apply a remote Yjs update received from the server.
   *
   * @param {string} updateBase64 - Base64 encoded Yjs update
   * @returns {void}
   */
  applyRemoteUpdate(updateBase64) {
    try {
      const updateArray = Uint8Array.from(atob(updateBase64), c => c.charCodeAt(0))
      Y.applyUpdate(this.ydoc, updateArray, 'remote')
    } catch (error) {
      console.error('Error applying remote Yjs update:', error)
      throw error
    }
  }

  /**
   * Set callback for when local updates occur.
   *
   * @param {Function} callback - Callback function that receives (updateBase64, userId)
   * @returns {void}
   */
  onLocalUpdate(callback) {
    this.onLocalUpdateCallback = callback
  }

  /**
   * Get the user ID for this client.
   *
   * @returns {string} User ID
   */
  getUserId() {
    return this.userId
  }

  /**
   * Get the Yjs document.
   *
   * @returns {Y.Doc} Yjs document
   */
  getYDoc() {
    return this.ydoc
  }

  /**
   * Clean up resources.
   *
   * @returns {void}
   */
  destroy() {
    if (this.yjsUndoManager) {
      this.yjsUndoManager.destroy()
      this.yjsUndoManager = null
    }
    if (this.ydoc) {
      this.ydoc.destroy()
      this.ydoc = null
    }
    this.yXmlFragment = null
    this.onLocalUpdateCallback = null
  }

  /**
   * Handle Yjs update events.
   *
   * @private
   * @param {Uint8Array} update - Yjs update
   * @param {any} origin - Origin of the update
   * @returns {void}
   */
  _handleYjsUpdate(update, origin) {
    // Only send local updates (not remote ones) to the server
    if (origin !== 'remote' && this.onLocalUpdateCallback) {
      const updateBase64 = btoa(String.fromCharCode(...update))
      this.onLocalUpdateCallback(updateBase64, this.userId)
    }
  }

  /**
   * Generate a unique user ID for this client.
   *
   * @private
   * @returns {string} User ID
   */
  _generateUserId() {
    return 'user_' + Math.random().toString(36).substr(2, 9) + Date.now().toString(36)
  }
}
