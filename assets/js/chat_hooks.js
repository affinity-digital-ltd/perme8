/**
 * JavaScript hooks for the chat panel component
 * Handles localStorage persistence, keyboard shortcuts, and auto-scroll
 */

export const ChatPanel = {
  mounted() {
    const toggleBtn = document.getElementById('chat-toggle-btn')

    // Function to update button visibility
    const updateButtonVisibility = () => {
      if (this.el.checked) {
        toggleBtn.classList.add('hidden')
      } else {
        toggleBtn.classList.remove('hidden')
      }
    }

    // Watch for checkbox changes
    this.el.addEventListener('change', () => {
      updateButtonVisibility()

      if (this.el.checked) {
        // Drawer is opening - focus the input after animation
        setTimeout(() => {
          const input = document.getElementById('chat-input')
          if (input) {
            input.focus()
          }
        }, 150)
      }

      // Save state to localStorage
      localStorage.setItem('chat_collapsed', !this.el.checked)
    })

    // Load collapsed state from localStorage
    const collapsed = localStorage.getItem('chat_collapsed')
    if (collapsed !== null) {
      this.el.checked = collapsed === 'false'
    }

    // Initial button visibility
    updateButtonVisibility()

    // Keyboard shortcut: Cmd/Ctrl + K to toggle
    this.handleKeyboard = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        this.el.click()
      }

      // Escape to close
      if (e.key === 'Escape' && this.el.checked) {
        this.el.click()
      }
    }

    document.addEventListener('keydown', this.handleKeyboard)
  },

  destroyed() {
    if (this.handleKeyboard) {
      document.removeEventListener('keydown', this.handleKeyboard)
    }
  }
}

export const ChatMessages = {
  mounted() {
    this.scrollToBottom()
  },

  updated() {
    this.scrollToBottom()
  },

  scrollToBottom() {
    // Smooth scroll to bottom
    this.el.scrollTop = this.el.scrollHeight
  }
}

export const ChatInput = {
  mounted() {
    // Submit on Enter (without Shift), Shift+Enter for new line
    this.el.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault()
        const form = this.el.closest('form')
        if (form && this.el.value.trim() !== '') {
          form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
          // Refocus after submit
          setTimeout(() => {
            this.el.focus()
          }, 0)
        }
      }
      // Shift+Enter will create a new line (default textarea behavior)
    })
  },

  updated() {
    // Keep focus on input after form submission and LiveView updates
    if (document.activeElement !== this.el) {
      this.el.focus()
    }
  }
}
