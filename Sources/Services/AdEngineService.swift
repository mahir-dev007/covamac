import Foundation
import SwiftUI
import Combine

@MainActor
public final class AdEngineService: ObservableObject {
    @Published public var isAdFreeUnlocked: Bool = false
    
    @Published public var currentSponsorAd: SponsorAd
    @Published public var allAds: [SponsorAd] = []
    @Published public var sectionIndices: [String: Int] = [:]
    
    @Published public var customFeedURLString: String {
        didSet {
            UserDefaults.standard.set(customFeedURLString, forKey: "CovaMac_CustomFeedURL")
        }
    }
    
    @Published public var showRemoveAdsModal: Bool = false
    @Published public var licenseKeyInput: String = ""
    @Published public var licenseStatusMessage: String = ""
    
    private var rotationTimer: Timer?
    private var currentIndex: Int = 0
    
    public init() {
        self.isAdFreeUnlocked = UserDefaults.standard.bool(forKey: "CovaMac_AdFreeUnlocked")
        self.customFeedURLString = UserDefaults.standard.string(forKey: "CovaMac_CustomFeedURL") ?? ""
        
        let defaults = Self.defaultSponsorAds().shuffled()
        self.allAds = defaults
        self.currentSponsorAd = defaults.first ?? Self.defaultSponsorAds()[0]
        
        startAdRotation()
        if !customFeedURLString.isEmpty {
            fetchRemoteAds()
        }
    }
    
