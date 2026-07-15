//
//  LLM.swift
//  TingXieFlow
//
//  Created by Ava Zhou on 2026/7/14.
//

import Foundation

nonisolated struct OllamaRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
}

nonisolated struct OllamaResponse: Decodable {
    let response: String
}

func generateText(prompt: String, completion: @escaping (String?) -> Void) {
    guard let url = URL(string: "http://localhost:11434/api/generate") else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let payload = OllamaRequest(model: "llama3", prompt: prompt, stream: false)
    
    do {
        request.httpBody = try JSONEncoder().encode(payload)
    } catch {
        print("Failed to encode payload")
        return
    }
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            print("Error: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        do {
            let result = try JSONDecoder().decode(OllamaResponse.self, from: data)
            DispatchQueue.main.async {
                completion(result.response)
            }
        } catch {
            print("Failed to decode JSON: \(error.localizedDescription)")
        }
    }
    
    task.resume()
}
