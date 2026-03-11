# PKM Reader User Guide

PKM Reader is an iOS app for browsing your Personal Knowledge Management vault. It connects to a cloud backend that automatically processes your Obsidian markdown documents, classifying them with AI, extracting entities, and generating daily summaries and weekly reports.

## Getting Started

### Signing In

1. Open PKM Reader on your iPhone.
2. Enter the email and password associated with your account.
3. Tap **Sign In**.

If you see an error, verify your credentials and check your internet connection. Contact your system administrator if you need an account or a password reset.

### Navigation

The app uses a tab bar at the bottom of the screen with four tabs:

| Tab | Purpose |
|-----|---------|
| **Documents** | Browse, search, filter by tag/classification, create, edit, and delete documents |
| **Insights** | Monthly calendar view with daily summaries and weekly reports |
| **Settings** | Manage preferences, cache, and your account |
| **Graph** | Interactive knowledge graph of entity relationships |

## Documents

The Documents tab displays all documents in your vault, sorted by modification date (most recent first).

### Browsing Documents

- Scroll through the list to browse your documents.
- Each row shows the document title, classification badge, and modification date.
- Tap a document to view its full content.
- Pull down on the list to refresh and load the latest documents from the server.
- The list loads more documents automatically as you scroll to the bottom.

### Searching Documents

The Documents tab includes an integrated search bar at the top:

1. Tap the search bar and type at least 2 characters to begin searching.
2. Results appear automatically as you type (with a short delay to avoid excessive requests).
3. Toggle between **Keyword** and **Semantic** search modes. Keyword matches titles, paths, and tags. Semantic search finds conceptually related documents using AI embeddings.
4. Tap a result to open the document detail view.
5. Browse state is preserved while searching — dismiss the search to return to your previous position.

### Filtering by Classification and Tags

Tap the filter icon in the top-right corner to open the filter sheet, which has two sections:

**Classification filter:** Your documents are automatically classified by AI into five categories:

| Classification | Description |
|----------------|-------------|
| **Meeting** | Meeting notes and agendas |
| **Idea** | Ideas, brainstorms, and creative notes |
| **Reference** | Reference material, documentation, and guides |
| **Journal** | Journal entries and daily logs |
| **Project** | Project plans, specifications, and task lists |

Select a classification or choose **All Documents** to remove the filter.

**Tag filter:** Browse all tags used across your vault with document counts. Tap a tag to filter the document list to only documents with that tag. Tag and classification filters can be combined.

When any filter is active, the filter icon appears filled in.

### Document Detail

Tapping a document opens the detail view, which shows:

- **Classification badge** -- the AI-assigned category for this document. Tap the badge to change the classification.
- **Tags** -- any tags from the document's frontmatter, displayed as chips.
- **Extracted entities** -- people, organizations, concepts, and locations that the AI identified in the document.
- **Dates** -- when the document was created and when it was last modified.
- **Content** -- the full markdown content of the document, rendered with formatting. Internal `[[wikilinks]]` are rendered as tappable navigation links. Checkboxes are rendered visually.

You can select and copy text from the document content.

### Creating and Editing Documents

Admin users can create and edit documents directly from the app:

- **Create**: Tap the **+** button in the Documents tab to open the editor. Enter the document path (for example, `notes/my-note.md`), optionally a title, and the markdown content, then save.
- **Edit**: In the document detail view, tap the **...** actions menu in the top-right corner and choose **Edit** to modify the document content.
- **Delete**: In the document detail view, tap the **...** actions menu in the top-right corner and choose **Delete**. A confirmation prompt appears before deletion.

## Search Monitors

Search monitors let you track topics across the web over time. Access them via the binoculars icon in the Documents tab toolbar.

- **Create a monitor**: Tap the **+** button, enter a search term, configure the schedule and novelty threshold, then save.
- **View summaries**: Tap a monitor to see its AI-generated summaries of web search results, with novelty scores indicating how significant each update is.
- **Manage monitors**: Edit, pause, or delete monitors from the detail view.
- When a monitor detects significant new results (above the novelty threshold), you receive a push notification.

## Insights

The Insights tab displays a monthly calendar grid showing your vault activity at a glance.

### Calendar View

- Navigate between months using the left/right arrows.
- Days with **daily summaries** are indicated with a dot. Tap a day to view its summary.
- Weeks with **weekly reports** are indicated with a bar along the week row. Tap the bar to view the report.
- The current day is highlighted.

### Daily Summaries

Summaries are generated every day at 6 AM UTC. Each summary covers the previous day's vault activity, highlighting new and modified documents, key themes, and notable changes.

### Weekly Reports

Reports are generated every Sunday at 8 PM UTC. Each report provides a broader analysis of the week, including trends, patterns, and connections across your documents.

## Graph

The Graph tab displays an interactive knowledge graph showing relationships between entities extracted from your documents.

- Nodes represent entities (people, organizations, concepts, locations) and are color-coded by type or classification.
- Edges connect entities that appear together in documents.
- Tap a node to see related documents and navigate to them.
- Pinch to zoom and drag to pan the graph.

## Settings

### Display Preferences

- **Compact List Mode** -- reduces spacing in document lists for denser viewing.
- **Show Document Previews** -- toggles content previews in document list rows.

### Storage

- **Clear Cache** -- removes all locally cached documents and data. This frees storage space but means documents will need to be re-downloaded from the server.

### Account

- **Sign Out** -- signs you out of your account. You will need to sign in again to access your vault. A confirmation prompt appears before signing out.
- **Version** -- displays the current app version and build number.

## Offline Mode

PKM Reader caches documents locally so you can continue browsing previously viewed content when you lose internet connectivity.

### What Works Offline

- Viewing documents that have been loaded within the last hour.
- Browsing previously loaded document lists.

### What Requires Internet

- Loading new documents or refreshing lists.
- Searching for documents.
- Loading daily summaries and weekly reports.
- Receiving push notifications.
- Signing in.

### How It Works

- Documents are cached automatically when you view them.
- The cache expires after 1 hour -- stale entries are not shown.
- When the device is offline, an orange banner reading "No internet connection" appears at the top of the screen.
- Use **Settings > Clear Cache** to manually remove cached data.

## Troubleshooting

### Cannot Sign In

- Verify your email and password are correct.
- Check that your device has an internet connection.
- If you have forgotten your password, contact your system administrator for a reset.

### Documents Not Loading

- Pull down on the list to refresh.
- Check the internet connection. If the offline banner is visible, wait for connectivity to restore.
- Try clearing the cache in Settings and refreshing.

### Search Returns No Results

- Ensure you have typed at least 2 characters.
- Try broader search terms. The search matches against document titles, paths, and tags.
- Pull down to retry the search.

### Stale or Missing Data

- Pull down on any list to refresh from the server.
- Clear the cache in Settings to remove outdated local data.
- Documents sync from your Obsidian vault to the cloud every 5 minutes. Very recent edits may not yet be available.

### App Shows "No Internet Connection" Banner

- Check your Wi-Fi or cellular connection.
- The banner disappears automatically when connectivity is restored.
- You can still browse cached documents while offline.
