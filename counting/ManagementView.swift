import SwiftUI
import SwiftData

struct ManagementView: View {
    @Query(sort: \CounterItem.createdAt, order: .reverse) var counters: [CounterItem]
    @Query(sort: \TimerItem.createdAt, order: .reverse) var timerItems: [TimerItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("lastSelectedCounterID") private var lastSelectedCounterID: String = ""
    @AppStorage("lastSelectedTimerID") private var lastSelectedTimerID: String = ""
    
    @State private var editingCounter: CounterItem?
    @State private var newName: String = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Counters")) {
                    ForEach(counters) { counter in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(counter.name)
                                    .font(.headline)
                                Text(String.localizedStringWithFormat(NSLocalizedString("Total: %lld", comment: ""), Int64(counter.totalCount)))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if counter.id.uuidString == lastSelectedCounterID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            
                            Button(action: {
                                editingCounter = counter
                                newName = counter.name
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .padding(.leading, 8)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            lastSelectedCounterID = counter.id.uuidString
                            counter.lastAccessedAt = Date()
                            dismiss()
                        }
                    }
                    .onDelete(perform: deleteCounters)
                }
                
                Section(header: Text("Timers")) {
                    ForEach(timerItems) { item in
                        HStack {
                            Text(item.name)
                                .font(.headline)
                            Spacer()
                            if item.id.uuidString == lastSelectedTimerID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            lastSelectedTimerID = item.id.uuidString
                            item.lastAccessedAt = Date()
                            dismiss()
                        }
                    }
                    .onDelete(perform: deleteTimerItems)
                    
                    Button(action: addTimerItemQuick) {
                        Label("Add Timer", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Manage")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .alert("Rename Counter", isPresented: Binding(
                get: { editingCounter != nil },
                set: { if !$0 { editingCounter = nil } }
            )) {
                TextField("New Name", text: $newName)
                Button("Cancel", role: .cancel) { editingCounter = nil }
                Button("Save") {
                    if let counter = editingCounter {
                        counter.name = newName
                    }
                    editingCounter = nil
                }
            } message: {
                Text("Enter a new name for this counter.")
            }
        }
    }
    
    private func deleteCounters(offsets: IndexSet) {
        for index in offsets {
            let counter = counters[index]
            if counter.id.uuidString == lastSelectedCounterID {
                lastSelectedCounterID = ""
            }
            modelContext.delete(counter)
        }
    }
    
    private func deleteTimerItems(offsets: IndexSet) {
        for index in offsets {
            let item = timerItems[index]
            if item.id.uuidString == lastSelectedTimerID {
                lastSelectedTimerID = ""
            }
            modelContext.delete(item)
        }
    }
    
    private func addTimerItemQuick() {
        let item = TimerItem(name: nextAvailableTimerName())
        modelContext.insert(item)
        lastSelectedTimerID = item.id.uuidString
    }
    
    private func nextAvailableTimerName() -> String {
        nextAvailableName(base: NSLocalizedString("Plank", comment: ""), existingNames: timerItems.map(\.name))
    }
    
    private func nextAvailableName(base: String, existingNames: [String]) -> String {
        guard existingNames.contains(base) else { return base }
        var index = 2
        while existingNames.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }
    
}
