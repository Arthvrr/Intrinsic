import SwiftUI

// --- 1. STRUCTURES ULTRA-SOUPLES (Tout est optionnel) ---
struct YahooResponse: Codable {
    let chart: YahooChart
}

struct YahooChart: Codable {
    let result: [YahooResult]?
    let error: YahooError?
}

struct YahooError: Codable {
    let description: String?
}

struct YahooResult: Codable {
    let meta: YahooMeta
}

// On met des "?" partout. Si Yahoo n'envoie pas l'info, on ne plante pas.
struct YahooMeta: Codable {
    let symbol: String
    let currency: String?
    let regularMarketPrice: Double? // Le prix actuel OU le dernier prix de clôture
    let previousClose: Double?      // La clôture de la veille
    let chartPreviousClose: Double? // Une autre façon que Yahoo a de nommer la clôture
}
// ---------------------------------------------------------

struct ContentView: View {
    @State private var ticker: String = ""
    @State private var price: String = "---"
    @State private var variation: String = ""
    @State private var isPositive: Bool = true
    @State private var isLoading = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 25) {
            Text("Prix Action (24/7)")
                .font(.headline)
                .opacity(0.7)

            HStack {
                TextField("Ticker (ex: AAPL)", text: $ticker)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onSubmit { fetchPrice() }

                Button("Rechercher") {
                    fetchPrice()
                }
                .buttonStyle(.borderedProminent)
                .disabled(ticker.isEmpty)
            }

            Divider()

            if isLoading {
                ProgressView()
            } else if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            } else {
                VStack(spacing: 5) {
                    Text(price)
                        .font(.system(size: 46, weight: .bold))
                        .monospacedDigit()
                    
                    if !variation.isEmpty {
                        Text(variation)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(isPositive ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundColor(isPositive ? .green : .red)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    func fetchPrice() {
        // Nettoyage input
        let cleanTicker = ticker
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .uppercased()
        
        guard !cleanTicker.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        // On demande "interval=1d" pour avoir les données journalières,
        // c'est plus stable quand le marché est fermé.
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(cleanTicker)?interval=1d"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { DispatchQueue.main.async { isLoading = false } }

            if let error = error {
                DispatchQueue.main.async { errorMessage = "Erreur réseau : \(error.localizedDescription)" }
                return
            }

            guard let data = data else { return }

            do {
                let response = try JSONDecoder().decode(YahooResponse.self, from: data)
                
                // Vérif si Yahoo renvoie une erreur explicite
                if let errorInfo = response.chart.error {
                    DispatchQueue.main.async { errorMessage = "Erreur : \(errorInfo.description ?? "Ticker inconnu")" }
                    return
                }

                if let result = response.chart.result?.first {
                    let meta = result.meta
                    
                    // --- LOGIQUE DE RECUPERATION BLINDÉE ---
                    // 1. On cherche le prix "normal". Si pas là, on cherche "previousClose".
                    // Si aucun des deux, on met 0.0.
                    let currentPrice = meta.regularMarketPrice ?? meta.chartPreviousClose ?? meta.previousClose ?? 0.0
                    
                    // 2. On cherche la référence pour calculer la variation
                    let referencePrice = meta.chartPreviousClose ?? meta.previousClose ?? currentPrice
                    
                    // 3. Devise (USD par défaut)
                    let currency = meta.currency ?? "USD"
                    
                    // 4. Calculs
                    let change = currentPrice - referencePrice
                    // Eviter la division par zéro
                    let percent = referencePrice != 0 ? (change / referencePrice) * 100 : 0.0
                    
                    DispatchQueue.main.async {
                        if currentPrice == 0.0 {
                            self.price = "Indisponible"
                            self.errorMessage = "Données vides reçues de Yahoo"
                        } else {
                            self.price = String(format: "%.2f %@", currentPrice, currency)
                            self.isPositive = change >= 0
                            
                            // Si c'est 0% pile, on affiche juste 0%
                            self.variation = String(format: "%@%.2f %%", change >= 0 ? "+" : "", percent)
                        }
                    }
                } else {
                    DispatchQueue.main.async { errorMessage = "Ticker introuvable." }
                }
            } catch {
                DispatchQueue.main.async { errorMessage = "Données illisibles." }
                print("Erreur JSON : \(error)")
            }
        }.resume()
    }
}
