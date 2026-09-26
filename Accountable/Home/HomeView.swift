import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingApps = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Card {
                        Text("You're set up")
                            .font(.headline)
                        Text("Holding you to \(model.state.selection.summary).")
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Accountable")
            .toolbar {
                Button("Apps") { editingApps = true }
            }
            .sheet(isPresented: $editingApps) {
                AppPickerView(isEditing: true)
            }
        }
    }
}
