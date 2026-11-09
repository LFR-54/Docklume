import SwiftUI
import UniformTypeIdentifiers

/// Drag and drop on the drives page. What is dragged is only seen by Docklume: dropped on the Finder or another
/// app, a card leaves nothing behind.
enum DriveDrag {
    static let type = UTType.utf8PlainText

    static func provider(_ text: String) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .ownProcess) { done in
            done(Data(text.utf8), nil)
            return nil
        }
        return provider
    }

    /// The line showing where a dragged card or group lands, halfway across the gap.
    static func line(after: Bool, gap: CGFloat) -> some View {
        Capsule()
            .fill(Theme.accent)
            .frame(height: 3)
            .padding(.horizontal, 4)
            .offset(y: (after ? 1 : -1) * (gap / 2 + 1.5))
            .allowsHitTesting(false)
    }
}

/// A drive card as a drop target: the dragged drive goes above or below it, in its group when the groups show.
struct CardDrop: DropDelegate {
    let drive: Drive
    let height: CGFloat
    let store: DriveStore
    let app: AppState

    private var dragged: Drive? {
        guard case .drive(let id) = app.dragging, id != drive.id else { return nil }
        return store.drive(id)
    }

    func validateDrop(info: DropInfo) -> Bool { dragged != nil }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard dragged != nil else { return DropProposal(operation: .forbidden) }
        app.dropSpot = .drive(drive.id, after: info.location.y > height / 2)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if case .drive(drive.id, _) = app.dropSpot { app.dropSpot = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        let dragged = dragged
        app.dropSpot = nil
        app.dragging = nil
        guard let dragged else { return false }
        withAnimation(.easeOut(duration: 0.2)) {
            store.move(dragged, to: drive, after: info.location.y > height / 2)
        }
        return true
    }
}

/// A group's header, or the place of an empty group, as a drop target: a drive joins the group, last; a group
/// moves above or below it. `group` is nil for the drives without a group, which take drives only.
struct GroupDrop: DropDelegate {
    let group: String?
    let height: CGFloat
    let store: DriveStore
    let app: AppState
    /// The place of an empty group takes drives only.
    var drivesOnly = false

    func validateDrop(info: DropInfo) -> Bool { accepts(app.dragging) }

