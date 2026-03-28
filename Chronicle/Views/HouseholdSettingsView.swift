import SwiftUI

// MARK: - Household Settings View

struct HouseholdSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var householdService = HouseholdService.shared
    @State private var showCreateHousehold = false
    @State private var showAddMember = false
    @State private var showLeaveConfirmation = false
    @State private var showQRCode = false
    @State private var newHouseholdName = ""
    @State private var newOwnerName = ""
    @State private var newMemberName = ""
    @State private var selectedAvatar = "person.circle.fill"
    @State private var selectedRole: HouseholdMember.Role = .member
    @State private var showAvatarPicker = false
    @State private var showInviteSheet = false

    private let avatarOptions = [
        "person.circle.fill",
        "person.circle",
        "star.circle.fill",
        "heart.circle.fill",
        "house.circle.fill",
        "car.circle.fill",
        "airplane.circle.fill",
        "bicycle.circle.fill",
        "tram.circle.fill",
        "cup.and.saucer.circle.fill",
        "fork.knife.circle.fill",
        "film.circle.fill",
        "gamecontroller.circle.fill",
        "headphones.circle.fill",
        "tv.circle.fill"
    ]

    var body: some View {
        Group {
            if householdService.household != nil {
                settingsContent
            } else {
                createHouseholdPrompt
            }
        }
        .frame(minWidth: 480, minHeight: 400)
        .sheet(isPresented: $showCreateHousehold) { createHouseholdSheet }
        .sheet(isPresented: $showAddMember) { addMemberSheet }
        .sheet(isPresented: $showLeaveConfirmation) { leaveConfirmationSheet }
        .sheet(isPresented: $showInviteSheet) { inviteSheet }
    }

    // MARK: - Create Household Prompt

    private var createHouseholdPrompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "house.fill")
                .font(.system(size: 56))
                .foregroundColor(Theme.textTertiary)
                .accessibilityHidden(true)

            Text("No Household Yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("Create a household to share bills with your family or roommates, split expenses, and track who owes whom.")
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: 360)

            Button("Create Household") {
                newOwnerName = ""
                newHouseholdName = ""
                showCreateHousehold = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Create household")
        }
        .padding(40)
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Household Name Header
                headerSection

                Divider()

                // Members Section
                membersSection

                Divider()

                // Actions Section
                actionsSection
            }
            .padding(24)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(householdService.household?.name ?? "My Household")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("\(householdService.household?.members.count ?? 0) members")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Button("Invite Someone") {
                    showInviteSheet = true
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Invite someone to household")
            }
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Members")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                if isCurrentUserAdmin {
                    Button {
                        newMemberName = ""
                        selectedAvatar = "person.circle.fill"
                        selectedRole = .member
                        showAddMember = true
                    } label: {
                        Label("Add Member", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Add member")
                }
            }

            if let members = householdService.household?.members {
                ForEach(members) { member in
                    memberRow(member)
                }
            }
        }
    }

    private func memberRow(_ member: HouseholdMember) -> some View {
        let avatarColor = Color(hex: member.colorHex)
        let isCurrentUser = member.id == householdService.currentMember?.id

        return HStack(spacing: 12) {
            Image(systemName: member.avatarName)
                .font(.title2)
                .foregroundColor(avatarColor)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(.body)
                        .foregroundColor(Theme.textPrimary)
                    if isCurrentUser {
                        Text("(you)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                HStack(spacing: 4) {
                    roleBadge(member.role)
                    if member.isOwner {
                        Text("Owner")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            Spacer()

            if isCurrentUserAdmin && !isCurrentUser {
                Button {
                    householdService.removeMember(member.id)
                } label: {
                    Image(systemName: "person.badge.minus")
                        .foregroundColor(Theme.danger)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(member.name)")
                .contextMenu {
                    Button("Remove \(member.name)", role: .destructive) {
                        householdService.removeMember(member.id)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Theme.surfaceSecondary)
        .cornerRadius(Theme.radiusSmall)
        .accessibilityLabel("\(member.name), \(member.role.rawValue)\(isCurrentUser ? ", you" : "")")
    }

    private func roleBadge(_ role: HouseholdMember.Role) -> some View {
        let (text, color): (String, Color) = {
            switch role {
            case .admin: return ("Admin", Theme.danger)
            case .member: return ("Member", Theme.accent)
            case .viewer: return ("Viewer", Theme.textTertiary)
            }
        }()

        return Text(text)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.8))
            .cornerRadius(4)
    }

    private var isCurrentUserAdmin: Bool {
        householdService.currentMember?.role == .admin
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(role: .destructive) {
                showLeaveConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Leave Household")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Leave household")
        }
    }

    // MARK: - Create Household Sheet

    private var createHouseholdSheet: some View {
        VStack(spacing: 20) {
            Text("Create Household")
                .font(.title2.bold())
                .foregroundColor(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Household Name")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                TextField("e.g. Mauriello Family", text: $newHouseholdName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Household name")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Your Name")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                TextField("e.g. Tommaso", text: $newOwnerName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Your name")
            }

            HStack {
                Button("Cancel") {
                    showCreateHousehold = false
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Cancel")

                Spacer()

                Button("Create") {
                    _ = householdService.createHousehold(name: newHouseholdName, ownerName: newOwnerName)
                    showCreateHousehold = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newHouseholdName.trimmingCharacters(in: .whitespaces).isEmpty ||
                          newOwnerName.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Create household")
            }
        }
        .padding(32)
        .frame(width: 380)
    }

    // MARK: - Add Member Sheet

    private var addMemberSheet: some View {
        VStack(spacing: 20) {
            Text("Add Member")
                .font(.title2.bold())
                .foregroundColor(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                TextField("Member name", text: $newMemberName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("New member name")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Role")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Picker("Role", selection: $selectedRole) {
                    Text("Admin").tag(HouseholdMember.Role.admin)
                    Text("Member").tag(HouseholdMember.Role.member)
                    Text("Viewer").tag(HouseholdMember.Role.viewer)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Member role")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Avatar")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                    ForEach(avatarOptions, id: \.self) { icon in
                        Button {
                            selectedAvatar = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(selectedAvatar == icon ? .white : Theme.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(selectedAvatar == icon ? Color.accentColor : Theme.surfaceSecondary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Avatar \(icon)")
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    showAddMember = false
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Cancel")

                Spacer()

                Button("Add") {
                    _ = householdService.addMember(name: newMemberName, avatarName: selectedAvatar, role: selectedRole)
                    showAddMember = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newMemberName.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Add member")
            }
        }
        .padding(32)
        .frame(width: 420)
    }

    // MARK: - Leave Confirmation

    private var leaveConfirmationSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(Theme.danger)

            Text("Leave Household?")
                .font(.title2.bold())
                .foregroundColor(Theme.textPrimary)

            Text("You will no longer see shared bills or balance information. Any bills you created will remain in your personal list.")
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: 320)

            HStack {
                Button("Cancel") {
                    showLeaveConfirmation = false
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Cancel")

                Button("Leave") {
                    householdService.leaveHousehold()
                    showLeaveConfirmation = false
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.danger)
                .accessibilityLabel("Leave household")
            }
        }
        .padding(32)
        .frame(width: 380)
    }

    // MARK: - Invite Sheet

    private var inviteSheet: some View {
        VStack(spacing: 24) {
            Text("Invite to \(householdService.household?.name ?? "Household")")
                .font(.title2.bold())
                .foregroundColor(Theme.textPrimary)

            if let household = householdService.household,
               let qrImage = householdService.generateInviteQRCode(for: household) {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 180, height: 180)
                    .accessibilityLabel("QR code for household invite")
            }

            Text("Invite Code")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)

            if let code = householdService.household?.inviteCode {
                Text(code)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.surfaceSecondary)
                    .cornerRadius(8)
            }

            Text("Scan the QR code or enter this code on another Mac to join.")
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: 280)

            Button("Done") {
                showInviteSheet = false
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Done")
        }
        .padding(32)
    }
}

// MARK: - Preview

#if DEBUG
struct HouseholdSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        HouseholdSettingsView()
            .environmentObject(BillStore.shared)
    }
}
#endif
