# Chat with Documents - PR Strategy

## Overview

This document outlines an incremental delivery strategy for the "Chat with Documents" feature. Each PR is designed to be independently valuable, testable, and deployable to production.

**Total Estimated Effort**: 29-41 days (5-8 weeks) if done sequentially

**Key Principle**: Each PR adds user value and validates assumptions before building the next layer.

---

## PR #1: Global Chat Panel with Static Content Chat

**Goal**: Chat with any page content using existing UI as "documents"

**Value**: Users can immediately ask questions about what they're viewing

**Effort**: 3-5 days

### What's Included

✅ **Core Features**:
- Global collapsible right panel (LiveView component)
- Chat UI (messages, input, streaming responses)
- OpenRouter + Gemini Flash 2.5 Lite integration
- LLM Client infrastructure
- Panel state persistence (localStorage)
- Keyboard shortcuts (Cmd+K to toggle)

✅ **Basic RAG**:
- Extract current page content as "context"
- No documents yet - just chat with visible page content
- Simple context injection (no embeddings)

✅ **UI Components**:
- Chat panel component in root layout
- Message list (user/assistant)
- Message input with streaming indicator
- Collapsible panel animations
- Mobile-responsive (full-screen overlay)

### How It Works

```
User on: /app/projects/proj-123 (viewing project details)
Opens: Chat panel (Cmd+K or button in header)
Context: Automatically extracts page content
         - Project name, description, tasks
         - Any visible data on the page
Query: "What's the project deadline?"
Answer: Based on the page content (without vector search)
        Streams response in real-time
```

### Technical Implementation

**New Files**:
```
lib/jarga_web/live/chat_live/
├── panel.ex                    # Main panel LiveView component
├── panel.html.heex             # Panel template
└── components/
    ├── message.ex              # Message component
    └── message_input.ex        # Input component

lib/jarga/documents/infrastructure/services/
└── llm_client.ex               # OpenRouter + Gemini client

assets/js/
└── chat_hooks.js               # LocalStorage + keyboard shortcuts

config/
└── config.exs                  # OpenRouter config
```

**Modified Files**:
```
lib/jarga_web/components/layouts/app.html.heex  # Add chat panel
mix.exs                                          # Add dependencies
```

**Dependencies**:
- `{:req, "~> 0.5"}` - Already in project
- `{:jason, "~> 1.4"}` - Already in project

**Environment Variables**:
```bash
OPENROUTER_API_KEY=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
CHAT_MODEL=google/gemini-2.5-flash-lite
```

### Testing Strategy

**Tests**:
- Panel renders and collapses
- Extracts page context correctly
- Sends message to LLM
- Streams response chunks
- Persists state to localStorage
- Keyboard shortcuts work

**Manual Testing**:
- Navigate to different pages, verify context changes
- Test on mobile (full-screen overlay)
- Verify streaming works smoothly

### Value Delivered

✅ Users get AI assistance immediately on any page
✅ Infrastructure validated (panel, LLM, streaming)
✅ UX validated (global panel concept)
✅ Foundation for future document features
✅ Can be shipped to production immediately

### Success Metrics

- Users open chat panel
- Users ask questions about page content
- Response latency < 3 seconds
- Panel state persists across navigation

---

## PR #2: Document Upload & Management

**Goal**: Users can upload and manage documents

**Value**: Central document repository per workspace/project

**Effort**: 4-6 days

**Depends On**: PR #1

### What's Included

✅ **Documents Context**:
- New `Jarga.Documents` context with Boundary
- Domain layer (policies, value objects)
- Infrastructure layer (storage, repository)
- Application layer (upload use case)

✅ **Database**:
- `documents` table (basic fields, no processing yet)
- Migrations for document schema

✅ **File Management**:
- File upload LiveView page
- Phoenix LiveView uploads integration
- File storage (local for dev, S3-ready for prod)
- Upload progress indicators
- Document list view (table with metadata)
- Delete functionality

✅ **UI**:
- Document upload page
- Drag-and-drop upload zone
- File type validation (client & server)
- Size limit validation (50MB)
- Document list with filters

