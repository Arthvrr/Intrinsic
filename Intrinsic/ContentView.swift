import SwiftUI

// --- STRUCTURES YAHOO (Les mêmes qu'avant) ---
struct YahooResponse: Codable { let chart: YahooChart }
struct YahooChart: Codable { let result: [YahooResult]?; let error: YahooError? }
struct YahooError: Codable { let description: String? }
struct YahooResult: Codable { let meta: YahooMeta }
struct YahooMeta: Codable {
    let symbol: String
    let currency: String?
    let regularMarketPrice: Double?
    let previousClose: Double?
    let chartPreviousClose: Double?
}
// ---------------------------------------------

struct ContentView: View {
    // --- ÉTATS (Données de l'UI) ---
    // Partie 1 : Yahoo
    @State private var ticker: String = "AAPL"
    @State private var currentPrice: Double = 0.0
    @State private var priceDisplay: String = "---"
    @State private var isLoading = false
    @State private var errorMessage: String = ""
    
    // Partie 2 : Saisie DCF (Valeurs par défaut pour tester)
    @State private var fcfPerShare: Double = 6.0    // Exemple
    @State private var totalCash: Double = 0.0      // En millions ou milliards (cohérent avec dette)
    @State private var totalDebt: Double = 0.0
    @State private var sharesOutstanding: Double = 1.0 // Nombre d'actions
    
    // Partie 3 : Hypothèses
    @State private var growthRate: Double = 10.0    // 10% de croissance
    @State private var discountRate: Double = 9.0   // 9% coût du capital
    @State private var terminalGrowth: Double = 2.0 // 2% perpétuel après 5 ans
    
    // Résultat calculé
    @State private var intrinsicValue: Double = 0.0

    var body: some View {
        HSplitView {
            // --- COLONNE GAUCHE : Saisie et Paramètres ---
            VStack(spacing: 0) {
                // En-tête bleu
                Text("Paramètres DCF")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                
                Form {
                    Section(header: Text("Recherche & Prix")) {
                        HStack {
                            TextField("Ticker", text: $ticker)
                                .onSubmit { fetchPrice() }
                            Button("Charger") { fetchPrice() }
                        }
                        HStack {
                            Text("Prix Marché :")
                            Spacer()
                            if isLoading { ProgressView().scaleEffect(0.5) }
                            Text(priceDisplay).bold()
                        }
                    }
                    
                    Section(header: Text("Fondamentaux (Par Action)")) {
                        inputRow(label: "FCF / Action", value: $fcfPerShare)
                        inputRow(label: "Nb Actions (Total)", value: $sharesOutstanding)
                    }
                    
                    Section(header: Text("Bilan (Total Entreprise)")) {
                        // On demande le total, on divisera par le nb d'actions dans le calcul
                        inputRow(label: "Cash Total", value: $totalCash)
                        inputRow(label: "Dette Totale", value: $totalDebt)
                    }
                    
                    Section(header: Text("Hypothèses (%)")) {
                        inputRow(label: "Croissance (5 ans)", value: $growthRate)
                        inputRow(label: "Taux d'actualisation", value: $discountRate)
                        inputRow(label: "Croissance Terminale", value: $terminalGrowth)
                    }
                }
                .formStyle(.grouped)
            }
            .frame(minWidth: 300, maxWidth: 400)
            
            // --- COLONNE DROITE : Résultats ---
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                
                VStack(spacing: 30) {
                    Text("Résultat de la Valorisation")
                        .font(.title)
                        .opacity(0.5)
                    
                    // Comparaison Visuelle
                    HStack(spacing: 50) {
                        // Prix Actuel
                        VStack {
                            Text("Prix Actuel")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text(priceDisplay)
                                .font(.system(size: 40, weight: .bold))
                        }
                        
                        Image(systemName: "arrow.right")
                            .font(.largeTitle)
                            .opacity(0.3)
                        
                        // Valeur Intrinsèque (Calculée)
                        VStack {
                            Text("Valeur Intrinsèque")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            // Couleur : Vert si Sous-évalué (Bonne affaire), Rouge si Surévalué
                            Text(String(format: "%.2f $", intrinsicValue))
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(intrinsicValue > currentPrice ? .green : .red)
                        }
                    }
                    
                    // Marge de sécurité
                    if currentPrice > 0 && intrinsicValue > 0 {
                        let margin = ((intrinsicValue - currentPrice) / intrinsicValue) * 100
                        VStack(spacing: 5) {
                            Text("Marge de sécurité")
                                .font(.caption)
                                .textCase(.uppercase)
                            
                            Text(String(format: "%.1f %%", margin))
                                .font(.title2)
                                .bold()
                                .foregroundColor(margin > 0 ? .green : .red)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 5)
                                .background(margin > 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    Button("CALCULER MAINTENANT") {
                        calculateIntrinsicValue()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 20)
                }
                .padding()
            }
        }
    }
    
    // --- Helper pour les champs de saisie ---
    func inputRow(label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
        }
    }

