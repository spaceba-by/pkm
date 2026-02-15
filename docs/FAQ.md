# PKM Reader FAQ

## General

### How do I get an account?

Accounts are created by a system administrator using AWS Cognito. Contact your administrator to request access. You will receive an email address and password to sign in.

### What is PKM Reader?

PKM Reader is an iOS app for browsing a Personal Knowledge Management vault. It connects to a cloud backend that processes your Obsidian markdown documents, applying AI classification, entity extraction, and automated summarization.

### What devices are supported?

PKM Reader runs on iPhone with iOS 26 or later.

## Documents

### How do documents get into the system?

Documents are synced automatically from your local Obsidian vault to the cloud using rclone. The sync runs every 5 minutes by default. Once documents arrive in the cloud, they are automatically processed by the AI pipeline.

### How does AI classification work?

When a document is synced to the cloud, an AI model (Claude via Amazon Bedrock) reads the content and assigns one of five classifications: Meeting, Idea, Reference, Journal, or Project. The classification is based on the content and structure of the document.

### What are extracted entities?

The AI also identifies key entities mentioned in each document:

- **People** -- names of individuals
- **Organizations** -- companies, teams, and institutions
- **Concepts** -- topics and abstract ideas
- **Locations** -- places and geographic references

These appear in the document detail view.

### Can I edit documents in the app?

No. PKM Reader is currently a read-only viewer. Edit your documents in Obsidian, and the changes will sync to the app automatically.

### Why is a document missing from the app?

- The sync runs every 5 minutes. If you just created the document, wait for the next sync cycle.
- Check that the document is in a location covered by your rclone sync configuration.
- If the document still does not appear, try pulling down to refresh the document list.

## Insights

### What do daily summaries contain?

Daily summaries are generated every day at 6 AM UTC. They cover the previous day's vault activity, highlighting new and modified documents, recurring themes, and notable changes. The summary is written by an AI model (Claude Sonnet via Amazon Bedrock).

### What do weekly reports contain?

Weekly reports are generated every Sunday at 8 PM UTC. They provide a higher-level analysis of the week, covering trends across your vault, connections between documents, and patterns in your note-taking activity.

### Why are there no summaries or reports yet?

Summaries and reports are generated on a schedule. If the system was recently set up, there may not be enough data or enough time may not have passed for the first generation cycle to run.

## Connectivity and Offline

### What happens when I lose internet?

An orange banner appears at the top of the screen. You can still browse documents that were cached within the last hour. Features that require the server (search, loading new documents, insights) will not work until connectivity is restored.

### How long does the cache last?

Cached documents expire after 1 hour. After that, they are no longer shown and must be re-downloaded from the server.

### How do I clear the cache?

Go to Settings and tap **Clear Cache**. This removes all locally stored documents and frees storage space.

## Troubleshooting

### I forgot my password. How do I reset it?

Contact your system administrator. Password resets are managed through AWS Cognito.

### The app is showing outdated information.

Pull down on any list to refresh data from the server. You can also clear the cache in Settings to remove stale local data.

### Search is not finding a document I know exists.

Search matches against document titles, file paths, and tags. Try different terms. Also make sure you have typed at least 2 characters, as the search does not activate with fewer.

### The app feels slow or unresponsive.

- Clear the cache in Settings to free up local storage.
- Check your internet connection; slow network can cause delays in loading content.
- Force-quit and relaunch the app if the issue persists.