### How It Works

```
User on: /app/workspaces/workspace-123/documents
Action: Drag and drop report.pdf
Result:
  - File validated (type, size)
  - Upload progress shown (0-100%)
  - File stored in storage backend
  - Database record created
  - Appears in document list
Status: "Uploaded" (not processed yet)
```

### Technical Implementation

**New Files**:
```
lib/jarga/documents/
├── documents.ex                         # Public context API
├── document.ex                          # Ecto schema
├── domain/
│   └── value_objects/
│       └── file_metadata.ex             # File validation
├── policies/
│   └── upload_policy.ex                 # Upload rules
├── infrastructure/
│   ├── persistence/
│   │   └── document_repository.ex       # Data access
│   └── storage/
│       └── file_storage.ex              # File storage
└── use_cases/
    ├── use_case.ex                      # Behavior
    └── upload_document.ex               # Upload use case

lib/jarga_web/live/documents_live/
├── index.ex                             # Document list page
└── index.html.heex                      # Template

priv/repo/migrations/
└── TIMESTAMP_create_documents.exs       # Migration

test/jarga/documents/                    # TDD tests
test/jarga_web/live/documents_live/      # LiveView tests
```

**Database Schema**:
```elixir
create table(:documents) do
  add :id, :binary_id, primary_key: true
  add :filename, :string, null: false
  add :original_filename, :string, null: false
  add :file_type, :string, null: false
  add :file_size, :integer, null: false
  add :storage_path, :string, null: false
  add :mime_type, :string, null: false
  add :status, :string, null: false, default: "uploaded"

  add :user_id, references(:users, type: :binary_id)
  add :workspace_id, references(:workspaces, type: :binary_id)
  add :project_id, references(:projects, type: :binary_id)

  timestamps()
end
```

**Routes**:
```elixir
scope "/app/workspaces/:workspace_id", JargaWeb do
  live "/documents", DocumentsLive.Index, :index
end

scope "/app/projects/:project_id", JargaWeb do
  live "/documents", DocumentsLive.Index, :index
end
```

**Boundary Configuration**:
```elixir
# lib/jarga/documents.ex
use Boundary,
  deps: [Jarga.Accounts, Jarga.Workspaces, Jarga.Projects, Jarga.Repo],
  exports: [{Document, []}]
```

### Testing Strategy

**TDD Approach**:
1. Write domain tests first (file validation)
2. Write use case tests (upload logic)
3. Write LiveView tests (UI interactions)

**Test Coverage**:
- Valid file types accepted
- Invalid file types rejected
- File size limits enforced
- Upload progress tracked
- Documents scoped to workspace/project
- Authorization checks
- Delete functionality

### Value Delivered

✅ Users can organize documents by workspace/project
✅ Foundation for processing pipeline
✅ Immediate utility (document storage/management)
✅ Clean architecture established (Boundary)

### Success Metrics

- Upload success rate > 99%
- Average upload time < 10 seconds
- Users upload multiple documents
- Documents properly scoped to workspace/project

---

## PR #3: Docling Integration & Document Processing

**Goal**: Extract structured content from documents

**Value**: Documents become searchable/queryable with rich structure

**Effort**: 5-7 days

**Depends On**: PR #2

### What's Included

✅ **Python Environment**:
- Python 3.10+ setup instructions
- Docling installation
- Python service wrapper for Elixir

✅ **Docling Integration**:
- ErlPort for Python interop
- DoclingClient module (calls Python service)
- Document parser (parses DoclingDocument JSON)
- Structure extractor (sections, tables, images)

✅ **Background Processing**:
- Oban for background jobs
- ProcessDocumentWorker
- Real-time status updates via PubSub

✅ **Database Updates**:
- Add `docling_structure` JSONB field
- Add metadata fields (page_count, table_count, etc.)
- Add processing status tracking

✅ **UI Updates**:
- Show processing status in document list
- Display extracted metadata
- Real-time status updates

### How It Works

