/**
 * Hooks Entry Point
 *
 * This file serves as the main entry point for all Phoenix LiveView hooks.
 * Hooks are organized by domain into separate files for better maintainability.
 */

// Editor and document hooks
export { MilkdownEditor, DocumentTitleInput } from './document_hooks'

// Chat hooks
export { ChatPanel, ChatMessages, ChatInput } from './chat_hooks'

// Flash hooks
export { AutoHideFlash } from './flash_hooks'

// Default export for Phoenix LiveView
import { MilkdownEditor, DocumentTitleInput } from './document_hooks'
import { ChatPanel, ChatMessages, ChatInput } from './chat_hooks'
import { AutoHideFlash } from './flash_hooks'

export default {
  MilkdownEditor,
  ChatPanel,
  ChatMessages,
  ChatInput,
  AutoHideFlash,
  DocumentTitleInput
}
