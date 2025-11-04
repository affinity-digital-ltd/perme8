import { Editor, rootCtx, editorViewCtx, defaultValueCtx, serializerCtx } from '@milkdown/core'
import { commonmark } from '@milkdown/preset-commonmark'
import { nord } from '@milkdown/theme-nord'
import { clipboard } from '@milkdown/plugin-clipboard'
import { CollaborationManager } from './collaboration'

/**
 * MilkdownEditor Hook
 *
 * Responsibilities:
 * - UI lifecycle management (mounted/destroyed)
 * - Milkdown editor initialization
 * - Phoenix LiveView communication
 * - Delegates collaboration logic to CollaborationManager
 */
export const MilkdownEditor = {
  mounted() {
    // Get initial state from data attributes
    const initialYjsState = this.el.dataset.yjsState || ''
    const initialContent = this.el.dataset.initialContent || ''

    // Initialize collaboration manager with initial state
    this.collaborationManager = new CollaborationManager()
    this.collaborationManager.initialize(initialYjsState)

    // Set up callback for local updates to send to server
    this.collaborationManager.onLocalUpdate((updateBase64, userId) => {
      // Extract markdown content from editor
      const markdown = this.getMarkdownContent()

      // Get the complete document state for persistence
      const completeState = this.collaborationManager.getCompleteState()

      this.pushEvent('yjs_update', {
        update: updateBase64,
        complete_state: completeState,
        user_id: userId,
        markdown: markdown
      })
    })

    // Set up callback for awareness updates
    this.collaborationManager.onAwarenessUpdate((updateBase64, userId) => {
      this.pushEvent('awareness_update', {
        update: updateBase64,
        user_id: userId
      })
    })

    // Listen for remote Yjs updates from server
    this.handleEvent('yjs_update', ({ update }) => {
      this.collaborationManager.applyRemoteUpdate(update)
    })

    // Listen for remote awareness updates from server
    this.handleEvent('awareness_update', ({ update }) => {
      this.collaborationManager.applyRemoteAwarenessUpdate(update)
    })

    // Create Milkdown editor WITHOUT history/keymap (we'll add them later as raw plugins)
    const editor = Editor.make()
      .config((ctx) => {
        ctx.set(rootCtx, this.el)
      })
      .use(nord)
      .use(commonmark)
      .use(clipboard)

    this.editor = editor

    // Create the editor and configure collaboration
    editor.create().then(() => {
      this.editor.action((ctx) => {
        const view = ctx.get(editorViewCtx)
        const state = view.state

        // Configure ProseMirror with collaboration + undo/redo plugins
        const newState = this.collaborationManager.configureProseMirrorPlugins(view, state)
        view.updateState(newState)
      })
    }).catch((error) => {
      console.error('Failed to create Milkdown editor:', error)
    })
  },

  getMarkdownContent() {
    if (!this.editor) {
      return ''
    }

    try {
      // Get the markdown content from the editor
      let markdown = ''
      this.editor.action((ctx) => {
        const editorView = ctx.get(editorViewCtx)
        const serializer = ctx.get(serializerCtx)

        if (serializer && editorView) {
          markdown = serializer(editorView.state.doc)
        }
      })
      return markdown
    } catch (error) {
      console.error('Error extracting markdown:', error)
      return ''
    }
  },

  destroyed() {
    if (this.collaborationManager) {
      this.collaborationManager.destroy()
    }
    if (this.editor) {
      this.editor.destroy()
    }
  }
}

export default {
  MilkdownEditor
}