```
User: Uploads report.pdf
System:
  1. File uploaded (PR #2 functionality)
  2. Enqueues ProcessDocumentWorker job
  3. Worker calls Docling service (Python)
  4. Docling extracts structure:
     - Page layout and reading order
     - Tables (with TableFormer AI)
     - Sections and hierarchy
     - Formulas, code blocks
     - Image classification
  5. Stores DoclingDocument JSON in database
  6. Updates status to "processed"
  7. Broadcasts update via PubSub
Result:
  - Status: "Processed"
  - Metadata visible: "15 pages, 3 tables, 2 images"
  - Structure available for search
```

### Technical Implementation

**New Files**:
```
priv/python/
└── docling_service.py              # Python wrapper for Docling

lib/jarga/documents/infrastructure/
├── docling/
│   ├── docling_client.ex           # Elixir → Python bridge
│   ├── document_parser.ex          # Parse DoclingDocument
│   └── structure_extractor.ex      # Extract semantic structure
└── workers/
    └── process_document_worker.ex  # Oban worker

lib/jarga/documents/use_cases/
└── process_document.ex             # Processing use case

config/
└── config.exs                      # Oban + Docling config
```

**Migration**:
```elixir
alter table(:documents) do
  add :docling_structure, :jsonb
  add :page_count, :integer
  add :table_count, :integer
  add :image_count, :integer
  add :has_formulas, :boolean
  add :has_code_blocks, :boolean
  add :processed_at, :utc_datetime
  modify :status, :string  # pending → processing → processed → failed
end

create index(:documents, [:docling_structure], using: :gin)
```

**Dependencies**:
```elixir
# mix.exs
{:erlport, "~> 0.11"},
{:oban, "~> 2.18"}
```

**Python Setup**:
```bash
# Development setup
python -m venv .venv
source .venv/bin/activate
pip install docling docling-core docling-ibm-models
```

**Configuration**:
```elixir
# config/config.exs
config :jarga, Oban,
  repo: Jarga.Repo,
  queues: [default: 10, documents: 5],
  plugins: [Oban.Plugins.Pruner]

config :jarga, Jarga.Documents,
  docling_python_path: ".venv/bin/python",
  docling_script_path: "priv/python/docling_service.py",
  docling_timeout: 300_000  # 5 minutes
```

### Testing Strategy

**Tests**:
- DoclingClient calls Python service
- Parses DoclingDocument JSON correctly
- Extracts structure (sections, tables, images)
- Worker processes documents
- Updates status correctly
- Handles failures gracefully
- Real-time UI updates work

**Manual Testing**:
- Upload various file types (PDF, DOCX, PPTX, XLSX)
- Verify Docling extracts structure correctly
- Check processing time (should be < 2 min for 20-page PDF)
- Verify error handling for corrupt files

### Value Delivered

✅ Rich document understanding (structure, not just text)
✅ Foundation for semantic search
✅ Users see document structure and metadata
✅ Background processing doesn't block UI

### Success Metrics

- Processing success rate > 95%
- Processing time < 2 minutes for 20-page PDF
- Extracted metadata is accurate
- UI updates in real-time

---

## PR #4: Simple Document Search in Chat

**Goal**: Chat can search within uploaded documents (keyword-based)

**Value**: Ask questions about documents without vector embeddings

**Effort**: 3-4 days

**Depends On**: PR #3

### What's Included

✅ **Chat Panel Updates**:
- Document selector component
- Context-aware filtering (auto-select workspace/project docs)
- Checkboxes for manual selection
- Document count indicator

✅ **Search Functionality**:
- Keyword search in DoclingDocument JSON
- PostgreSQL JSONB queries
- Simple relevance ranking (keyword frequency)
- Extract matching sections/paragraphs

✅ **Context Assembly**:
- Include matching sections in LLM prompt
- Basic source attribution
- Format context with document name, page, section

✅ **UI Updates**:
- Show sources below answer
- Simple source cards (document, page, section)
- Click to view document (links to document page)

### How It Works

