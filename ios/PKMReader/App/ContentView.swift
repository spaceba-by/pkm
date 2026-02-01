import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("PKM Reader")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your Personal Knowledge Base")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Documents")
            .accessibilityIdentifier("PKM Reader")
        }
    }
}

#Preview {
    ContentView()
}
