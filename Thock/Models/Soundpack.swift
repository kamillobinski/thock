import Foundation

struct Soundpack: Equatable {
    let id: UUID
    let name: String
    let brand: String
    let author: String
    let category: String
    var path: String
    
    static func == (lhs: Soundpack, rhs: Soundpack) -> Bool {
        return lhs.id == rhs.id
    }
}