```
User in chat panel:
  - Selects 3 documents (checkboxes)
  - Asks: "What was Q2 revenue?"

System:
  1. Keyword extraction: ["Q2", "revenue"]
  2. JSONB search in selected documents:
     SELECT * FROM documents
     WHERE id IN (selected_ids)
     AND docling_structure @> '{"texts": [{"content": "Q2"}]}'
  3. Rank results by keyword frequency
  4. Extract top 5 matching sections
  5. Format as LLM context:
     """
     Document: report.pdf, Page 5, Section: Results
     [matching text content]

     Document: data.xlsx, Sheet: Q2 Data
     [matching text content]
     """
  6. Send to Gemini with user question
  7. Stream response
  8. Show sources below answer

User sees:
  - Answer: "Q2 revenue was $120K, up 20% from Q1..."
  - Sources:
    • report.pdf (Page 5, Results section)
    • data.xlsx (Q2 Data sheet)
```

### Technical Implementation

**New Files**:
```
lib/jarga_web/live/chat_live/components/
├── document_selector.ex        # Document picker UI
└── source_block.ex             # Source citation card

lib/jarga/documents/use_cases/
└── query_documents.ex          # Basic keyword search

lib/jarga/documents/infrastructure/
└── search/
    └── keyword_searcher.ex     # JSONB keyword search
```

**Modified Files**:
```
lib/jarga_web/live/chat_live/panel.ex
  - Add document selection state
  - Add query_documents integration
  - Show sources in UI

lib/jarga/documents/documents.ex
  - Add query_documents/3 function
```

**Search Implementation**:
```elixir
def search_documents(document_ids, keywords) do
  from(d in Document,
    where: d.id in ^document_ids,
    where: fragment(
      "? @> ANY(ARRAY[?]::jsonb[])",
      d.docling_structure,
      ^build_keyword_matchers(keywords)
    )
  )
  |> Repo.all()
  |> extract_matching_sections(keywords)
  |> rank_by_relevance()
end
```

### Testing Strategy

**Tests**:
- Document selector filters by workspace/project
- Keyword search finds relevant sections
- Ranking prioritizes best matches
- Context assembly formats correctly
- Sources displayed properly
- Links to documents work

**Manual Testing**:
- Upload documents with known content
- Ask questions, verify answers are correct
- Check source attribution accuracy
- Test with multiple documents

### Value Delivered

✅ Chat works with documents immediately
✅ Validates document selection UX
✅ Validates source attribution UI
✅ Useful even without embeddings (good enough for many queries)
✅ Foundation for vector search upgrade

### Success Metrics

- Users select and query documents
- Answer relevance > 70% (user feedback)
- Response time < 5 seconds
- Users click on sources to verify

---

## PR #5: Vector Embeddings & Semantic Search

**Goal**: High-quality semantic search with embeddings

**Value**: Better answers via similarity search (understands meaning, not just keywords)

**Effort**: 5-7 days

**Depends On**: PR #4

### What's Included

✅ **Database**:
- Enable pgvector extension
- Create `document_chunks` table
- Vector indexes

✅ **Embeddings**:
- OpenAI embeddings integration
- EmbeddingService module
- Batch processing for efficiency

✅ **Chunking**:
- Structure-aware chunking policy
- Chunk documents respecting sections/tables
- Store chunks with metadata

✅ **Vector Store**:
- Store embeddings in pgvector
- Similarity search implementation
- Manage chunk lifecycle

✅ **Processing Pipeline**:
- Update ProcessDocumentWorker:
  1. Docling extraction (existing)
  2. Structure-aware chunking (new)
  3. Generate embeddings (new)
  4. Store in vector store (new)

✅ **Query Updates**:
- Replace keyword search with vector search
- Generate query embedding
- Similarity search for top K chunks
- Send to LLM as context

### How It Works

