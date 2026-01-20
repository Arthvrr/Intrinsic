import SwiftUI

// MARK: - SETTINGS VIEW
struct SettingsView: View {
    // Ces variables sont automatiquement sauvegardées sur le disque
    @AppStorage("userFinnhubKey") private var userFinnhubKey: String = ""
    @AppStorage("userExchangeRateKey") private var userExchangeRateKey: String = ""
    @AppStorage("defaultMarginOfSafety") private var defaultMarginOfSafety: Double = 10.0
    @AppStorage("appTheme") private var appTheme: String = "System" // System, Light, Dark
    
    var body: some View {
        Form {
            // Section API Keys
            Section(header: Text("API Configuration").font(.headline)) {
                Text("Enter your personal API keys to power the valuation engine.")
                    .font(.caption).foregroundColor(.secondary)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Finnhub API Key")
                        Spacer()
                        Link("Get Key", destination: URL(string: "https://finnhub.io/")!)
                            .font(.caption)
                    }
                    SecureField("Paste key here...", text: $userFinnhubKey)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.vertical, 5)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("ExchangeRate API Key")
                        Spacer()
                        Link("Get Key", destination: URL(string: "https://www.exchangerate-api.com/")!)
                            .font(.caption)
                    }
                    SecureField("Paste key here...", text: $userExchangeRateKey)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.vertical, 5)
            }
            
            // Section Defaults
            Section(header: Text("Defaults").font(.headline)) {
                VStack(alignment: .leading) {
                    Text("Default Margin of Safety: \(Int(defaultMarginOfSafety))%")
                    Slider(value: $defaultMarginOfSafety, in: 0...50, step: 5)
                }
                .padding(.vertical, 5)
            }
            
            // Section Appearance
            Section(header: Text("Appearance").font(.headline)) {
                Picker("Theme", selection: $appTheme) {
                    Text("System").tag("System")
                    Text("Light Mode").tag("Light")
                    Text("Dark Mode").tag("Dark")
                }
                .pickerStyle(.segmented)
            }
            
            // Footer
            Section {
                HStack {
                    Spacer()
                    Text("Intrinsic v2.0 • Build for Investors")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .frame(width: 450, height: 400) // Taille de la fenêtre de réglages
    }
}
