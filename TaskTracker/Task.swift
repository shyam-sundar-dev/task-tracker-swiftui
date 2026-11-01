import Foundation
import SwiftUI

enum TaskPriority: String, Equatable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

enum TaskCategory: String, Equatable {
    case design = "Design"
    case engineering = "Engineering"
    case qa = "QA"
    case release = "Release"
    case infra = "Infra"
}

struct Assignee: Equatable {
    let name: String
    let avatarColor: Color
    let initials: String
}

struct Task: Identifiable, Equatable {
    let id = UUID()
    var title: String
    let description: String
    let priority: TaskPriority
    var isCompleted: Bool
    let dueDate: String
    let category: TaskCategory
    let progress: Double          // 0.0 – 1.0
    let tags: [String]
    let assignees: [Assignee]
    let commentCount: Int
    let attachmentCount: Int
    let coverSymbol: String       // SF Symbol used as decorative bg image
    let cardLayoutID: String      // which BDUI compiled layout to use
}

extension Task {

    // 100 tasks built from a pool of varied templates + a generated suffix.
    static let mockData: [Task] = Self.generated100

    private static let generated100: [Task] = {
        let titles = [
            "Design login screen", "Fix crash on launch", "Write unit tests",
            "Performance audit", "Localise strings", "Submit to App Store",
            "Setup CI pipeline", "Refactor networking layer", "Dark mode support",
            "Accessibility audit", "Add push notifications", "Widget extension",
            "Reduce binary size", "Migrate to Swift 6", "In-app review prompt",
            "Deep link handling", "Offline mode", "Onboarding flow",
            "Analytics integration", "A/B test framework",
        ]
        let descriptions = [
            "Create wireframes and finalise UI for the login flow. Covers OAuth, OTP, and social sign-in variants.",
            "App crashes when device has no internet. Need graceful offline fallback and proper error state.",
            "Cover the data layer with at least 80% code coverage. Focus on repository and usecase layers.",
            "Profile scroll performance and fix jank in the feed. Target < 16ms frame time on iPhone 12.",
            "Add Hindi and Tamil localisations for all user-facing text. Use .xcstrings catalog.",
            "Prepare screenshots for all device sizes, write release notes, bump build number, and submit.",
            "Configure GitHub Actions: lint, test, archive, and TestFlight upload on every PR merge to main.",
            "Extract URLSession into a protocol-backed layer so unit tests can inject a fake transport.",
            "Respect system colour scheme, audit every custom colour, add dark-mode snapshot tests.",
            "Run Accessibility Inspector, fix all contrast failures, add meaningful accessibility labels.",
        ]
        let allTags: [[String]] = [
            ["UI", "Auth", "Figma"], ["Crash", "Offline", "Urgent"], ["Tests", "Coverage"],
            ["Perf", "Instruments"], ["i18n", "Hindi", "Tamil"], ["Release", "ASC"],
            ["CI", "GitHub", "Actions"], ["Network", "Protocol"], ["DarkMode", "A11y"],
            ["Widget", "Extensions"], ["Push", "APNs"], ["SwiftUI", "Refactor"],
        ]
        let allAssignees: [[Assignee]] = [
            [Assignee(name: "Ananya", avatarColor: .purple, initials: "AN"),
             Assignee(name: "Rohit",  avatarColor: .blue,   initials: "RO")],
            [Assignee(name: "Kiran",  avatarColor: .red,    initials: "KI")],
            [Assignee(name: "Priya",  avatarColor: .green,  initials: "PR"),
             Assignee(name: "Dev",    avatarColor: .orange, initials: "DE"),
             Assignee(name: "Sam",    avatarColor: .teal,   initials: "SA")],
            [Assignee(name: "Raj",    avatarColor: .indigo, initials: "RA")],
            [Assignee(name: "Meera",  avatarColor: .pink,   initials: "ME"),
             Assignee(name: "Arun",   avatarColor: .cyan,   initials: "AR")],
            [Assignee(name: "Sneha",  avatarColor: .yellow, initials: "SN")],
            [Assignee(name: "Vikram", avatarColor: .mint,   initials: "VI"),
             Assignee(name: "Deepa",  avatarColor: .brown,  initials: "DE")],
        ]
        let priorities: [TaskPriority]   = [.high, .high, .medium, .medium, .medium, .low, .low]
        let categories: [TaskCategory]   = [.design, .engineering, .qa, .release, .infra]
        let symbols = [
            "paintbrush.pointed.fill", "exclamationmark.triangle.fill", "checkmark.seal.fill",
            "gauge.with.dots.needle.67percent", "globe", "paperplane.fill",
            "arrow.triangle.2.circlepath", "network", "moon.stars.fill",
            "figure.accessibility", "bell.badge.fill", "rectangle.stack.fill",
        ]
        let months = ["Oct", "Nov", "Dec"]
        let days   = Array(1...28)

        return (0..<100).map { i in
            let t   = titles[i % titles.count]
            let d   = descriptions[i % descriptions.count]
            let pri = priorities[i % priorities.count]
            let cat = categories[i % categories.count]
            let prg = Double(i % 11) / 10.0
            let tags = allTags[i % allTags.count]
            let asn  = allAssignees[i % allAssignees.count]
            let sym  = symbols[i % symbols.count]
            let date = "\(months[i % months.count]) \(days[i % days.count])"

            return Task(
                title: i < titles.count ? t : "\(t) #\(i + 1)",
                description: d,
                priority: pri,
                isCompleted: i % 5 == 2,
                dueDate: date,
                category: cat,
                progress: prg,
                tags: tags,
                assignees: asn,
                commentCount: i % 20,
                attachmentCount: i % 6,
                coverSymbol: sym,
                cardLayoutID: i % 3 == 2 ? "task_compact" : "task_card"
            )
        }
    }()
}
