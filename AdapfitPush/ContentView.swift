import SwiftUI
import UniformTypeIdentifiers
#Preview {
    ContentView()
}
struct ContentView: View {
    @StateObject private var vm = PushViewModel()
    @State private var showFilePicker = false
    @State private var isDroppingFile = false

    var body: some View {
        HSplitView {
            // ── LEFT PANEL ── Settings
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .font(.title)
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AdapfitPush")
                                .font(.title2).bold()
                            Text("Firebase FCM v1 Sender")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 4)

                    // ─── Service Account ───────────────────
                    GroupBox(label: Label("Service Account", systemImage: "key.fill").font(.headline)) {
                        VStack(alignment: .leading, spacing: 10) {
                            // Drop zone
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        isDroppingFile ? Color.accentColor : Color.secondary.opacity(0.4),
                                        style: StrokeStyle(lineWidth: 2, dash: [6])
                                    )
                                    .frame(height: 80)
                                    .background(isDroppingFile ? Color.accentColor.opacity(0.05) : Color.clear)
                                    .cornerRadius(8)

                                VStack(spacing: 4) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    Text("Kéo thả serviceAccount.json vào đây")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .onDrop(of: [UTType.json, UTType.fileURL], isTargeted: $isDroppingFile) { providers in
                                handleDrop(providers: providers)
                            }

                            HStack {
                                Button(action: { showFilePicker = true }) {
                                    Label("Chọn File...", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)

                                Spacer()

                                HStack(spacing: 4) {
                                    Image(systemName: vm.serviceAccount != nil ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(vm.serviceAccount != nil ? .green : .secondary)
                                    Text(vm.serviceAccountFileName)
                                        .font(.callout)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }

                            if let sa = vm.serviceAccount {
                                VStack(alignment: .leading, spacing: 2) {
                                    InfoRow(label: "Project", value: sa.projectId)
                                    InfoRow(label: "Email", value: sa.clientEmail)
                                }
                                .font(.caption)
                                .padding(8)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(6)
                            }
                        }
                        .padding(8)
                    }

                    // ─── Target ───────────────────────────
                    GroupBox(label: Label("Target", systemImage: "target").font(.headline)) {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("", selection: $vm.useTopicMode) {
                                Text("📢  Topic").tag(true)
                                Text("📱  Device Token").tag(false)
                            }
                            .pickerStyle(.segmented)

                            if vm.useTopicMode {
                                LabeledField("Topic") {
                                    TextField("vd: adapfit_vi", text: $vm.topic)
                                        .textFieldStyle(.roundedBorder)
                                }
                            } else {
                                LabeledField("Device Token") {
                                    TextField("Paste FCM token...", text: $vm.deviceToken)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.caption, design: .monospaced))
                                }
                            }
                        }
                        .padding(8)
                    }

                    // ─── Notification ─────────────────────
                    GroupBox(label: Label("Notification", systemImage: "bell").font(.headline)) {
                        VStack(alignment: .leading, spacing: 10) {
                            LabeledField("Title") {
                                TextField("Tiêu đề", text: $vm.title)
                                    .textFieldStyle(.roundedBorder)
                            }
                            LabeledField("Body") {
                                TextEditor(text: $vm.body)
                                    .frame(height: 80)
                                    .font(.body)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(8)
                    }

                    // ─── Data Payload ─────────────────────
                    GroupBox(label: Label("Data Payload", systemImage: "doc.text").font(.headline)) {
                        LabeledField("force_update_min_version") {
                            TextField("vd: 1.0.0", text: $vm.forceUpdateMinVersion)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(8)
                    }

                    // ─── APNS ─────────────────────────────
                    GroupBox(label: Label("APNS Config", systemImage: "apple.logo").font(.headline)) {
                        VStack(alignment: .leading, spacing: 10) {
                            LabeledField("apns-push-type") {
                                Picker("", selection: $vm.apnsPushType) {
                                    Text("alert").tag("alert")
                                    Text("background").tag("background")
                                    Text("voip").tag("voip")
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            LabeledField("apns-priority") {
                                Picker("", selection: $vm.apnsPriority) {
                                    Text("10 (High)").tag("10")
                                    Text("5 (Normal)").tag("5")
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            HStack {
                                LabeledField("Sound") {
                                    TextField("default", text: $vm.sound)
                                        .textFieldStyle(.roundedBorder)
                                }
                                LabeledField("Badge") {
                                    TextField("1", value: $vm.badge, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                }
                            }
                        }
                        .padding(8)
                    }

                    // ─── Send Button ──────────────────────
                    Button(action: { vm.send() }) {
                        HStack {
                            if vm.isSending {
                                ProgressView().scaleEffect(0.7)
                                Text("Đang gửi...")
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Gửi Push Notification")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(vm.isSending || vm.serviceAccount == nil)
                    .controlSize(.large)
                }
                .padding(20)
            }
            .frame(minWidth: 360, maxWidth: 420)

            // ── RIGHT PANEL ── Log output
            VStack(spacing: 0) {
                HStack {
                    Label("Log", systemImage: "terminal")
                        .font(.headline)
                    Spacer()
                    Button(action: { vm.clearLogs() }) {
                        Label("Xoá", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(vm.logs) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(entry.timestamp)
                                        .foregroundColor(.secondary)
                                    Text(entry.message)
                                        .foregroundColor(entry.isError ? .red : .primary)
                                        .textSelection(.enabled)
                                }
                                .font(.system(.caption, design: .monospaced))
                                .id(entry.id)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .onChange(of: vm.logs.count) { _ in
                        if let last = vm.logs.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
            .frame(minWidth: 400)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    let accessing = url.startAccessingSecurityScopedResource()
                    vm.loadServiceAccount(from: url)
                    if accessing { url.stopAccessingSecurityScopedResource() }
                }
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
        .frame(minWidth: 800, minHeight: 560)
    }

    // MARK: - Drag & Drop

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // Try file URL first
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                DispatchQueue.main.async {
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        vm.loadServiceAccount(from: url)
                    }
                }
            }
            return true
        }

        // Fallback: raw JSON data dropped
        if provider.hasItemConformingToTypeIdentifier(UTType.json.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.json.identifier) { item, _ in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        vm.loadServiceAccount(from: url)
                    }
                }
            }
            return true
        }

        return false
    }
}

// MARK: - Helper Views

struct LabeledField<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            content
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }
}
