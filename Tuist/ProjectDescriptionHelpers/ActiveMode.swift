import ProjectDescription

public enum TemplateMode: String, CaseIterable {
    case enterprise
    case lean
    case plugin
}

public let activeMode: TemplateMode = .enterprise
