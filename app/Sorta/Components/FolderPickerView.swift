//
//  FolderPickerView.swift
//  Sorta
//
//  Created by Max PRUDHOMME on 15/04/2025.
//


import SwiftUI

struct FolderPickerView: View {
    @Binding var selectedPath: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Select a folder to monitor")
                .font(.headline)
                .padding()
            
            Button("Choose Folder") {
                selectFolder()
            }
            
            Button("Cancel") {
                dismiss()
            }
            .padding(.bottom)
        }
        .frame(width: 300, height: 200)
    }
    
    private func selectFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                selectedPath = url.path
                dismiss()
            } else {
                dismiss()
            }
        }
    }
}
