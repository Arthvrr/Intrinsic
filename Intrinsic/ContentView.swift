import SwiftUI
import Charts // NOUVEAU : Nécessaire pour le graphique linéaire

// --- STRUCTURES YAHOO (Inchangées) ---
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

// Enum pour choisir la méthode
enum ValuationMethod: String, CaseIterable, Identifiable {
    case gordon = "Conservateur (Perpétuel)"
    case multiples = "Marché (Multiples)"
    var id: Self { self }
}

// NOUVEAU : Structure pour les points du graphique linéaire
struct ProjectionPoint: Identifiable {
    let id = UUID()
    let year: Int
    let value: Double
}

struct ContentView: View {
    // --- ÉTATS ---
    @State private var ticker: String = "ASML"
    @State private var priceDisplay: String = "---"
    @State private var isLoading = false
    @State private var currentPrice: Double = 0.0

    // Saisie en String
    @State private var fcfInput: String = "6.58"
    @State private var sharesInput: String = "14.78"
    @State private var cashInput: String = "165"
    @State private var debtInput: String = "112"

    // Hypothèses
    @State private var growthRate: Double = 12.0
    @State private var discountRate: Double = 9.0
    
    // Méthode
    @State private var selectedMethod: ValuationMethod = .multiples
    @State private var terminalGrowth: Double = 2.5
    @State private var exitMultiple: Double = 40.0
    
    // Résultats
    @State private var intrinsicValue: Double = 0.0
    // NOUVEAU : Données pour le graphique linéaire
    @State private var projectionData: [ProjectionPoint] = []

