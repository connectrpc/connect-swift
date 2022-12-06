import Foundation

struct Message {
    enum Author {
        case eliza
        case user
    }

    let id = UUID()
    let message: String
    let author: Author
}

extension Message: Identifiable {
    typealias ID = UUID
}
