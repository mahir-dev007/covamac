import SwiftUI

// MARK: - 1. Sidebar Sponsor Card (Dedicated Sidebar Ad)

public struct SidebarSponsorCardView: View {
    @ObservedObject var adEngine: AdEngineService
    
    public init(adEngine: AdEngineService) {
        self.adEngine = adEngine
    }
    
    public var body: some View {
        if adEngine.isAdFreeUnlocked {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(CovaTheme.accentGreen)
                    .font(.system(size: 13))
                Text("CovaMac Pro • Ad-Free")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.12))
            .cornerRadius(8)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        } else {
            let ad = adEngine.currentSponsorAd
            let accentColor = Color(hex: ad.accentColorHex) ?? CovaTheme.primaryBlue
            
            VStack(alignment: .leading, spacing: 10) {
                // Top Header Row
                HStack {
                    Text(ad.badgeText)
                        .font(.system(size: 8, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(accentColor.opacity(0.18))
                        .foregroundColor(accentColor)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Button(action: {
                        adEngine.showRemoveAdsModal = true
                    }) {
                        Text("Hide Ads")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Redeem license key to remove ads")
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Button(action: {
                        withAnimation {
                            adEngine.rotateToNextAd()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 9, weight: .bold))
                            Text("Next")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Shuffle gear recommendation")
                }
                
                // Product Visual & Details
                HStack(spacing: 12) {
                    // Visual Preview Box
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 46, height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
                            )
                        
                        if let imgStr = ad.imageURLString, let url = URL(string: imgStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 42, height: 42)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                default:
                                    Image(systemName: ad.iconSystemName)
                                        .font(.system(size: 22))
                                        .foregroundColor(accentColor)
                                }
                            }
                        } else {
                            Image(systemName: ad.iconSystemName)
                                .font(.system(size: 22))
                                .foregroundColor(accentColor)
                                .shadow(color: accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ad.title)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 9))
                            Text(String(format: "%.1f", ad.rating))
                                .font(.system(size: 10, weight: .bold))
                            Text("•")
                                .foregroundColor(.secondary)
                                .font(.system(size: 9))
                            Text(ad.category)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                // Spec Chip
                if let firstSpec = ad.specs.first {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(accentColor)
                        Text(firstSpec)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.primary.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(4)
                }
                
                // Call To Action Button
                Button(action: {
                    adEngine.recordAdClick(ad: ad)
                }) {
                    HStack {
                        Text(ad.callToAction)
                            .font(.system(size: 10, weight: .bold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .black))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .shadow(color: accentColor.opacity(0.25), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.25), value: ad.id)
        }
    }
}


// MARK: - 2. TopBar Sponsor View (Clean, Non-Intrusive, Fixed on Top of Window)

public struct TopBarSponsorView: View {
    @ObservedObject var adEngine: AdEngineService
    
    public init(adEngine: AdEngineService) {
        self.adEngine = adEngine
    }
    
    public var body: some View {
        if adEngine.isAdFreeUnlocked {
            EmptyView()
        } else {
            let ad = adEngine.currentSponsorAd
            let accentColor = Color(hex: ad.accentColorHex) ?? CovaTheme.primaryBlue
            let allAds = adEngine.allAds
            let currentIndex = adEngine.currentAdIndex % max(1, allAds.count)
            
            HStack(spacing: 12) {
            // Product Icon Box
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 30, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(accentColor.opacity(0.3), lineWidth: 1)
                    )
                if let imgStr = ad.imageURLString, let url = URL(string: imgStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        default:
                            Image(systemName: ad.iconSystemName)
                                .font(.system(size: 15))
                                .foregroundColor(accentColor)
                        }
                    }
                } else {
                    Image(systemName: ad.iconSystemName)
                        .font(.system(size: 15))
                        .foregroundColor(accentColor)
                }
            }
            
            // Badge Pill
            Text(ad.badgeText)
                .font(.system(size: 8, weight: .black))
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(accentColor.opacity(0.16))
                .foregroundColor(accentColor)
                .cornerRadius(4)
            
            // Title, Rating & Tagline
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(ad.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 9))
                        Text(String(format: "%.1f", ad.rating))
                            .font(.system(size: 10, weight: .bold))
                        Text("(\(ad.reviewCount))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(ad.tagline)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Spec Chip
            if let spec = ad.specs.first {
                Text(spec)
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Carousel Chevrons
            HStack(spacing: 4) {
                Button(action: {
                    withAnimation {
                        adEngine.rotateToPreviousAd()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Previous gear")
                
                Text("\(currentIndex + 1)/\(allAds.count)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Button(action: {
                    withAnimation {
                        adEngine.rotateToNextAd()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Next gear")
            }
            
            // Call To Action Button
            Button(action: {
                adEngine.recordAdClick(ad: ad)
            }) {
                HStack(spacing: 5) {
                    Text(ad.callToAction)
                        .font(.system(size: 11, weight: .bold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .black))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(6)
                .shadow(color: accentColor.opacity(0.3), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.08)),
            alignment: .bottom
        )
        .animation(.easeInOut(duration: 0.25), value: ad.id)
        }
    }
}

// MARK: - Compatibility Stubs (Not shown in middle of functions)

public struct BannerSponsorCardView: View {
    @ObservedObject var adEngine: AdEngineService
    var section: NavigationSection
    
    public init(adEngine: AdEngineService, section: NavigationSection = .dashboard) {
        self.adEngine = adEngine
        self.section = section
    }
    
    public var body: some View {
        EmptyView()
    }
}

public struct LargeSpotlightSponsorCardView: View {
    @ObservedObject var adEngine: AdEngineService
    var section: NavigationSection
    
    public init(adEngine: AdEngineService, section: NavigationSection = .dashboard) {
        self.adEngine = adEngine
        self.section = section
    }
    
    public var body: some View {
        EmptyView()
    }
}

public struct InlineContextualRecommendationBar: View {
    @ObservedObject var adEngine: AdEngineService
    var section: NavigationSection
    var contextPrompt: String
    
    public init(adEngine: AdEngineService, section: NavigationSection, contextPrompt: String) {
        self.adEngine = adEngine
        self.section = section
        self.contextPrompt = contextPrompt
    }
    
    public var body: some View {
        EmptyView()
    }
}

public struct SectionSponsorCardView: View {
    @ObservedObject var adEngine: AdEngineService
    var section: NavigationSection
    
    public init(adEngine: AdEngineService, section: NavigationSection = .dashboard) {
        self.adEngine = adEngine
        self.section = section
    }
    
    public var body: some View {
        EmptyView()
    }
}