    var body: some View {
        HSplitView {
            // --- COLONNE GAUCHE (Paramètres) ---
            VStack(spacing: 0) {
                Text("Paramètres DCF")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                
                Form {
                    Section(header: Text("Recherche")) {
                        HStack {
                            TextField("Ticker", text: $ticker).onSubmit { fetchPrice() }
                            Button("Charger") { fetchPrice() }
                        }
                        HStack {
                            Text("Prix Marché :")
                            Spacer()
                            if isLoading { ProgressView().scaleEffect(0.5) }
                            Text(priceDisplay).bold()
                        }
                    }
                    
                    Section(header: Text("Fondamentaux")) {
                        // CORRECTION ICI : L'inputRowString est nettoyé
                        inputRowString(label: "FCF / Action", value: $fcfInput, helpText: "Free Cash Flow par action")
                        inputRowString(label: "Nb Actions (Mds)", value: $sharesInput, helpText: "Milliards d'actions")
                        inputRowString(label: "Cash Total", value: $cashInput, helpText: "Cash + Placements (Milliards)")
                        inputRowString(label: "Dette Totale", value: $debtInput, helpText: "Dette Totale (Milliards)")
                    }
                    
                    Section(header: Text("Méthode de Sortie (Année 5)")) {
                        Picker("Méthode", selection: $selectedMethod) {
                            ForEach(ValuationMethod.allCases) { method in
                                Text(method.rawValue).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 5)
                        
                        inputRowDouble(label: "Croissance (1-5 ans)", value: $growthRate, suffix: "%", helpText: "Croissance annuelle sur 5 ans.")
                        inputRowDouble(label: "Taux d'actualisation", value: $discountRate, suffix: "%", helpText: "Ton exigence de rentabilité (Risque).")

                        if selectedMethod == .gordon {
                            inputRowDouble(label: "Croissance Perpétuelle", value: $terminalGrowth, suffix: "%", helpText: "Croissance à l'infini après l'année 5 (Max 3%).")
                        } else {
                            inputRowDouble(label: "Multiple de Sortie", value: $exitMultiple, suffix: "x", helpText: "A combien x le FCF l'action se vendra dans 5 ans ?")
                        }
                    }
                }
                .formStyle(.grouped)
            }
            .frame(minWidth: 320, maxWidth: 400)
            
            // --- COLONNE DROITE (Résultats) ---
            ZStack(alignment: .top) { // 1. On aligne tout en HAUT
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea() // 2. La couleur remplit tout l'écran
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Résultat de la Valorisation")
                            .font(.title)
                            .opacity(0.5)
                            .padding(.top, 40) // Un peu d'air en haut
                        
                        // 1. Chiffres Principaux
                        HStack(spacing: 50) {
                            VStack {
                                Text("Prix Actuel")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text(priceDisplay)
                                    .font(.system(size: 36, weight: .bold))
                            }
                            
                            Image(systemName: "arrow.right")
                                .font(.largeTitle)
                                .opacity(0.3)
                            
                            VStack {
                                Text("Valeur Intrinsèque")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(String(format: "%.2f $", intrinsicValue))
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(intrinsicValue > currentPrice ? .green : .red)
                            }
                        }
                        .padding(.vertical, 20)
                        
                        // 2. Graphique à Barres
                        if currentPrice > 0 && intrinsicValue > 0 {
                            ValuationBarChart(marketPrice: currentPrice, intrinsicValue: intrinsicValue)
                                .frame(height: 180)
                                .padding(.horizontal, 40)
                        }
                        
                        // 3. Graphique Linéaire
                        if !projectionData.isEmpty && intrinsicValue > 0 {
                            ProjectedGrowthChart(data: projectionData)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 20)
                        }
                        
                        // 4. Marge & Bouton
                        VStack(spacing: 20) {
                            if currentPrice > 0 && intrinsicValue > 0 {
                                let margin = ((intrinsicValue - currentPrice) / intrinsicValue) * 100
                                VStack(spacing: 5) {
                                    Text(margin > 0 ? "SOUS-ÉVALUÉ (Marge de sécurité)" : "SURÉVALUÉ (Trop cher)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(margin > 0 ? .green : .red)
                                        .textCase(.uppercase)
                                    
                                    Text(String(format: "%.1f %%", abs(margin)))
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(margin > 0 ? .green : .red)
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 5)
                                        .background(margin > 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            
                            Button("CALCULER") {
                                calculateIntrinsicValue()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        .padding(.bottom, 50) // Espace en bas pour le scroll
                    }
                    .frame(maxWidth: .infinity) // Le contenu prend toute la largeur
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // La colonne prend toute la place dispo
        }
    }
    
    // --- Helpers Conversion ---
    func parseDouble(_ input: String) -> Double {
        let clean = input.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(clean) ?? 0.0
    }

    // --- Helpers UI ---
    // CORRECTION DU BUG DES "0" ICI
    func inputRowString(label: String, value: Binding<String>, helpText: String) -> some View {
        HStack {
            Text(label).help(helpText)
            Image(systemName: "info.circle").font(.caption2).opacity(0.5).help(helpText)
            Spacer()
            // Le TextField est collé au Spacer, sans texte parasite entre les deux
            TextField("0", text: value)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
        }
    }
    
    func inputRowDouble(label: String, value: Binding<Double>, suffix: String, helpText: String) -> some View {
        HStack {
            Text(label).help(helpText)
            Image(systemName: "info.circle").font(.caption2).opacity(0.5).help(helpText)
            Spacer()
            HStack(spacing: 2) {
                TextField("", value: value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                Text(suffix).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    // --- CALCUL ---
    func calculateIntrinsicValue() {
        let fcfPerShare = parseDouble(fcfInput)
        let sharesOutstanding = parseDouble(sharesInput)
        let totalCash = parseDouble(cashInput)
        let totalDebt = parseDouble(debtInput)
        
        let g = growthRate / 100.0
        let r = discountRate / 100.0
        
        var futureCashFlows: [Double] = []
        var sumPV = 0.0
        var currentFCF = fcfPerShare
        
        // --- NOUVEAU : Génération des données pour le graphique linéaire ---
        var newProjections: [ProjectionPoint] = []
        // Année 0 = Prix actuel (ou une estimation si le prix n'est pas chargé)
        let startValue = currentPrice > 0 ? currentPrice : (fcfPerShare * exitMultiple)
        newProjections.append(ProjectionPoint(year: 0, value: startValue))
        var projectedValue = startValue
        // -------------------------------------------------------------------
        
        for i in 1...5 {
            // Calcul DCF
            currentFCF = currentFCF * (1 + g)
            futureCashFlows.append(currentFCF)
            let discountFactor = pow(1 + r, Double(i))
            sumPV += (currentFCF / discountFactor)
            
            // Calcul Projection Graphique (Croissance simple du prix)
            projectedValue = projectedValue * (1 + g)
            newProjections.append(ProjectionPoint(year: i, value: projectedValue))
        }
        
        let lastFCF = futureCashFlows.last ?? fcfPerShare
        var terminalValue = 0.0
        
        if selectedMethod == .gordon {
            let tg = terminalGrowth / 100.0
            if r > tg { terminalValue = (lastFCF * (1 + tg)) / (r - tg) }
        } else {
            terminalValue = lastFCF * exitMultiple
        }
        
        let terminalValuePV = terminalValue / pow(1 + r, 5.0)
        let netCashPerShare = (sharesOutstanding > 0) ? (totalCash - totalDebt) / sharesOutstanding : 0.0
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            self.intrinsicValue = sumPV + terminalValuePV + netCashPerShare
            self.projectionData = newProjections // Mise à jour du graphique
        }
    }
    
    // --- YAHOO FETCH ---
    func fetchPrice() {
        let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "").uppercased()
        guard !cleanTicker.isEmpty else { return }
        
        isLoading = true
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(cleanTicker)?interval=1d"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            defer { DispatchQueue.main.async { isLoading = false } }
            guard let data = data else { return }
            if let response = try? JSONDecoder().decode(YahooResponse.self, from: data),
               let result = response.chart.result?.first {
                let price = result.meta.regularMarketPrice ?? result.meta.previousClose ?? 0.0
                let currency = result.meta.currency ?? "USD"
                DispatchQueue.main.async {
                    self.currentPrice = price
                    self.priceDisplay = String(format: "%.2f %@", price, currency)
                }
            }
        }.resume()
    }
}

// --- COMPOSANT : GRAPHIQUE BARRES ---
struct ValuationBarChart: View {
    var marketPrice: Double
    var intrinsicValue: Double
    
    private var maxValue: Double { max(marketPrice, intrinsicValue) * 1.1 }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 60) {
                BarView(value: marketPrice, maxValue: maxValue, label: "Marché", color: Color.gray.opacity(0.4), height: geometry.size.height)
                BarView(value: intrinsicValue, maxValue: maxValue, label: "Valeur", color: intrinsicValue >= marketPrice ? Color.green : Color.red, height: geometry.size.height)
            }
        }
    }
}

struct BarView: View {
    var value: Double; var maxValue: Double; var label: String; var color: Color; var height: CGFloat
    var barHeight: CGFloat { guard maxValue > 0 else { return 0 }; return height * (value / maxValue) }
    
    var body: some View {
        VStack {
            Text("\(Int(value)) $").font(.headline).foregroundColor(.secondary)
            RoundedRectangle(cornerRadius: 8).fill(color.gradient).frame(height: barHeight)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: value)
            Text(label).font(.subheadline).fontWeight(.bold).foregroundColor(.secondary)
        }
    }
}

// --- NOUVEAU COMPOSANT : GRAPHIQUE LINÉAIRE ---
struct ProjectedGrowthChart: View {
    var data: [ProjectionPoint]
    
    // Détermine si la tendance est haussière pour la couleur
    var isPositiveGrowth: Bool {
        guard let first = data.first, let last = data.last else { return true }
        return last.value >= first.value
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Projection de la valeur (5 ans)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Chart(data) { point in
                // La ligne
                LineMark(
                    x: .value("Année", point.year),
                    y: .value("Valeur", point.value)
                )
                .interpolationMethod(.catmullRom) // Lissage de la courbe
                .foregroundStyle(isPositiveGrowth ? Color.green.gradient : Color.red.gradient)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                // La zone remplie sous la ligne
                AreaMark(
                    x: .value("Année", point.year),
                    yStart: .value("Base", data.first?.value ?? 0), // Remplir à partir du prix de base
                    yEnd: .value("Valeur", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(isPositiveGrowth ? Color.green.opacity(0.1).gradient : Color.red.opacity(0.1).gradient)
                
                // Points sur la ligne
                PointMark(
                    x: .value("Année", point.year),
                    y: .value("Valeur", point.value)
                )
                .foregroundStyle(isPositiveGrowth ? Color.green : Color.red)
            }
            .chartXScale(domain: 0...5) // Axe X fixe de 0 à 5 ans
            .chartYAxis {
                AxisMarks(position: .leading) // Axe Y à gauche
            }
            .frame(height: 150) // Hauteur du graphique
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor)) // Fond légère pour faire ressortir le graph
        .cornerRadius(12)
    }
}
