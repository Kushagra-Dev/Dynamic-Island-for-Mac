import Foundation
import CoreLocation
import Combine
import SwiftUI

class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var temperature: Double = 0
    @Published var highTemp: Double = 0
    @Published var lowTemp: Double = 0
    @Published var weatherCode: Int = 0
    @Published var locationName: String = "Loading..."
    @Published var isLoaded: Bool = false
    @Published var humidity: Int = 0
    @Published var windSpeed: Double = 0
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var refreshTimer: AnyCancellable?
    private var lastLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        
        // Request location permission
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        // Auto-refresh every 15 minutes
        refreshTimer = Timer.publish(every: 900, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshWeather()
            }
    }
    
    private func refreshWeather() {
        if let location = lastLocation {
            fetchWeather(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        
        // Only fetch once, then rely on timer for updates
        locationManager.stopUpdatingLocation()
        
        DispatchQueue.main.async {
            if self.locationName == "Location unavailable" || self.locationName == "Loading..." {
                self.locationName = "Locating..."
            }
        }
        
        fetchWeather(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
        reverseGeocode(location: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        
        // We do NOT stopUpdatingLocation here. If it's a temporary error (like locationUnknown), it might recover.
        
        DispatchQueue.main.async {
            if self.locationName == "Loading..." {
                self.locationName = "Locating (IP Fallback)..."
            }
        }
        
        // If we haven't loaded any data yet, attempt IP-based location fallback
        if !isLoaded {
            fetchIPLocation()
        }
    }
    
    // MARK: - IP Location Fallback
    private func fetchIPLocation() {
        guard let url = URL(string: "http://ip-api.com/json/") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            guard let data = data, error == nil else {
                // Absolute worst case fallback if even IP fails
                if !self.isLoaded {
                    DispatchQueue.main.async {
                        self.locationName = "Fallback City"
                    }
                    self.fetchWeather(lat: 28.6139, lon: 77.2090)
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String, status == "success",
                   let lat = json["lat"] as? Double,
                   let lon = json["lon"] as? Double,
                   let city = json["city"] as? String {
                    
                    DispatchQueue.main.async {
                        self.locationName = city
                    }
                    self.fetchWeather(lat: lat, lon: lon)
                } else {
                    if !self.isLoaded {
                        DispatchQueue.main.async { self.locationName = "Fallback City" }
                        self.fetchWeather(lat: 28.6139, lon: 77.2090)
                    }
                }
            } catch {
                if !self.isLoaded {
                    DispatchQueue.main.async { self.locationName = "Fallback City" }
                    self.fetchWeather(lat: 28.6139, lon: 77.2090)
                }
            }
        }.resume()
    }
    
    // MARK: - Geocoding
    private func reverseGeocode(location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Geocode error: \(error.localizedDescription)")
                    // Apple geocoder is heavily rate limited on restarts. Fallback gracefully.
                    self.locationName = "Local Area"
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    self.locationName = "Unknown"
                    return
                }
                
                if let city = placemark.locality {
                    self.locationName = city
                } else if let area = placemark.administrativeArea {
                    self.locationName = area
                } else {
                    self.locationName = "Local Area"
                }
            }
        }
    }
    
    // MARK: - Open-Meteo API (free, no key needed)
    private func fetchWeather(lat: Double, lon: Double) {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                print("Weather fetch error: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async {
                        // Current weather
                        if let current = json["current"] as? [String: Any] {
                            self.temperature = (current["temperature_2m"] as? Double) ?? 0
                            self.weatherCode = (current["weather_code"] as? Int) ?? 0
                            self.humidity = (current["relative_humidity_2m"] as? Int) ?? 0
                            self.windSpeed = (current["wind_speed_10m"] as? Double) ?? 0
                        }
                        
                        // Daily high/low
                        if let daily = json["daily"] as? [String: Any] {
                            if let maxTemps = daily["temperature_2m_max"] as? [Double], let max = maxTemps.first {
                                self.highTemp = max
                            }
                            if let minTemps = daily["temperature_2m_min"] as? [Double], let min = minTemps.first {
                                self.lowTemp = min
                            }
                        }
                        
                        self.isLoaded = true
                    }
                }
            } catch {
                print("Weather JSON parse error: \(error)")
            }
        }.resume()
    }
    
    // MARK: - WMO Weather Code → SF Symbol + Description
    var conditionSymbol: String {
        switch weatherCode {
        case 0: return "sun.max.fill"
        case 1: return "sun.min.fill"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77: return "cloud.hail.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
    
    var conditionDescription: String {
        switch weatherCode {
        case 0: return "Clear Sky"
        case 1: return "Mostly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61, 63, 65: return "Rainy"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75: return "Snowy"
        case 77: return "Snow Grains"
        case 80, 81, 82: return "Heavy Rain"
        case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Hailstorm"
        default: return "Unknown"
        }
    }
    
    /// Color accent for the weather condition
    var conditionColor: Color {
        switch weatherCode {
        case 0, 1: return .yellow
        case 2, 3: return .gray
        case 45, 48: return .gray.opacity(0.7)
        case 51...67: return .blue
        case 71...86: return .cyan
        case 95, 96, 99: return .purple
        default: return .blue
        }
    }
}
