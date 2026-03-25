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

            HouseholdDashboardView()
                .tabItem {
                    Label("Household", systemImage: "house.fill")
                }
                .tag(3)
                .keyboardShortcut("4")

            BusinessView()
                .tabItem {
                    Label("Business", systemImage: "briefcase.fill")
                }
                .tag(4)
                .keyboardShortcut("5")

            APIServerView()
                .tabItem {
                    Label("API", systemImage: "server.rack")
                }
                .tag(5)
                .keyboardShortcut("6")
        }
        .frame(minWidth: 560, minHeight: 400)
    }
}
