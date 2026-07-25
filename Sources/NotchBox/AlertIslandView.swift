import SwiftUI

struct WeatherIslandView: View {
    @ObservedObject var weatherManager: WeatherManager
    
    let expandedWidth: CGFloat = LayoutConstants.expandedWidth
    
    // Dynamic Weather Gradient Palette based on active condition
    private var weatherGradient: LinearGradient {
        let sym = weatherManager.conditionSymbol.lowercased()
        let colors: [Color]
        
        if sym.contains("sun") || sym.contains("clear") {
            // Sunny / Clear: Deep Royal Navy fading to Solar Amber/Orange
            colors = [
                Color(red: 0.04, green: 0.08, blue: 0.20),
                Color(red: 0.12, green: 0.16, blue: 0.32),
                Color(red: 0.28, green: 0.18, blue: 0.08)
            ]
        } else if sym.contains("rain") || sym.contains("drizzle") || sym.contains("drop") {
            // Rain: Stormy Deep Slate & Oceanic Dark Blue
            colors = [
                Color(red: 0.03, green: 0.06, blue: 0.14),
                Color(red: 0.08, green: 0.14, blue: 0.24),
                Color(red: 0.12, green: 0.20, blue: 0.30)
            ]
        } else if sym.contains("snow") || sym.contains("ice") || sym.contains("flurries") {
            // Snow: Frosty Indigo & Crisp Glacier Blue
            colors = [
                Color(red: 0.05, green: 0.08, blue: 0.20),
                Color(red: 0.12, green: 0.18, blue: 0.34),
                Color(red: 0.20, green: 0.28, blue: 0.44)
            ]
        } else if sym.contains("bolt") || sym.contains("lightning") || sym.contains("thunder") {
            // Thunderstorm: Dark Violet & Deep Electric Navy
            colors = [
                Color(red: 0.06, green: 0.04, blue: 0.16),
                Color(red: 0.12, green: 0.08, blue: 0.26),
                Color(red: 0.08, green: 0.12, blue: 0.22)
            ]
        } else {
            // Cloudy / Muted: Atmospheric Graphite & Soft Slate Blue
            colors = [
                Color(red: 0.05, green: 0.07, blue: 0.12),
                Color(red: 0.10, green: 0.14, blue: 0.22),
                Color(red: 0.16, green: 0.20, blue: 0.28)
            ]
        }
        
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if weatherManager.isLoaded {
                // Header: Location Badge & Condition
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue.opacity(0.9))
                        Text(weatherManager.locationName.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .kerning(0.8)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    
                    Spacer()
                    
                    Text(weatherManager.conditionDescription)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 24)
                .padding(.top, 38)
                
                // Main Weather Layout
                HStack(alignment: .center, spacing: 18) {
                    // Left: Glowing Animated Condition Icon
                    ZStack {
                        Circle()
                            .fill(weatherManager.conditionColor.opacity(0.18))
                            .frame(width: 64, height: 64)
                            .blur(radius: 8)
                        
                        Image(systemName: weatherManager.conditionSymbol)
                            .font(.system(size: 40, weight: .medium))
                            .symbolRenderingMode(.multicolor)
                            .foregroundColor(weatherManager.conditionColor)
                            .shadow(color: weatherManager.conditionColor.opacity(0.5), radius: 12, x: 0, y: 4)
                    }
                    
                    // Center: Temperature & High/Low
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .top, spacing: 0) {
                            Text("\(Int(round(weatherManager.temperature)))")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("°")
                                .font(.system(size: 24, weight: .light, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .offset(y: 4)
                        }
                        
                        HStack(spacing: 10) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.orange)
                                Text("\(Int(round(weatherManager.highTemp)))°")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.cyan)
                                Text("\(Int(round(weatherManager.lowTemp)))°")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Right: Glassmorphic Metric Capsules
                    VStack(alignment: .trailing, spacing: 8) {
                        // Humidity Pill
                        HStack(spacing: 6) {
                            Image(systemName: "humidity.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.cyan)
                            Text("\(weatherManager.humidity)%")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        
                        // Wind Pill
                        HStack(spacing: 6) {
                            Image(systemName: "wind")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.teal)
                            Text("\(Int(round(weatherManager.windSpeed))) km/h")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 16)
            } else {
                // Loading State
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Updating Weather...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 45)
                .padding(.bottom, 25)
            }
        }
        .padding(.bottom, 22)
        .frame(width: expandedWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.weather") {
                let configuration = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: nil)
            }
        }
        .background(
            ZStack(alignment: .top) {
                Color.black
                
                weatherGradient
                    .opacity(0.85)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .clear, location: 0.22),
                                .init(color: .black.opacity(0.4), location: 0.35),
                                .init(color: .black, location: 0.85)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .compositingGroup()
        )
    }
}

// Keep AlertIslandView for generic alerts (non-weather)
struct AlertIslandView: View {
    let title: String
    let systemImage: String
    
    let expandedWidth: CGFloat = LayoutConstants.expandedWidth
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .regular))
                .foregroundColor(.white)
                .symbolRenderingMode(.hierarchical)
            
            Text(title)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.top, 42)
        .padding(.bottom, 24)
        .frame(width: expandedWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.black)
    }
}