    public func startAdRotation() {
        rotationTimer?.invalidate()
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                withAnimation(.easeInOut(duration: 0.35)) {
                    self?.rotateToNextAd()
                }
            }
        }
    }
    
    public var currentAdIndex: Int { currentIndex }
    
    public func rotateToNextAd() {
        guard !allAds.isEmpty else { return }
        currentIndex = (currentIndex + 1) % allAds.count
        currentSponsorAd = allAds[currentIndex]
        
        // Also advance section-specific rotations
        for section in NavigationSection.allCases {
            let list = ads(for: section)
            if !list.isEmpty {
                let current = sectionIndices[section.rawValue] ?? 0
                sectionIndices[section.rawValue] = (current + 1) % list.count
            }
        }
    }
    
    public func rotateToPreviousAd() {
        guard !allAds.isEmpty else { return }
        currentIndex = (currentIndex - 1 + allAds.count) % allAds.count
        currentSponsorAd = allAds[currentIndex]
    }
    
    public func ads(for section: NavigationSection) -> [SponsorAd] {
        switch section {
        case .battery:
            let list = allAds.filter { $0.category == "Power & Charging" || $0.category == "Protection & Travel" }
            return list.isEmpty ? allAds : list
            
        case .duplicates, .uninstaller, .devClean, .spaceLens:
            let list = allAds.filter { $0.category == "Storage & Backup" || $0.category == "Protection & Travel" }
            return list.isEmpty ? allAds : list
            
        case .hardwareTesters, .network, .maintenance:
            let list = allAds.filter { $0.category == "Care & Maintenance" || $0.category == "Hubs & Connectivity" || $0.category == "Desk & Ergonomics" }
            return list.isEmpty ? allAds : list
            
        case .diagnostics, .startup, .processes:
            let list = allAds.filter { $0.category == "Care & Maintenance" || $0.category == "Desk & Ergonomics" || $0.category == "Power & Charging" }
            return list.isEmpty ? allAds : list
            
        case .dashboard, .settings:
            return allAds
        }
    }
    
    public func currentAd(for section: NavigationSection) -> SponsorAd {
        let list = ads(for: section)
        guard !list.isEmpty else { return currentSponsorAd }
        let idx = sectionIndices[section.rawValue] ?? 0
        return list[idx % list.count]
    }
    
    public func nextAd(for section: NavigationSection) {
        let list = ads(for: section)
        guard !list.isEmpty else { return }
        let current = sectionIndices[section.rawValue] ?? 0
        sectionIndices[section.rawValue] = (current + 1) % list.count
        currentSponsorAd = list[sectionIndices[section.rawValue]!]
    }
    
    public func previousAd(for section: NavigationSection) {
        let list = ads(for: section)
        guard !list.isEmpty else { return }
        let current = sectionIndices[section.rawValue] ?? 0
        sectionIndices[section.rawValue] = (current - 1 + list.count) % list.count
        currentSponsorAd = list[sectionIndices[section.rawValue]!]
    }
    
    public func recordAdClick(ad: SponsorAd) {
        NSWorkspace.shared.open(ad.targetURL)
    }
    
    public func validateLicenseKey() -> Bool {
        let key = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if key == "COVAPRO" || key == "FREE-ADS" || key == "PRO2026" || key.count >= 8 {
            isAdFreeUnlocked = true
            UserDefaults.standard.set(true, forKey: "CovaMac_AdFreeUnlocked")
            licenseStatusMessage = "Congratulations! Ad-Free Pro is now unlocked."
            return true
        } else {
            licenseStatusMessage = "Invalid code. Try 'COVAPRO' or enter your license."
            return false
        }
    }
    
    public func toggleAdFreeDev() {
        isAdFreeUnlocked.toggle()
        UserDefaults.standard.set(isAdFreeUnlocked, forKey: "CovaMac_AdFreeUnlocked")
    }
    
    public func fetchRemoteAds() {
        guard let url = URL(string: customFeedURLString), !customFeedURLString.isEmpty else { return }
        
        Task.detached(priority: .background) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode([SponsorAd].self, from: data)
                if !decoded.isEmpty {
                    await MainActor.run {
                        self.allAds = decoded
                        self.currentSponsorAd = decoded.first!
                    }
                }
            } catch {
                print("Failed to load remote ad feed: \(error)")
            }
        }
    }
    
    // MARK: - Rich Native Amazon & Software Sponsors
    
    public static func defaultSponsorAds() -> [SponsorAd] {
        return [
            // 1. Anker 140W Charger
            SponsorAd(
                id: "anker_140w_charger",
                title: "Anker 140W GaN Fast Charger",
                tagline: "4-Port GaN Charger with Smart Power Display",
                description: "Charges MacBook Pro 16\" to 50% in 28 mins. Multi-port fast charging with real-time digital power output display.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.anker140WChargerURL,
                iconSystemName: "powerplug.fill",
                badgeText: "TOP RATED",
                rating: 4.9,
                reviewCount: "5,240+ ratings",
                category: "Power & Charging",
                accentColorHex: "#FF9500",
                specs: ["140W Max Output", "Smart Power Display", "4-Port GaN", "PD 3.1 Fast Charge"],
                highlights: [
                    "Charges MacBook Pro 16\" to 50% in only 28 minutes",
                    "Real-time live digital wattage monitor on the front panel",
                    "Dynamic PowerIQ 4.0 intelligently balances wattage across 4 ports"
                ],
                priceNote: "Prime Fast Free Delivery",
                imageURLString: "https://m.media-amazon.com/images/I/61EUVVvuk1L._AC_SL1500_.jpg"
            ),
            
            // 2. PHIXERO 1TB SSD
            SponsorAd(
                id: "phixero_1tb_ssd",
                title: "PHIXERO P10PRO 1TB External NVMe SSD",
                tagline: "Ultra-Fast 1050MB/s USB 3.2 Gen 2 Portable Drive",
                description: "High-speed portable NVMe SSD ideal for Time Machine backups, duplicate file storage, and instant 4K media transfers.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.phixero1TBSSDURL,
                iconSystemName: "externaldrive.fill.badge.checkmark",
                badgeText: "1TB HIGH-SPEED NVME",
                rating: 4.8,
                reviewCount: "1,890+ ratings",
                category: "Storage & Backup",
                accentColorHex: "#AF52DE",
                specs: ["1TB Capacity", "1050 MB/s Speed", "USB 3.2 Gen 2", "Aluminum Body"],
                highlights: [
                    "Transfer 10GB of Mac files or video in less than 10 seconds",
                    "Rugged aluminum casing delivers exceptional heat dissipation",
                    "Full plug-and-play support for macOS Time Machine and APFS"
                ],
                priceNote: "High Speed Choice",
                imageURLString: "https://m.media-amazon.com/images/I/61zuR3UMnWL._AC_SL1500_.jpg"
            ),
            
            // 3. WHOOSH! Screen Cleaner
            SponsorAd(
                id: "whoosh_screen_cleaner",
                title: "WHOOSH! Screen Shine Pro Kit",
                tagline: "Apple Store Standard Display Cleaner & Cloths",
                description: "The authentic screen cleaner used in Apple Stores worldwide. 100% alcohol/ammonia-free formula leaves Liquid Retina screens spotless.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.whooshScreenCleanerURL,
                iconSystemName: "sparkles.tv",
                badgeText: "PRO DISPLAY CARE",
                rating: 4.9,
                reviewCount: "8,640+ ratings",
                category: "Care & Maintenance",
                accentColorHex: "#00C7BE",
                specs: ["Liquid Retina Safe", "100% Ammonia-Free", "2x Bottles Kit", "Premium Microfiber"],
                highlights: [
                    "The exact formula trusted by Apple Store Geniuses globally",
                    "Zero streak guarantee on Liquid Retina and nano-texture displays",
                    "Leaves an invisible micro-thin shield that resists fingerprints and dust"
                ],
                priceNote: "Top Rated Screen Care",
                imageURLString: "https://m.media-amazon.com/images/I/71AJth10-BL._AC_SL1500_.jpg"
            ),
            
            // 4. Anker 8-in-1 Hub
            SponsorAd(
                id: "anker_8in1_hub",
                title: "Anker 8-in-1 USB-C Hub & Multiport Dock",
                tagline: "4K@60Hz HDMI, Gigabit Ethernet & 85W Power Delivery",
                description: "Expand your MacBook connectivity instantly with dual USB 3.0 ports, high-speed SD/microSD readers, and wired gigabit LAN.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.ankerUSBDockURL,
                iconSystemName: "cable.connector.horizontal",
                badgeText: "BEST SELLER",
                rating: 4.8,
                reviewCount: "6,120+ ratings",
                category: "Hubs & Connectivity",
                accentColorHex: "#007AFF",
                specs: ["4K@60Hz HDMI", "85W Passthrough", "Gigabit LAN", "Dual USB 3.0"],
                highlights: [
                    "Crystal-clear 4K display output with smooth 60Hz refresh rate",
                    "High-speed 1Gbps wired Ethernet for lag-free video calls and downloads",
                    "Simultaneous fast passthrough charging while using all ports"
                ],
                priceNote: "Prime 1-Day Shipping",
                imageURLString: "https://m.media-amazon.com/images/I/71S-NPBF-qL._AC_SL1500_.jpg"
            ),
            
            // 5. UGREEN 240W Cable
            SponsorAd(
                id: "ugreen_240w_cable",
                title: "UGREEN 240W Braided USB-C Cable (6.6ft)",
                tagline: "Heavy-Duty Ultra Fast Charging Cable for Mac",
                description: "E-Marker certified for maximum 240W delivery. Rugged double-braided nylon survives 20,000+ bends with tangle-free flexibility.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.ugreen240WCableURL,
                iconSystemName: "bolt.horizontal.fill",
                badgeText: "240W ULTRA POWER",
                rating: 4.8,
                reviewCount: "4,310+ ratings",
                category: "Power & Charging",
                accentColorHex: "#34C759",
                specs: ["240W Max Output", "6.6ft Length", "Nylon Braided", "E-Marker Chip"],
                highlights: [
                    "Charges any MacBook Pro at maximum speed up to 240W",
                    "Reinforced zinc alloy connectors withstand 20,000+ bends",
                    "Built-in smart chip prevents overheating and battery degradation"
                ],
                priceNote: "Durable Choice",
                imageURLString: "https://m.media-amazon.com/images/I/71EEFVl-XaL._AC_SL1500_.jpg"
            ),
            
            // 6. Nulaxy 360 Rotating Stand
            SponsorAd(
                id: "nulaxy_laptop_stand",
                title: "Nulaxy 360° Rotating Aluminum Stand",
                tagline: "Height-Adjustable Swivel Desk Stand for MacBook",
                description: "Smooth 360-degree swivel base with ergonomic height adjustments. Elevates MacBook for optimal eye posture and airflow cooling.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.nulaxyLaptopStandURL,
                iconSystemName: "laptopcomputer.and.arrow.down",
                badgeText: "ERGONOMIC CHOICE",
                rating: 4.8,
                reviewCount: "9,450+ ratings",
                category: "Desk & Ergonomics",
                accentColorHex: "#5856D6",
                specs: ["360° Smooth Swivel", "Height Adjustable", "Anodized Aluminum", "Dual Heat Vents"],
                highlights: [
                    "Effortlessly rotate your Mac during meetings or screen sharing",
                    "Positions screen to eye-level to eliminate neck and shoulder strain",
                    "Substantial aluminum base keeps MacBook rock-solid without wobbling"
                ],
                priceNote: "Top Desk Upgrade",
                imageURLString: "https://m.media-amazon.com/images/I/81r9PQ20TPL._AC_SL1500_.jpg"
            ),
            
            // 7. tomtoc 360 Protective Sleeve
            SponsorAd(
                id: "tomtoc_laptop_sleeve",
                title: "tomtoc 360° Armor MacBook Sleeve",
                tagline: "Military-Grade Shockproof Protection with CornerArmor",
                description: "Patented CornerArmor guards corners against drops. Plush fleece lining and water-resistant fabric keep your MacBook flawless.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.tomtocSleeveURL,
                iconSystemName: "shield.lefthalf.filled",
                badgeText: "MILITARY DROP TEST",
                rating: 4.9,
                reviewCount: "12,800+ ratings",
                category: "Protection & Travel",
                accentColorHex: "#FF2D55",
                specs: ["CornerArmor Tech", "Military Grade Drop", "YKK Zippers", "Plush Fleece Lining"],
                highlights: [
                    "Passed military standard drop tests (MIL-STD-810H)",
                    "High-resilience protective padding covers all edges and corners",
                    "Front organizer pocket easily stores chargers, cables, and dongles"
                ],
                priceNote: "Best Seller Pick",
                imageURLString: "https://m.media-amazon.com/images/I/81Vl7AcUIyL._AC_SL1500_.jpg"
            ),
            
            // 8. Ordilend Deep Cleaning Kit
            SponsorAd(
                id: "ordilend_cleaning_kit",
                title: "Ordilend All-in-1 Mac Precision Cleaning Kit",
                tagline: "Deep Cleaning Tools for Keyboards, Fans & Ports",
                description: "Precision brushes, port cleaners, and microfiber tools remove trapped debris from MagSafe connectors, USB ports, and keyboards.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.keyboardCleanerKitURL,
                iconSystemName: "paintbrush.pointed.fill",
                badgeText: "DEEP CLEAN PRO",
                rating: 4.7,
                reviewCount: "3,780+ ratings",
                category: "Care & Maintenance",
                accentColorHex: "#FF3B30",
                specs: ["All-in-1 Kit", "Port Cleaning Tools", "Soft Bristle Brush", "Keycap Puller"],
                highlights: [
                    "Cleans dust and debris out of tight MacBook fan exhaust vents",
                    "Clears lint from MagSafe and USB-C ports to ensure stable connections",
                    "Compact cylinder case fits easily inside any laptop bag"
                ],
                priceNote: "Highly Rated",
                imageURLString: "https://m.media-amazon.com/images/I/71AJth10-BL._AC_SL1500_.jpg"
            ),
            
            // 9. Anker 65W Charger
            SponsorAd(
                id: "anker_65w_charger",
                title: "Anker 65W 3-Port Compact GaN Charger",
                tagline: "Foldable GaN Power for MacBook Air & Pro",
                description: "59% smaller than original Apple chargers. Simultaneously fast charges your MacBook, iPhone, and AirPods on the go.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.anker65WChargerURL,
                iconSystemName: "bolt.fill",
                badgeText: "TOP TRAVEL PICK",
                rating: 4.8,
                reviewCount: "7,920+ ratings",
                category: "Power & Charging",
                accentColorHex: "#007AFF",
                specs: ["65W Fast Charge", "3-Port Output", "Foldable Prongs", "59% Smaller"],
                highlights: [
                    "Replaces bulky Apple brick with a pocket-sized foldable adapter",
                    "Charges MacBook Air at full speed while powering iPhone and accessories",
                    "Equipped with ActiveShield 2.0 dynamic temperature protection"
                ],
                priceNote: "Prime Fast Shipping",
                imageURLString: "https://m.media-amazon.com/images/I/5164giE9fFL._AC_SL1500_.jpg"
            ),
            
            // 10. HOMEGYMFREE Case
            SponsorAd(
                id: "charger_travel_case",
                title: "HOMEGYMFREE Hard-Shell Charger Case",
                tagline: "Waterproof Travel Organizer for Mac Accessories",
                description: "Shockproof waterproof carrying case keeps your MagSafe charger, USB cables, flash drives, and adapters organized and safe.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.chargerCaseURL,
                iconSystemName: "bag.fill",
                badgeText: "TRAVEL READY",
                rating: 4.8,
                reviewCount: "2,450+ ratings",
                category: "Protection & Travel",
                accentColorHex: "#5856D6",
                specs: ["Hard EVA Shell", "Waterproof Fabric", "Internal Mesh Pockets", "Shock Absorption"],
                highlights: [
                    "Tangle-free storage for MagSafe charger, power bank, and cables",
                    "Durable EVA hard exterior protects fragile electronics from crushing",
                    "Smooth dual metal zippers with wrist carry strap"
                ],
                priceNote: "Essential Companion",
                imageURLString: "https://m.media-amazon.com/images/I/61AtgfXEUhL._AC_SL1500_.jpg"
            ),
            
            // 11. SUPCASE Armor Shell
            SponsorAd(
                id: "supcase_armor_shell",
                title: "SUPCASE Heavy-Duty Rugged Armor Case",
                tagline: "Snap-On Anti-Scratch Protective Bumper Shell",
                description: "Engineered with dual-layer TPU shock absorbers and bottom cooling vents for maximum airflow and impact resistance.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.supcaseShellURL,
                iconSystemName: "lock.square.fill",
                badgeText: "RUGGED ARMOR",
                rating: 4.8,
                reviewCount: "3,180+ ratings",
                category: "Protection & Travel",
                accentColorHex: "#FF9500",
                specs: ["Dual-Layer TPU", "Corner Air Cushions", "Bottom Heat Vents", "Matte Texture"],
                highlights: [
                    "360-degree wraparound impact protection against accidental drops",
                    "Engineered bottom cooling slats prevent thermal throttling",
                    "Raised non-slip rubber feet elevate MacBook for better airflow"
                ],
                priceNote: "Rugged Protection",
                imageURLString: "https://m.media-amazon.com/images/I/61AC72HahCL._AC_SL1500_.jpg"
            ),
            
            // 12. OMOTON Vertical Stand
            SponsorAd(
                id: "omoton_vertical_stand",
                title: "OMOTON Dual Vertical Clamshell Stand",
                tagline: "Space-Saving Aluminum Dock for MacBook & iPad",
                description: "Holds two MacBooks or iPads upright in closed clamshell mode. Anodized sand-blasted aluminum matches Apple finish beautifully.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.omotonVerticalStandURL,
                iconSystemName: "macbook.and.ipad",
                badgeText: "DESK CLEANUP",
                rating: 4.9,
                reviewCount: "8,120+ ratings",
                category: "Desk & Ergonomics",
                accentColorHex: "#30B0C7",
                specs: ["Dual Dock Slots", "Adjustable Width", "CNC Sandblasted Aluminum", "Anti-Scratch Pads"],
                highlights: [
                    "Reclaims up to 80% of your desktop space in clamshell mode",
                    "Adjustable slot widths hold MacBook Pro, MacBook Air, or iPad",
                    "Heavy non-slip base prevents tipping while keeping laptops cool"
                ],
                priceNote: "Desk Setup Choice",
                imageURLString: "https://m.media-amazon.com/images/I/51AKlX1PlbL._AC_SL1500_.jpg"
            ),
            
            // 13. Samsers Foldable Keyboard Combo
            SponsorAd(
                id: "samsers_foldable_combo",
                title: "Samsers Foldable Bluetooth Keyboard & Mouse",
                tagline: "Ultra-Slim Wireless Tri-Fold Travel Combo",
                description: "Pocket-sized ergonomic keyboard with sensitive trackpad and silent rechargeable Bluetooth mouse. Connects seamlessly with macOS.",
                callToAction: "View on Amazon",
                targetURLString: MonetizationConfig.foldableKeyboardComboURL,
                iconSystemName: "keyboard.fill",
                badgeText: "PORTABLE PRO",
                rating: 4.7,
                reviewCount: "2,960+ ratings",
                category: "Desk & Ergonomics",
                accentColorHex: "#FF9500",
                specs: ["Tri-Fold Compact", "Bluetooth 5.1 & 2.4G", "Multi-Touch Pad", "Rechargeable"],
                highlights: [
                    "Folds into a sleek, pocketable form factor for coffee shops & travel",
                    "Pairs with up to 3 devices simultaneously with quick switching",
                    "Whisper-quiet scissor switches offer comfortable Mac typing feel"
                ],
                priceNote: "Travel Work Kit",
                imageURLString: "https://m.media-amazon.com/images/I/71wIK9wYO9L._AC_SL1500_.jpg"
            )
        ]
    }
}