**Processing**:
```
User uploads: report.pdf
Worker:
  1. Docling extracts structure ✓ (PR #3)
  2. Chunk with structure awareness:
     - Paragraphs stay together
     - Tables stay complete
     - Respect section boundaries
  3. Generate embeddings for each chunk:
     → OpenAI API call
     → Get 1536-dim vector per chunk
  4. Store in document_chunks:
     - chunk content
     - chunk metadata (page, section, element_type)
     - embedding vector
  5. Status: "Vectorized"
```

**Query**:
```
User asks: "What was our revenue growth strategy?"
System:
  1. Generate query embedding → [0.123, -0.456, ...]
  2. Similarity search (pgvector):
     SELECT id, content,
            embedding <=> query_embedding AS distance
     FROM document_chunks
     WHERE document_id IN (selected_ids)
     ORDER BY distance
     LIMIT 10
  3. Top 10 most similar chunks returned
  4. Format as LLM context
  5. Stream answer
  6. Show sources (now more accurate!)
```

### Technical Implementation

**Migration**:
```elixir
# Enable pgvector
execute "CREATE EXTENSION IF NOT EXISTS vector"

# Create chunks table
create table(:document_chunks) do
  add :id, :binary_id, primary_key: true
  add :document_id, references(:documents, type: :binary_id)
  add :content, :text, null: false
  add :chunk_index, :integer, null: false
  add :token_count, :integer

  # Metadata
  add :element_type, :string  # text, table, picture, code
  add :page_number, :integer
  add :section_title, :string
  add :section_level, :integer

  # Vector
  add :embedding, :vector, size: 1536

  timestamps()
end

create index(:document_chunks, [:document_id])
execute "CREATE INDEX ON document_chunks USING ivfflat (embedding vector_cosine_ops)"
```

**New Files**:
```
lib/jarga/documents/
├── domain/
│   └── entities/
│       └── document_chunk.ex           # Chunk entity
├── policies/
│   └── chunking_policy.ex              # Chunking rules
└── infrastructure/
    ├── persistence/
    │   └── vector_store.ex             # Vector operations
    └── services/
        └── embedding_service.ex        # OpenAI embeddings
```

**Dependencies**:
```elixir
{:pgvector, "~> 0.3.0"},
{:openai, "~> 0.6"},
{:tiktoken, "~> 0.1"}  # Token counting
```

**Environment Variables**:
```bash
OPENAI_API_KEY=sk-...
EMBEDDING_MODEL=text-embedding-ada-002
```

### Testing Strategy

**Tests**:
- Chunks respect document structure
- Embeddings generated correctly
- Similarity search returns relevant chunks
- Vector store operations work
- Query quality improved vs keyword search

**Manual Testing**:
- Upload documents, verify chunking
- Ask questions, compare with keyword search
- Verify semantic understanding (synonyms, meaning)

### Value Delivered

✅ Significantly better search quality
✅ Handles synonyms and semantic meaning
✅ Foundation for semantic block retrieval
✅ More accurate answers

### Success Metrics

- Answer relevance > 80% (improved from 70%)
- Response time still < 5 seconds
- Users prefer semantic search over keyword
- Embedding generation < 30 seconds per document

---

## PR #6: Semantic Block Retrieval & Enhanced Sources

**Goal**: Return complete semantic blocks, not fragments

**Value**: Users get verifiable, complete sources (full sections/tables)

**Effort**: 4-5 days

**Depends On**: PR #5

### What's Included

✅ **Semantic Expansion**:
- SemanticExpander module
- Expand chunks to full semantic blocks:
  - Chunk in table → full table
  - Chunk in paragraph → full paragraph
  - Chunk in section → full section

✅ **Block Reranking**:
- BlockReranker module
- Rerank expanded blocks by relevance
- Deduplicate overlapping blocks
- Apply token limits

✅ **Enhanced Query Pipeline**:
1. Vector search (existing)
2. Expand chunks to blocks (new)
3. Rerank & deduplicate (new)
4. Send expanded context to LLM (updated)
5. Return answer + full source blocks (updated)

✅ **UI Enhancements**:
- Expandable source cards
- Show full semantic blocks
- Syntax highlighting for tables/code
- Metadata display (element type, page, section)
- "View in Document" button

