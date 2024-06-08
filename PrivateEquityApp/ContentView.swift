//
//  ContentView.swift
//  PrivateEquityApp
//
//  Created by Steven Zhang on 2024-06-07.
//

import SwiftUI
import MarkdownUI

struct ContentView: View {
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    @State private var apiResponse = ""
    @State private var isLoading = false
    @State private var hasSearched = false

    var body: some View {
        ZStack {
            StarBackgroundView()
            
            VStack {
                Spacer(minLength: hasSearched ? (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0 : 0)

                
                VStack {
                    Text("Index by Endex")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom)
                    
                    HStack {
                        SearchBar(text: $searchText, onSearch: performSearch)
                        
                        Button(action: {
                            performSearch()
                        }) {
                            Text("Search")
                                .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                                .frame(height: 5)
                                .padding()
                                .background(colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.8))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.move(edge: .top))
                .animation(.easeInOut, value: hasSearched)
                
                if isLoading {
                    ProgressView()
                        .padding()
                } else if !apiResponse.isEmpty {
                    ScrollView {
                        ResponseView(paragraphs: apiResponse.split(separator: "\n").map { String($0) })
                    }
                    .frame(maxHeight: .infinity)
                }
                
                Spacer()
            }
            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
        .edgesIgnoringSafeArea(.all)
    }

    private func performSearch() {
        withAnimation(.easeInOut) {
            hasSearched = true
        }
        fetchAPIResponse()
    }

    private func fetchAPIResponse() {
        isLoading = true
        apiResponse = ""
        
        guard let url = URL(string: "https://api.perplexity.ai/chat/completions") else {
            print("Invalid URL")
            isLoading = false
            return
        }
        
        let companyPrompt = """
        Please provide the following details about the company "\(searchText)":

        - **Name**: The official name of the company.
        - **Blurb**: A short description of what the company does.
        - **Overview of company**: A brief overview of the company's mission and operations.
        - **Date founded**: The date when the company was founded.
        - **Founders & title**: The names and titles of the founders.
        - **Stage**: The current stage of the company (e.g., startup, growth, mature).
        - **Funding amount**: The total amount of funding the company has received.
        - **Number of employees**: The total number of employees working at the company.
        - **Similar companies/competitors**: A list of similar companies or competitors.

        Please make the response concise and structured as follows:

        **Name**:
        [Name]

        **Blurb**:
        [Blurb]

        **Overview of company**:
        [Overview]

        **Date founded**:
        [Date founded]

        **Founders & title**:
        [Founders & title]

        **Stage**:
        [Stage]

        **Funding amount**:
        [Funding amount]

        **Number of employees**:
        [Number of employees]

        **Similar companies/competitors**:
        [Similar companies/competitors]
        """
        
        let parameters: [String: Any] = [
            "model": "llama-3-sonar-small-32k-online",
            "messages": [
                [
                    "role": "system",
                    "content": "Be precise and concise."
                ],
                [
                    "role": "user",
                    "content": companyPrompt
                ]
            ]
        ]
        
        let postData = try? JSONSerialization.data(withJSONObject: parameters, options: [])
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "content-type": "application/json",
            "authorization": "Bearer \(Secrets.apiKey)"
        ]
        request.httpBody = postData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8),
               let jsonData = responseString.data(using: .utf8),
               let jsonResponse = try? JSONDecoder().decode(APIResponse.self, from: jsonData),
               let content = jsonResponse.choices.first?.message.content {
                DispatchQueue.main.async {
                    apiResponse = content
                    isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    isLoading = false
                }
            }
        }.resume()
    }
}

struct APIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}

struct ResponseView: View {
    let paragraphs: [String]
    
    var body: some View {
        VStack(alignment: .leading) {
            ForEach(paragraphs, id: \.self) { paragraph in
                VStack(alignment: .leading) {
                    Markdown(paragraph)
                        .padding()
                }
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .padding(.vertical, 5)
            }
        }
        .padding()
    }
}

struct Secrets {
    static let apiKey = ProcessInfo.processInfo.environment["Bearer"] ?? ""
}

struct StarBackgroundView: View {
    @State private var stars: [StarPosition] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(stars, id: \.id) { star in
                    Circle()
                        .fill(Color.white)
                        .frame(width: star.size, height: star.size)
                        .position(x: star.x, y: star.y)
                        .opacity(star.opacity)
                        .onAppear {
                            withAnimation(Animation.linear(duration: star.duration).repeatForever(autoreverses: false)) {
                                self.stars[self.stars.firstIndex(where: { $0.id == star.id })!].opacity = 0
                            }
                        }
                }
            }
            .onAppear {
                self.generateStars(in: geometry.size)
            }
        }
    }
    
    private func generateStars(in size: CGSize) {
        for _ in 1...100 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let size = CGFloat.random(in: 1...3)
            let duration = Double.random(in: 1...3)
            let opacity = Double.random(in: 0.1...1)
            
            let star = StarPosition(x: x, y: y, size: size, opacity: opacity, duration: duration)
            stars.append(star)
        }
    }
}

struct StarPosition: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    var opacity: Double
    let duration: Double
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.colorScheme, .dark)
    }
}

struct SearchBar: View {
    @Binding var text: String
    @Environment(\.colorScheme) var colorScheme
    var onSearch: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search...", text: $text, onCommit: onSearch)
                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: {
                    self.text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(colorScheme == .dark ? Color(UIColor.systemGray5).opacity(0.2) : Color(UIColor.systemGray5))
        .cornerRadius(10)
    }
}
