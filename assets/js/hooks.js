import { Editor, rootCtx, editorViewCtx } from '@milkdown/core'
import { commonmark } from '@milkdown/preset-commonmark'
import { nord } from '@milkdown/theme-nord'
import { history } from '@milkdown/plugin-history'
import * as Y from 'yjs'
import { ySyncPlugin, yCursorPlugin, yUndoPlugin } from 'y-prosemirror'

export const MilkdownEditor = {
  mounted() {
    const initialContent = this.el.dataset.content || "# Welcome\n\nStart typing..."

    // Generate user ID in JavaScript to ensure uniqueness per tab
    const userId = 'user_' + Math.random().toString(36).substr(2, 9) + Date.now().toString(36)

    console.log('Mounting editor for user:', userId)

    // Store user ID
    this.userId = userId

    // Create Yjs document and shared type
    this.ydoc = new Y.Doc()
    this.yXmlFragment = this.ydoc.get('prosemirror', Y.XmlFragment)

    console.log('Created Yjs doc and XmlFragment:', this.yXmlFragment)

    // Listen for Yjs updates and send to server via Phoenix LiveView
    this.ydoc.on('update', (update, origin) => {
      console.log('🔄 Yjs update event. Origin:', origin, 'Update size:', update.length)

      // Don't send updates that came from remote
      if (origin !== 'remote') {
        // Convert update to base64 for transport
        const updateBase64 = btoa(String.fromCharCode(...update))

        console.log('📤 Sending Yjs update to server. Size:', updateBase64.length)
        this.pushEvent('yjs_update', {
          update: updateBase64,
          user_id: this.userId
        })
      } else {
        console.log('⏭️ Skipping send for remote update')
      }
    })

    // Listen for remote Yjs updates from server
    this.handleEvent('yjs_update', ({ update }) => {
      console.log('📥 Received Yjs update from server. Size:', update.length)

      try {
        // Convert base64 back to Uint8Array
        const updateArray = Uint8Array.from(atob(update), c => c.charCodeAt(0))

        console.log('Applying update to Yjs doc. Array size:', updateArray.length)

        // Apply the update with 'remote' origin to prevent echo
        Y.applyUpdate(this.ydoc, updateArray, 'remote')

        console.log('✅ Yjs update applied successfully')
      } catch (error) {
        console.error('❌ Error applying Yjs update:', error)
      }
    })

    // Create Milkdown editor WITHOUT collab plugin
    // We'll manually add y-prosemirror plugins instead
    const editor = Editor.make()
      .config((ctx) => {
        ctx.set(rootCtx, this.el)
      })
      .use(nord)
      .use(commonmark)
      .use(history)

    // Store the editor instance
    this.editor = editor

    // Create the editor
    editor.create().then(() => {
      console.log('✅ Milkdown editor created successfully')

      // Now manually inject y-prosemirror plugins
      this.editor.action((ctx) => {
        const view = ctx.get(editorViewCtx)

        console.log('📌 Binding y-prosemirror to editor')

        // Create y-prosemirror plugins
        const ySync = ySyncPlugin(this.yXmlFragment)
        const yUndo = yUndoPlugin()

        // Get the current state
        const state = view.state

        // Create new state with y-prosemirror plugins
        const newState = state.reconfigure({
          plugins: [...state.plugins, ySync, yUndo]
        })

        // Update the view with the new state
        view.updateState(newState)

        console.log('✅ y-prosemirror plugins injected')
        console.log('Editor is ready for collaborative input')

        // Add debug listeners
        const editorDom = view.dom
        editorDom.addEventListener('input', () => {
          console.log('🔤 Input event detected!')
        })

        editorDom.addEventListener('keydown', (e) => {
          console.log('⌨️ Keydown event detected:', e.key)
        })
      })
    }).catch((error) => {
      console.error('❌ Failed to create Milkdown editor:', error)
      console.error('Error stack:', error.stack)
    })
  },

  destroyed() {
    console.log('Destroying editor')
    if (this.ydoc) {
      this.ydoc.destroy()
    }
    if (this.editor) {
      this.editor.destroy()
    }
  }
}

export default {
  MilkdownEditor
}