### How It Works

**Query Flow**:
```
User asks: "What were Q2 results?"

System:
  1. Vector search → 10 chunks
     Chunk #3: "...Q2 revenue of $120K..."
     Chunk #7: "...20% growth in Q2..."

  2. Semantic Expansion:
     Chunk #3 is part of Table 1
     → Expand to full table:
     """
     Table 1: Quarterly Results
     | Quarter | Revenue | Growth | Customers |
     | Q1      | $100K   | 10%    | 1,200     |
     | Q2      | $120K   | 20%    | 1,500     |

     The table shows strong growth...
     """

  3. Reranking:
     - Score blocks by relevance + element type
     - Remove duplicates
     - Select top 3-5 blocks

  4. LLM Context (expanded):
     - Full tables, not fragments
     - Complete paragraphs
     - Full sections with hierarchy

  5. User sees:
     Answer: "Q2 results showed 20% growth..."

     Sources (expandable cards):
     ┌────────────────────────────────────┐
     │ 📊 report.pdf • Page 5 • Results   │
     │ Table: Quarterly Results           │
     │ [Full table shown]                 │
     │ [Collapse ↑] [View in Doc →]      │
     └────────────────────────────────────┘
```

### Technical Implementation

**New Files**:
```
lib/jarga/documents/infrastructure/retrieval/
├── semantic_expander.ex        # Expand chunks to blocks
└── block_reranker.ex           # Rerank & deduplicate

lib/jarga_web/live/chat_live/components/
└── enhanced_source_block.ex    # Expandable source cards
```

**Modified Files**:
```
lib/jarga/documents/use_cases/query_documents.ex
  - Add expansion step
  - Add reranking step
  - Return full blocks in response

lib/jarga_web/live/chat_live/panel.ex
  - Display enhanced source blocks
  - Handle expand/collapse
```

**Database Updates**:
```elixir
# Add JSON Pointer reference to chunks
alter table(:document_chunks) do
  add :docling_ref, :string  # e.g., "/body/0/children/2"
end
```

**Expansion Algorithm**:
```elixir
def expand_chunk_to_block(chunk, docling_document) do
  # Use docling_ref to navigate structure
  json_pointer = chunk.docling_ref  # "/body/0/children/2"

  # Get element from DoclingDocument
  element = get_by_pointer(docling_document, json_pointer)

  case element.type do
    :table -> extract_full_table(element)
    :paragraph -> extract_full_paragraph(element)
    :section -> extract_section_or_page(element)
    :list -> extract_full_list(element)
    :code -> extract_code_block(element)
  end
end
```

### Testing Strategy

**Tests**:
- Chunks expand to correct semantic blocks
- Tables remain intact (not split)
- Reranking removes duplicates
- Top blocks are most relevant
- UI displays expanded blocks correctly
- Expand/collapse animations work

**Manual Testing**:
- Ask questions, verify source completeness
- Expand sources, check full content is visible
- Verify tables are properly formatted
- Test with various document types

### Value Delivered

✅ Complete, verifiable sources (not fragments)
✅ Better LLM understanding (full context)
✅ Professional, trustworthy answers
✅ Users can verify information easily

### Success Metrics

- Answer relevance > 85% (improved from 80%)
- Users expand sources to verify
- Source completeness = 100% (no fragments)
- User satisfaction with answer quality

---

## PR #7: Chat History & Sessions

**Goal**: Persistent conversations across navigation

**Value**: Users don't lose context when navigating

**Effort**: 2-3 days

**Depends On**: PR #1 (can be done anytime after)

### What's Included

✅ **Database**:
- `chat_sessions` table
- `chat_messages` table

✅ **Session Management**:
- Create new session on first message
- Save messages to database
- Restore session on panel mount
- Auto-generate session titles

✅ **UI Features**:
- "New conversation" button
- Session selector dropdown
- "View all conversations" page
- Session metadata (created_at, message count)

✅ **Persistence**:
- Chat history survives navigation
- Chat history survives browser refresh
- Multi-turn conversations supported