    private func accepts(_ item: AppState.DragItem?) -> Bool {
        switch item {
        case .drive: true
        case .group(let id): !drivesOnly && group != nil && id != group
        case nil: false
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard accepts(app.dragging) else { return DropProposal(operation: .forbidden) }
        if case .group = app.dragging, let group {
            app.dropSpot = .groupEdge(group, after: info.location.y > height / 2)
        } else {
            app.dropSpot = .group(group)
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        switch app.dropSpot {
        case .group(group): app.dropSpot = nil
        case .groupEdge(let id, _) where id == group: app.dropSpot = nil
        default: break
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        let item = app.dragging
        app.dropSpot = nil
        app.dragging = nil
        withAnimation(.easeOut(duration: 0.2)) {
            switch item {
            case .drive(let id):
                if let drive = store.drive(id) { store.move(drive, toGroup: group) }
            case .group(let id):
                if let group { store.moveGroup(id, to: group, after: info.location.y > height / 2) }
            case nil:
                break
            }
        }
        return item != nil
    }
}

/// The header of a group: a click folds or unfolds it, a drag moves it, a double-click renames it.
struct GroupHeader: View {
    @Environment(DriveStore.self) private var store
    @Environment(AppState.self) private var app
    let group: DriveGroup
    let count: Int
    /// The space between the cards, which a line drawn above or below the header keeps to.
    let gap: CGFloat
    @State private var hovering = false
    @State private var height: CGFloat = 32

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.text2)
                .rotationEffect(.degrees(group.collapsed ? 0 : 90))
                .frame(width: 14)
            if app.renamingGroup == group.id {
                GroupNameField(group: group)
            } else {
                Text(group.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .onTapGesture(count: 2) { app.renamingGroup = group.id }
            }
            Text(Format.plural(count, "lecteur"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.text2)
                .monospacedDigit()
            Spacer(minLength: 8)
            Menu {
                GroupMenuItems(group: group)
            } label: {
                IconButtonFace(symbol: "ellipsis", size: 26, iconSize: 13, radius: 7)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .opacity(hovering ? 1 : 0.6)
            .accessibilityLabel(L("Actions pour le groupe \(group.name)"))
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(height: 32)
        .background(lit ? Theme.accentSoft : hovering ? Theme.hover : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: edge?.after == true ? .bottom : .top) {
            if let edge { DriveDrag.line(after: edge.after, gap: gap) }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) { store.setCollapsed(group.id, !group.collapsed) }
        }
        .contextMenu { GroupMenuItems(group: group) }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .onDrag {
            app.dragging = .group(group.id)
            return DriveDrag.provider(group.id)
        }
        .onDrop(of: [DriveDrag.type], delegate: GroupDrop(group: group.id, height: height, store: store, app: app))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityAction(named: group.collapsed ? L("Déplier") : L("Replier")) { store.setCollapsed(group.id, !group.collapsed) }
    }

    private var lit: Bool { app.dropSpot == .group(group.id) }

    private var edge: (id: String, after: Bool)? {
        if case .groupEdge(let id, let after) = app.dropSpot, id == group.id { return (id, after) }
        return nil
    }
}

/// The header above the drives without a group, shown once there are groups.
struct UngroupedHeader: View {
    @Environment(DriveStore.self) private var store
    @Environment(AppState.self) private var app
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(L("Sans groupe"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text2)
            Text(Format.plural(count, "lecteur"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.text3)
                .monospacedDigit()
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(app.dropSpot == .group(nil) ? Theme.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onDrop(of: [DriveDrag.type], delegate: GroupDrop(group: nil, height: 32, store: store, app: app))
        .accessibilityAddTraits(.isHeader)
    }
}

/// An unfolded group without drives: room to drop one.
struct EmptyGroupDrop: View {
    @Environment(DriveStore.self) private var store
    @Environment(AppState.self) private var app
    let group: String

    var body: some View {
        let lit = app.dropSpot == .group(group)
        Text(L("Glissez un lecteur ici."))
            .font(.system(size: 12.5))
            .foregroundStyle(lit ? Theme.accent : Theme.text3)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(lit ? Theme.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(lit ? Theme.accent : Theme.controlBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .onDrop(of: [DriveDrag.type], delegate: GroupDrop(group: group, height: 64, store: store, app: app, drivesOnly: true))
    }
}

struct NewGroupButton: View {
    @Environment(DriveStore.self) private var store
    @Environment(AppState.self) private var app

    var body: some View {
        Button {
            let group = withAnimation(.easeOut(duration: 0.2)) { store.addGroup() }
            app.renamingGroup = group.id
        } label: {
            Hovering { hovering in
                Label(L("Nouveau groupe"), systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(hovering ? Theme.text : Theme.text2)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(hovering ? Theme.hover : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }
}

/// The group's menu, on its header and its ellipsis button.
struct GroupMenuItems: View {
    @Environment(DriveStore.self) private var store
    @Environment(AppState.self) private var app
    let group: DriveGroup

    var body: some View {
        Button(L("Renommer"), systemImage: "character.cursor.ibeam") { app.renamingGroup = group.id }
        Button(group.collapsed ? L("Déplier") : L("Replier"), systemImage: group.collapsed ? "chevron.down" : "chevron.right") {
            withAnimation(.easeOut(duration: 0.2)) { store.setCollapsed(group.id, !group.collapsed) }
        }
        Divider()
        Button(L("Supprimer le groupe…"), systemImage: "trash", role: .destructive) {
            app.confirm(L("Supprimer le groupe « \(group.name) » ?"),
                        message: L("Ses lecteurs restent dans Docklume, sans groupe. Rien n'est démonté."),
                        confirm: L("Supprimer"), destructive: true) {
                withAnimation(.easeOut(duration: 0.2)) { store.deleteGroup(group.id) }
            }
        }
    }
}

/// Moves a drive to another group from its menu; shown while the groups are.
struct DriveGroupMenu: View {
    let drive: Drive
    let actions: DriveActions

    var body: some View {
        let store = actions.store
        Menu(L("Groupe"), systemImage: "rectangle.stack") {
            Toggle(L("Sans groupe"), isOn: Binding(get: { store.groupID(of: drive) == nil },
                                                    set: { if $0 { store.move(drive, toGroup: nil) } }))
            ForEach(store.groups) { group in
                Toggle(group.name, isOn: Binding(get: { store.groupID(of: drive) == group.id },
                                                 set: { if $0 { store.move(drive, toGroup: group.id) } }))
            }
            Divider()
            Button(L("Nouveau groupe…")) {
                let group = store.addGroup(with: drive)
                actions.app.page = .drives
                actions.app.renamingGroup = group.id
            }
        }
    }
}

/// Inline rename of a group: Return keeps, Escape cancels, leaving the field keeps.
private struct GroupNameField: View {
    @Environment(DriveStore.self) private var store
    @Environment(AppState.self) private var app
    let group: DriveGroup
    @State private var text = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .focused($focused)
                .padding(.horizontal, 6)
                .frame(width: 240, height: 24)
                .inlineNameField(invalid: error != nil)
                .padding(.leading, -7)
                .onSubmit(commit)
                .onExitCommand { app.renamingGroup = nil }
                .onChange(of: text) { error = nil }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused, app.renamingGroup == group.id {
                        app.renamingGroup = nil
                        store.renameGroup(group.id, to: text)
                    }
                }
                .help(error ?? "")
                .accessibilityLabel(L("Nouveau nom du groupe \(group.name)"))
        }
        .onAppear {
            text = group.name
            focused = true
        }
    }

    private func commit() {
        if let message = store.renameGroup(group.id, to: text) {
            error = message
            app.show(message, warning: true)
            focused = true
        } else {
            app.renamingGroup = nil
        }
    }
}
