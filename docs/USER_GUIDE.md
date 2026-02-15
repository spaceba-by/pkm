# PKM Reader User Guide

PKM Reader is an iOS app for browsing your Personal Knowledge Management vault. It connects to a cloud backend that automatically processes your Obsidian markdown documents, classifying them with AI, extracting entities, and generating daily summaries and weekly reports.

## Getting Started

### Signing In

1. Open PKM Reader on your iPhone.
2. Enter the email and password associated with your account.
3. Tap **Sign In**.

If you see an error, verify your credentials and check your internet connection. Contact your system administrator if you need an account or a password reset.

### Navigation

The app uses a tab bar at the bottom of the screen with five tabs:

| Tab | Purpose |
|-----|---------|
| **Documents** | Browse all documents in your vault |
| **Search** | Find documents by title, path, or tags |
| **Tags** | Browse documents organized by tag |
| **Insights** | View AI-generated daily summaries and weekly reports |
| **Settings** | Manage preferences, cache, and your account |

## Documents

The Documents tab displays all documents in your vault, sorted by modification date (most recent first).

### Browsing Documents

- Scroll through the list to browse your documents.
- Each row shows the document title, classification badge, and modification date.
- Tap a document to view its full content.
- Pull down on the list to refresh and load the latest documents from the server.
- The list loads more documents automatically as you scroll to the bottom.

### Filtering by Classification

Your documents are automatically classified by AI into five categories:

| Classification | Description |
|----------------|-------------|
| **Meeting** | Meeting notes and agendas |
| **Idea** | Ideas, brainstorms, and creative notes |
| **Reference** | Reference material, documentation, and guides |
| **Journal** | Journal entries and daily logs |
| **Project** | Project plans, specifications, and task lists |

To filter documents:

1. Tap the filter icon in the top-right corner.
2. Select a classification or choose **All Documents** to remove the filter.
3. Tap **Apply**.

When a filter is active, the filter icon appears filled in.

### Document Detail

Tapping a document opens the detail view, which shows:

- **Classification badge** -- the AI-assigned category for this document.
- **Tags** -- any tags from the document's frontmatter, displayed as chips.
- **Extracted entities** -- people, organizations, concepts, and locations that the AI identified in the document.
- **Dates** -- when the document was created and when it was last modified.
- **Content** -- the full markdown content of the document, rendered with formatting.

You can select and copy text from the document content.

## Search

The Search tab lets you find documents by title, path, or tags.

1. Tap the search bar at the top of the screen.
2. Type at least 2 characters to begin searching.
3. Results appear automatically as you type (with a short delay to avoid excessive requests).
4. Tap a result to open the document detail view.

Pull down on the results to refresh the search.

## Tags

The Tags tab shows all tags used across your vault, along with a count of how many documents use each tag.

- Tags are listed alphabetically.
- Tap a tag to see all documents that have that tag.
- Pull down on the list to refresh the tags.

## Insights

The Insights tab provides AI-generated analysis of your vault activity, split into two sections accessible via the segmented control at the top.

### Daily Summaries

Summaries are generated every day at 6 AM UTC. Each summary covers the previous day's vault activity, highlighting new and modified documents, key themes, and notable changes.

- Tap a summary to read the full content.
- Pull down to refresh.

### Weekly Reports

Reports are generated every Sunday at 8 PM UTC. Each report provides a broader analysis of the week, including trends, patterns, and connections across your documents.

- Tap a report to read the full content.
- Pull down to refresh.

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
