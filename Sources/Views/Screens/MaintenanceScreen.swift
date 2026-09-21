import SwiftUI
import AppKit

public struct MaintenanceScreen: View {
    @ObservedObject var service: MaintenanceService
    @ObservedObject var adEngine: AdEngineService
    @State private var isConsoleExpanded: Bool = false
    
    public init(service: MaintenanceService, adEngine: AdEngineService) {
        self.service = service
        self.adEngine = adEngine
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerView
                
                // Tasks Grid
                tasksListView
                
                // Live Execution Console (Collapsible)
                consoleCardView
            }
            .padding(24)
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("System Maintenance")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("MACOS TOOLKIT")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(CovaTheme.accentAmber.opacity(0.18))
                        .foregroundColor(CovaTheme.accentAmber)
                        .cornerRadius(5)
                }
                
                Text("Execute low-level macOS system scripts to repair search indexing, context menus, DNS, and memory.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                service.runAllTasks()
            }) {
                HStack(spacing: 6) {
                    if service.isRunningAny {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                        Text("Running Maintenance...")
                            .font(.system(size: 11, weight: .bold))
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                        Text("Run All Tasks")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if service.isRunningAny {
                            Color.gray.opacity(0.3)
                        } else {
                            CovaTheme.amberGradient
                        }
                    }
                )
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(service.isRunningAny)
        }
    }
    
    // MARK: - Tasks List
    private var tasksListView: some View {
        VStack(spacing: 12) {
            ForEach(service.tasks) { task in
                MaintenanceTaskRowView(
                    task: task,
                    isRunning: service.activeTaskID == task.id,
                    isAnyRunning: service.isRunningAny,
                    onRun: { service.runSingleTask(id: task.id) }
                )
            }
        }
    }
    
    // MARK: - Console
    private var consoleCardView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isConsoleExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isConsoleExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Execution Log Console")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if isConsoleExpanded {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(service.globalLog, forType: .string)
                    }) {
                        Text("Copy Log")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if isConsoleExpanded {
                ScrollView {
                    Text(service.globalLog)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.green.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(height: 140)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(10)
    }
}

private struct MaintenanceTaskRowView: View {
    let task: MaintenanceTaskItem
    let isRunning: Bool
    let isAnyRunning: Bool
    let onRun: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 40, height: 40)
                Image(systemName: task.iconName)
                    .font(.system(size: 17))
                    .foregroundColor(CovaTheme.accentAmber)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .bold))
                    
                    Text(task.category)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.06))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }
                
                Text(task.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let date = task.lastRunDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text("Last run: \(DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short))")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Status & Run Button
            HStack(spacing: 10) {
                switch task.status {
                case .idle:
                    EmptyView()
                case .running:
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.6)
                        Text("Running...")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(CovaTheme.primaryBlue)
                    }
                case .success:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(CovaTheme.accentGreen)
                            .font(.system(size: 11))
                        Text("Done")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(CovaTheme.accentGreen)
                    }
                case .failed:
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 11))
                        Text("Notice")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
                
                Button(action: onRun) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text("Run")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isAnyRunning)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRunning ? CovaTheme.accentAmber.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
