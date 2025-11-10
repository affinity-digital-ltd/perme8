import { createAIMentionPlugin, updateAIResponseNode, appendChunkToNode } from './ai-mention-plugin'

/**
 * AI Assistant Manager
 *
 * Coordinates AI assistance between:
 * - Milkdown editor (ProseMirror view)
 * - AI mention plugin (detection and node creation)
 * - LiveView hook (server communication)
 *
 * Responsibilities:
 * - Configure AI mention plugin with callbacks
 * - Handle AI query requests
 * - Process streaming responses
 * - Update AI response nodes
 */
export class AIAssistantManager {
  /**
   * @param {Object} options
   * @param {Object} options.view - ProseMirror EditorView
   * @param {Object} options.schema - ProseMirror schema
   * @param {Function} options.parser - Milkdown markdown parser
   * @param {Function} options.pushEvent - LiveView pushEvent function
   */
  constructor(options) {
    console.log('[AIAssistantManager] Constructing with options:', { hasView: !!options.view, hasSchema: !!options.schema, hasParser: !!options.parser, hasPushEvent: !!options.pushEvent })

    this.view = options.view
    this.schema = options.schema
    this.parser = options.parser
    this.pushEvent = options.pushEvent

    // Track active AI queries
    this.activeQueries = new Map() // nodeId -> { question, startTime }

    // Bind methods
    this.handleAIQuery = this.handleAIQuery.bind(this)
    this.handleAIChunk = this.handleAIChunk.bind(this)
    this.handleAIDone = this.handleAIDone.bind(this)
    this.handleAIError = this.handleAIError.bind(this)

    console.log('[AIAssistantManager] Construction complete')
  }

  /**
   * Create and return the AI mention plugin instance
   *
   * This should be called after the manager is created to get the
   * ProseMirror plugin instance.
   *
   * @returns {Plugin} - ProseMirror plugin
   */
  createPlugin() {
    return createAIMentionPlugin({
      schema: this.schema,
      onAIQuery: this.handleAIQuery
    })
  }

  /**
   * Handle AI query trigger from mention plugin
   *
   * @param {Object} params
   * @param {string} params.question - User's question
   * @param {string} params.nodeId - AI response node ID
   */
  handleAIQuery({ question, nodeId }) {
    console.log(`[AIAssistant] Query triggered: "${question}" (${nodeId})`)

    // Track query
    this.activeQueries.set(nodeId, {
      question,
      startTime: Date.now()
    })

    // Send to LiveView
    this.pushEvent('ai_query', {
      question,
      node_id: nodeId
    })
  }

  /**
   * Handle streaming chunk from server
   *
   * @param {Object} data
   * @param {string} data.node_id - Node ID
   * @param {string} data.chunk - Text chunk
   */
  handleAIChunk({ node_id, chunk }) {
    console.log(`[AIAssistant] Chunk received for ${node_id}: ${chunk.length} chars`)

    // Append chunk to node
    const success = appendChunkToNode(this.view, node_id, chunk)

    if (!success) {
      console.warn(`[AIAssistant] Failed to append chunk to node ${node_id}`)
    }
  }

