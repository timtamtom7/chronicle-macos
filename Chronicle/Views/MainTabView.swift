import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            BillListView()
                .tabItem {
                    Label("Bills", systemImage: "list.bullet.rectangle")
                }
                .tag(0)
                .keyboardShortcut("1")

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(1)
                .keyboardShortcut("2")

            OverviewView()
                .tabItem {
                    Label("Overview", systemImage: "chart.bar")
                }
                .tag(2)
                .keyboardShortcut("3")
        }
        .frame(minWidth: 560, minHeight: 400)
    }
}
