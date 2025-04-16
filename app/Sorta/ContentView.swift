import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @State private var selectedView: SelectedView? = nil
    @State private var recentFiles: [String] = []
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedView) {
                Section(header: Text("Recent Files")) {
                    ForEach(recentFiles, id: \.self) { file in
                        NavigationLink(value: SelectedView.file(URL(string: file)!)) {
                            Text(file)
                        }
                    }
                }

                Section {
                    NavigationLink(value: SelectedView.settings) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
        } detail: {
            switch selectedView {
                case .settings:
                    SettingsView()
                    .navigationTitle("Settings")
                case .file(let fileURL):
                    Text("You selected file: \(fileURL.lastPathComponent)")
                        .font(.headline)
                        .padding()
                        .navigationTitle(fileURL.lastPathComponent)
                case .none:
                    Text("Select a section")
                        .font(.title)
                        .foregroundColor(.gray)
                        .navigationTitle("Sorta")
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
        
    enum SelectedView: Hashable {
        case file(URL)
        case settings
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
}
