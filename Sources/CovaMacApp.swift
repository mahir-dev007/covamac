import SwiftUI

@main
struct CovaMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup("CovaMac") {
            MainView()
                .frame(minWidth: 920, idealWidth: 1040, minHeight: 620, idealHeight: 720)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