    // --- LOGIQUE DE CALCUL DCF ---
    func calculateIntrinsicValue() {
        // 1. Conversion des pourcentages (10% -> 0.10)
        let g = growthRate / 100.0
        let r = discountRate / 100.0
        let tg = terminalGrowth / 100.0
        
        // Sécurité pour éviter division par zéro
        guard r > tg else {
            print("Erreur: Le taux d'actualisation doit être > croissance terminale")
            return
        }
        
        var futureCashFlows: [Double] = []
        var sumPV = 0.0 // Somme des valeurs actualisées
        
        // 2. Projection sur 5 ans
        var currentFCF = fcfPerShare
        
        for i in 1...5 {
            // On augmente le FCF de l'année précédente par le taux de croissance
            currentFCF = currentFCF * (1 + g)
            futureCashFlows.append(currentFCF)
            
            // On ramène cette valeur à aujourd'hui (Discount)
            let discountFactor = pow(1 + r, Double(i))
            let presentValue = currentFCF / discountFactor
            sumPV += presentValue
        }
        
        // 3. Valeur Terminale (Après l'année 5)
        // Formule de Gordon Shapiro : (DernierFCF * (1+tg)) / (r - tg)
        let lastFCF = futureCashFlows.last ?? fcfPerShare
        let terminalValue = (lastFCF * (1 + tg)) / (r - tg)
        
        // Actualisation de la valeur terminale (ramenée de l'année 5 à aujd)
        let terminalValuePV = terminalValue / pow(1 + r, 5.0)
        
        // 4. Ajustement Net Cash par action
        // (Cash Total - Dette Totale) / Nombre d'actions
        let netCashPerShare = (sharesOutstanding > 0) ? (totalCash - totalDebt) / sharesOutstanding : 0.0
        
        // 5. Résultat Final
        let totalValue = sumPV + terminalValuePV + netCashPerShare
        
        // Mise à jour UI
        withAnimation {
            self.intrinsicValue = totalValue
        }
    }
    
    // --- RECUPERATION PRIX YAHOO (Ton code qui marche) ---
    func fetchPrice() {
        let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "").uppercased()
        guard !cleanTicker.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(cleanTicker)?interval=1d"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { DispatchQueue.main.async { isLoading = false } }
            guard let data = data else { return }

            do {
                let response = try JSONDecoder().decode(YahooResponse.self, from: data)
                if let result = response.chart.result?.first {
                    let meta = result.meta
                    let price = meta.regularMarketPrice ?? meta.chartPreviousClose ?? meta.previousClose ?? 0.0
                    let currency = meta.currency ?? "USD"
                    
                    DispatchQueue.main.async {
                        self.currentPrice = price
                        self.priceDisplay = String(format: "%.2f %@", price, currency)
                        // On lance un calcul auto si on a déjà des données saisies
                        if self.intrinsicValue == 0 { self.calculateIntrinsicValue() }
                    }
                }
            } catch {
                print("Erreur: \(error)")
            }
        }.resume()
    }
}
