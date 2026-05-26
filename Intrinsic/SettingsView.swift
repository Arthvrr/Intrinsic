import SwiftUI

// MARK: - SETTINGS VIEW
struct SettingsView: View {
    @AppStorage("userFinnhubKey") private var userFinnhubKey: String = ""
    @AppStorage("userExchangeRateKey") private var userExchangeRateKey: String = ""
    @AppStorage("userGeminiKey") private var userGeminiKey: String = ""
    @AppStorage("defaultMarginOfSafety") private var defaultMarginOfSafety: Double = 10.0
    @AppStorage("appTheme") private var appTheme: String = "System"

    var body: some View {
        Form {
            Section(header: Text("API Configuration").font(.headline)) {
                Text("Enter your personal API keys to power the valuation engine.")
                    .font(.caption).foregroundColor(.secondary)

                VStack(alignment: .leading) {
                    HStack {
                        Text("Finnhub API Key")
                        Spacer()
                        Link("Get Key", destination: URL(string: "https://finnhub.io/")!).font(.caption)
                    }
                    SecureField("Paste key here...", text: $userFinnhubKey).textFieldStyle(.roundedBorder)
                }.padding(.vertical, 5)

                VStack(alignment: .leading) {
                    HStack {
                        Text("ExchangeRate API Key")
                        Spacer()
                        Link("Get Key", destination: URL(string: "https://www.exchangerate-api.com/")!).font(.caption)
                    }
                    SecureField("Paste key here...", text: $userExchangeRateKey).textFieldStyle(.roundedBorder)
                }.padding(.vertical, 5)
            }

            Section(header: HStack {
                Image(systemName: "sparkles").foregroundColor(.purple)
                Text("AI Analysis (Optional)").font(.headline)
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Google Gemini API Key")
                        Spacer()
                        Link("Get free key →", destination: URL(string: "https://aistudio.google.com/apikey")!)
                            .font(.caption).foregroundColor(.purple)
                    }
                    SecureField("Paste Gemini key here...", text: $userGeminiKey).textFieldStyle(.roundedBorder)
                    if !userGeminiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                            Text("AI Analysis enabled — button appears in toolbar after calculating")
                                .font(.caption).foregroundColor(.green)
                        }
                    } else {
                        Text("After calculating a valuation, a ✨ AI button will appear in the toolbar to generate an investment analysis powered by Gemini 2.0 Flash.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }.padding(.vertical, 5)
            }

            Section(header: Text("Defaults").font(.headline)) {
                VStack(alignment: .leading) {
                    Text("Default Margin of Safety: \(Int(defaultMarginOfSafety))%")
                    Slider(value: $defaultMarginOfSafety, in: 0...50, step: 5)
                }.padding(.vertical, 5)
            }

            Section(header: Text("Appearance").font(.headline)) {
                Picker("Theme", selection: $appTheme) {
                    Text("System").tag("System")
                    Text("Light Mode").tag("Light")
                    Text("Dark Mode").tag("Dark")
                }.pickerStyle(.segmented)
            }

            Section {
                HStack {
                    Spacer()
                    Text("Intrinsic v2.0 • Build for Investors")
                        .font(.caption2).foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .frame(width: 480, height: 520)
    }
}