  /**
   * Handle completion from server
   *
   * @param {Object} data
   * @param {string} data.node_id - Node ID
   * @param {string} data.response - Complete response text
   */
  handleAIDone({ node_id, response }) {
    console.log(`[AIAssistant] Query completed for ${node_id}`)

    // Find the AI response node and replace it with properly formatted content
    const { state } = this.view
    const { doc, schema } = state

    let nodePos = null
    let parentNode = null
    let indexInParent = null

    doc.descendants((node, pos, parent, index) => {
      if (node.type.name === 'ai_response' && node.attrs.nodeId === node_id) {
        nodePos = pos
        parentNode = parent
        indexInParent = index
        return false
      }
    })

    if (nodePos !== null && parentNode) {
      const tr = state.tr

      // Parse markdown response into ProseMirror nodes
      // The parser returns either a Node or a string (on error)
      const parsed = this.parser(response.trim())

      // Handle parser errors
      if (!parsed || typeof parsed === 'string') {
        console.error('[AIAssistant] Failed to parse markdown:', parsed)
        return
      }

      // Extract the content nodes (skip the top-level doc node)
      const nodes = []
      parsed.content.forEach(node => {
        nodes.push(node)
      })

      // Calculate positions BEFORE making any changes
      const parentStart = nodePos - indexInParent - 1
      const parentEnd = parentStart + parentNode.nodeSize

      // Delete the AI response node
      tr.delete(nodePos, nodePos + 1)

      // If the AI response is inside a paragraph, we need to handle inline vs block content
      if (parentNode.type.name === 'paragraph') {
        // Check if we have any block-level nodes (paragraphs, headings, lists, etc.)
        const hasBlockNodes = nodes.some(node => !node.isInline && node.type.name !== 'text')

        if (!hasBlockNodes && nodes.length === 1 && nodes[0].type.name === 'paragraph') {
          // Single paragraph - insert its content inline
          const inlineContent = nodes[0].content
          tr.insert(nodePos, inlineContent)
        } else {
          // Has block nodes - need to split the current paragraph and insert blocks
          const remainingInParent = parentEnd - (nodePos + 1) // Content after the AI node
          const insertAfterParent = nodePos + remainingInParent

          // Insert block nodes after the current paragraph
          let currentInsertPos = insertAfterParent
          nodes.forEach((node) => {
            tr.insert(currentInsertPos, node)
            currentInsertPos += node.nodeSize
          })
        }
      } else {
        // Not in a paragraph, insert all parsed nodes at the deletion point
        let currentPos = nodePos
        nodes.forEach((node) => {
          tr.insert(currentPos, node)
          currentPos += node.nodeSize
        })
      }

      this.view.dispatch(tr)

      // Log completion time
      const query = this.activeQueries.get(node_id)
      if (query) {
        const duration = Date.now() - query.startTime
        console.log(`[AIAssistant] Query took ${duration}ms`)
        this.activeQueries.delete(node_id)
      }
    } else {
      console.warn(`[AIAssistant] Failed to find node ${node_id}`)
    }
  }

  /**
   * Handle error from server
   *
   * @param {Object} data
   * @param {string} data.node_id - Node ID
   * @param {string} data.error - Error message
   */
  handleAIError({ node_id, error }) {
    console.error(`[AIAssistant] Error for ${node_id}: ${error}`)

    // Update node to error state
    const success = updateAIResponseNode(this.view, node_id, {
      state: 'error',
      error: error || 'An unknown error occurred',
      content: '' // Clear content on error
    })

    if (success) {
      // Remove from active queries
      this.activeQueries.delete(node_id)
    } else {
      console.warn(`[AIAssistant] Failed to update node ${node_id} to error state`)
    }
  }

  /**
   * Get statistics about active queries
   *
   * @returns {Object} - { count, queries }
   */
  getActiveQueriesInfo() {
    return {
      count: this.activeQueries.size,
      queries: Array.from(this.activeQueries.entries()).map(([nodeId, query]) => ({
        nodeId,
        question: query.question,
        duration: Date.now() - query.startTime
      }))
    }
  }

  /**
   * Cancel an active query
   *
   * @param {string} nodeId - Node ID to cancel
   */
  cancelQuery(nodeId) {
    const query = this.activeQueries.get(nodeId)

    if (query) {
      console.log(`[AIAssistant] Cancelling query ${nodeId}`)

      // Update node to error state (cancelled)
      updateAIResponseNode(this.view, nodeId, {
        state: 'error',
        error: 'Query cancelled by user',
        content: ''
      })

      // Remove from active queries
      this.activeQueries.delete(nodeId)

      // TODO: Send cancellation to server if backend supports it
      // this.pushEvent('ai_cancel', { node_id: nodeId })
    }
  }

  /**
   * Cancel all active queries
   */
  cancelAllQueries() {
    const nodeIds = Array.from(this.activeQueries.keys())

    console.log(`[AIAssistant] Cancelling ${nodeIds.length} active queries`)

    nodeIds.forEach(nodeId => {
      this.cancelQuery(nodeId)
    })
  }

  /**
   * Cleanup
   */
  destroy() {
    console.log('[AIAssistant] Destroying manager')

    // Cancel all active queries
    this.cancelAllQueries()

    // Clear references
    this.view = null
    this.schema = null
    this.parser = null
    this.pushEvent = null
    this.activeQueries.clear()
  }
}