### How It Works

```
User Flow:
  1. Opens chat panel
  2. Asks: "What's the project deadline?"
  3. Gets answer
  4. Navigates to different page
  5. Opens chat panel
  6. Previous conversation still there!
  7. Asks follow-up: "And what about the budget?"
  8. LLM has context from previous messages

Session Management:
  - First message creates new session
  - Session ID stored in panel state
  - Messages saved to database on send/receive
  - Session restored on mount via session_id
  - "New conversation" creates new session
```

### Technical Implementation

**Migrations**:
```elixir
create table(:chat_sessions) do
  add :id, :binary_id, primary_key: true
  add :title, :string
  add :user_id, references(:users, type: :binary_id)
  add :workspace_id, references(:workspaces, type: :binary_id)
  add :project_id, references(:projects, type: :binary_id)
  timestamps()
end

create table(:chat_messages) do
  add :id, :binary_id, primary_key: true
  add :chat_session_id, references(:chat_sessions, type: :binary_id)
  add :role, :string, null: false  # "user", "assistant"
  add :content, :text, null: false
  add :context_chunks, {:array, :binary_id}, default: []  # Source chunk IDs
  timestamps()
end

create index(:chat_messages, [:chat_session_id])
```

**New Files**:
```
lib/jarga/documents/
├── chat_session.ex             # Ecto schema
├── chat_message.ex             # Ecto schema
└── use_cases/
    ├── create_session.ex       # New conversation
    ├── save_message.ex         # Save to DB
    └── load_session.ex         # Restore history

lib/jarga_web/live/chat_live/
└── sessions_live.ex            # "View all" page
```

**Modified Files**:
```
lib/jarga_web/live/chat_live/panel.ex
  - Load session on mount
  - Save messages after send/receive
  - Handle "new conversation"
  - Handle session selection
```

### Testing Strategy

**Tests**:
- Session created on first message
- Messages saved to database
- Session restored correctly
- "New conversation" creates new session
- Multi-turn conversations work
- Authorization (users can't see others' sessions)

**Manual Testing**:
- Have conversation, navigate away, return
- Refresh browser, verify history persists
- Test multi-turn conversations
- Test "View all conversations"

### Value Delivered

✅ Persistent chat history
✅ Multi-turn conversations
✅ Return to previous conversations
✅ Better UX (no lost context)

### Success Metrics

- Users engage in multi-turn conversations
- Average conversation length > 3 messages
- Users return to previous conversations
- Session restore works 100% of time

---

## PR #8: Polish & Advanced Features (Optional)

**Goal**: Production-ready polish and nice-to-have features

**Value**: Enhanced UX, monitoring, and enterprise features

**Effort**: 3-4 days

**Depends On**: All previous PRs

### What's Included

✅ **Export Features**:
- Export conversation as Markdown
- Export conversation as PDF
- Copy answer to clipboard (enhanced)

✅ **Feedback System**:
- Feedback buttons (👍 👎) per answer
- Store feedback in database
- Analytics dashboard for feedback

✅ **Usage Tracking**:
- Token usage per query
- Token usage per user/workspace
- Cost tracking
- Usage reports

✅ **UX Polish**:
- Loading states refined
- Error messages improved
- Animations polished
- Keyboard shortcuts complete
- Mobile optimizations
- Accessibility improvements (ARIA labels)

✅ **Monitoring & Telemetry**:
- Query performance metrics
- LLM response time tracking
- Error rate monitoring
- Usage analytics

✅ **Advanced Features**:
- Regenerate answer button
- Share conversation link
- Copy conversation link
- Search within conversation

### Technical Implementation

**New Files**:
```
lib/jarga/documents/
├── chat_feedback.ex            # Ecto schema
└── use_cases/
    ├── export_conversation.ex  # Export as MD/PDF
    └── record_feedback.ex      # Store feedback

lib/jarga_web/live/analytics_live/
└── chat_analytics.ex           # Usage dashboard

lib/jarga/documents/telemetry/
└── chat_reporter.ex            # Custom telemetry
```

