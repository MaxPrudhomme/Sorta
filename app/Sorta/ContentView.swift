import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @State private var selectedView: SelectedView? = nil
    @State private var recentFiles: [String] = ["File A", "File B", "File C", "File D"]
    
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

struct HelperAppLauncher {
    static func startHelperIfNeeded() {
        let isRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.maxprudhomme.SortaHelper"
        }

        if !isRunning {
            guard let helperURL = Bundle.main.url(forAuxiliaryExecutable: "Contents/Library/LoginItems/SortaHelper.app") else {
                print("Could not find helper app")
                return
            }

            let config = NSWorkspace.OpenConfiguration()
            config.activates = false

            NSWorkspace.shared.openApplication(at: helperURL, configuration: config) { app, error in
                if let error = error {
                    print("Failed to launch helper: \(error.localizedDescription)")
                } else {
                    print("Helper started successfully")
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
}