**Modified Files**:
- Enhanced error handling throughout
- Refined loading states
- Polished animations
- Complete keyboard shortcuts

### Testing Strategy

**Tests**:
- Export functionality works
- Feedback stored correctly
- Usage tracking accurate
- Analytics dashboard loads
- All edge cases handled

**Manual Testing**:
- Test all features end-to-end
- Performance testing
- Accessibility audit
- Mobile device testing
- Error scenario testing

### Value Delivered

✅ Production-ready quality
✅ Monitoring and observability
✅ Enterprise features (export, analytics)
✅ Excellent user experience

### Success Metrics

- Error rate < 0.1%
- User satisfaction > 90%
- All features work smoothly
- Performance meets targets

---

## 📊 Summary Table

| PR | Feature | Value | Effort | Dependencies | Deployable? |
|----|---------|-------|--------|--------------|-------------|
| #1 | Chat panel + page content | Immediate AI help | 3-5d | None | ✅ Yes |
| #2 | Document upload | Doc management | 4-6d | #1 | ✅ Yes |
| #3 | Docling processing | Structure extraction | 5-7d | #2 | ✅ Yes |
| #4 | Keyword search | Basic doc chat | 3-4d | #3 | ✅ Yes |
| #5 | Vector embeddings | Semantic search | 5-7d | #4 | ✅ Yes |
| #6 | Semantic blocks | Complete sources | 4-5d | #5 | ✅ Yes |
| #7 | Chat history | Persistence | 2-3d | #1 | ✅ Yes |
| #8 | Polish | Production-ready | 3-4d | All | ✅ Yes |

**Total**: 29-41 days (5-8 weeks) if done sequentially

---

## 🎯 Implementation Approach

### Incremental Delivery Strategy

This feature will be delivered as **8 individual PRs**, each adding independent value and able to be deployed to production.

**Why Incremental?**
- ✅ Smallest PRs = easiest review and safest deployment
- ✅ Each PR adds value independently
- ✅ Can pivot based on user feedback after each release
- ✅ Faster time to initial user value
- ✅ Lower risk per deployment
- ✅ Validates assumptions early

**Timeline**: 8 deployments over 5-8 weeks (29-41 days total)

**Deployment Cadence**: Ship each PR as soon as it's ready and tested

---

## 🚀 Getting Started

### For PR #1 (Start Here):

1. **Setup**:
   ```bash
   git checkout -b chat-with-docs/pr-1-chat-panel
   ```

2. **Create OpenRouter Account**:
   - Sign up at https://openrouter.ai
   - Get API key
   - Add to `.env`: `OPENROUTER_API_KEY=sk-or-...`

3. **Follow TDD**:
   - Write panel component test first
   - Write LLM client test
   - Implement step by step
   - Commit on green

4. **Manual Testing Checklist**:
   - [ ] Panel opens/closes smoothly
   - [ ] Extracts page content
   - [ ] Sends to LLM successfully
   - [ ] Streams response in real-time
   - [ ] Keyboard shortcuts work (Cmd+K)
   - [ ] Mobile full-screen overlay works
   - [ ] State persists in localStorage

5. **Submit PR**:
   - Follow Git Safety Protocol from CLAUDE.md
   - Run `mix precommit`
   - Create PR with description from this doc
   - Request review

### Success Criteria for PR #1:

- ✅ All tests pass
- ✅ Panel works on desktop + mobile
- ✅ LLM responses stream correctly
- ✅ No Boundary violations
- ✅ Ready to ship to production

---

## 📝 Notes

- Each PR should follow the TDD approach outlined in CLAUDE.md
- All PRs must pass `mix precommit` (includes boundary checks)
- Use Mox for external service testing (LLM, OpenAI)
- Update this document as PRs evolve based on learnings

---

## 🎯 Next Steps

**Ready to start?**

Begin with **PR #1: Global Chat Panel** following the setup instructions above.

Each PR builds on the previous one, creating a complete document chat system by PR #8.
