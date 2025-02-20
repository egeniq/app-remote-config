import SwiftDiagnostics
import SwiftOperators
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum AppRemoteConfigValuesMacro: MemberMacro {
    
    public static func expansion<D: DeclGroupSyntax, C: MacroExpansionContext>(
        of node: AttributeSyntax,
        providingMembersOf declaration: D,
        in context: C
    ) throws -> [DeclSyntax] {
        guard let declaration = declaration.as(ClassDeclSyntax.self)
        else {
            context.diagnose(
                Diagnostic(
                    node: declaration,
                    message: MacroExpansionErrorMessage(
                        "'@AppRemoteConfigValues' can only be applied to class types"
                    )
                )
            )
            return []
        }
        var properties: [Property] = []
        var accesses: Set<Access> = Access(modifiers: declaration.modifiers).map { [$0] } ?? []
        for member in declaration.memberBlock.members {
            guard var property = member.decl.as(VariableDeclSyntax.self) else { continue }
            let propertyAccess = Access(modifiers: property.modifiers)
            guard
                var binding = property.bindings.first,
                let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            else { return [] }
            
            if property.bindingSpecifier.tokenKind == .keyword(.let), binding.initializer != nil {
                continue
            }
            if let accessors = binding.accessorBlock?.accessors {
                switch accessors {
                case .getter:
                    continue
                case let .accessors(accessors):
                    if accessors.contains(where: { $0.accessorSpecifier.tokenKind == .keyword(.get) }) {
                        continue
                    }
                }
            }
            
            if propertyAccess == .private, binding.initializer != nil { continue }
            accesses.insert(propertyAccess ?? .internal)
            
            guard let type = binding.typeAnnotation?.type ?? binding.initializer?.value.literalType
            else {
                context.diagnose(
                    Diagnostic(
                        node: binding,
                        message: MacroExpansionErrorMessage(
              """
              '@AppRemoteConfigValues' requires '\(identifier)' to have a type annotation in order to \
              generate a memberwise initializer
              """
                        ),
                        fixIt: FixIt(
                            message: MacroExpansionFixItMessage(
                """
                Insert ': <#Type#>'
                """
                            ),
                            changes: [
                                .replace(
                                    oldNode: Syntax(binding),
                                    newNode: Syntax(
                                        binding
                                            .with(\.pattern.trailingTrivia, "")
                                            .with(
                                                \.typeAnnotation,
                                                 TypeAnnotationSyntax(
                                                    colon: .colonToken(trailingTrivia: .space),
                                                    type: IdentifierTypeSyntax(name: "<#Type#>"),
                                                    trailingTrivia: .space
                                                 )
                                            )
                                    )
                                )
                            ]
                        )
                    )
                )
                return []
            }
            if var attributedTypeSyntax = type.as(AttributedTypeSyntax.self),
               attributedTypeSyntax.baseType.is(FunctionTypeSyntax.self)
            {
                attributedTypeSyntax.attributes.append(
                    .attribute("@escaping").with(\.trailingTrivia, .space)
                )
                binding.typeAnnotation?.type = TypeSyntax(attributedTypeSyntax)
            } else if let typeSyntax = type.as(FunctionTypeSyntax.self) {
                // TODO: Reenable
//                binding.typeAnnotation?.type = TypeSyntax(AttributedTypeSyntax(
//                    attributes: [.attribute("@escaping").with(\.trailingTrivia, .space)],
//                    baseType: typeSyntax
//                ))
            } else if binding.typeAnnotation == nil {
                binding.pattern.trailingTrivia = ""
                binding.typeAnnotation = TypeAnnotationSyntax(
                    colon: .colonToken(trailingTrivia: .space),
                    type: type.with(\.trailingTrivia, .space)
                )
            }
            if binding.initializer == nil, type.is(OptionalTypeSyntax.self) {
                binding.typeAnnotation?.trailingTrivia = .space
                binding.initializer = InitializerClauseSyntax(
                    equal: .equalToken(trailingTrivia: .space),
                    value: NilLiteralExprSyntax()
                )
            }
            property.bindings[property.bindings.startIndex] = binding
            
            let typeAnnotation = property.bindings.first?.typeAnnotation?.type
            let initializerValue = property.bindings.first?.initializer?.value
            let isLet = property.bindingSpecifier.tokenKind == .keyword(.let)
            properties.append(
                Property(declaration: property, identifier: identifier, typeAnnotation: typeAnnotation, initializerValue: initializerValue, isLet: isLet)
            )
        }
        let access = accesses.min().flatMap { $0.token?.with(\.trailingTrivia, .space) }
        
        return [properties].map {
            $0.isEmpty
            ? "\(access)init() {}"
            : """
            \(access)init(
            \(raw: $0.map { $0.declaration.bindings.trimmedDescription }.joined(separator: ",\n"))
            ) {
            \(raw: $0.map { "self.\($0.identifier) = \($0.identifier)" }.joined(separator: "\n"))
            }
            
            func apply(settings: [String: Any]) throws {
                var allKeys = Set(settings.keys)
                var incorrectKeys = Set<String>()
                var missingKeys = Set<String>()
            
            \(raw: $0.filter { $0.isLet == false }.map {
            """
                if let newValue = settings["\($0.identifier)"] as? \($0.typeAnnotation!) {
                    \($0.identifier) = newValue
                    allKeys.remove("\($0.identifier)")
                } else {
                    \($0.identifier) = \($0.initializerValue ?? "nil")
                    if allKeys.contains("\($0.identifier)") {
                        allKeys.remove("\($0.identifier)")
                        incorrectKeys.insert("\($0.identifier)")
                    } else {
                        missingKeys.insert("\($0.identifier)")
                    }
                }
            
            """}.joined(separator: "\n"))
                if !allKeys.isEmpty || !incorrectKeys.isEmpty || !missingKeys.isEmpty {
                    throw AppRemoteConfigServiceError.keysMismatch(unhandled: allKeys, incorrect: incorrectKeys, missing: missingKeys)
                }
            }
            """
        }
    }
}

private enum Access: Comparable {
    case `private`
    case `internal`
    case `public`
    
    init?(modifiers: DeclModifierListSyntax) {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.private):
                self = .private
                return
            case .keyword(.internal):
                self = .internal
                return
            case .keyword(.public):
                self = .public
                return
            default:
                continue
            }
        }
        return nil
    }
    
    var token: TokenSyntax? {
        switch self {
        case .private:
            return .keyword(.private)
        case .internal:
            return nil
        case .public:
            return .keyword(.public)
        }
    }
}

private struct Property {
    var declaration: VariableDeclSyntax
    var identifier: String
    var typeAnnotation: TypeSyntax?
    var initializerValue: ExprSyntax?
    var isLet: Bool
}

extension ExprSyntax {
    fileprivate var literalType: TypeSyntax? {
        if self.is(BooleanLiteralExprSyntax.self) {
            return "Swift.Bool"
        } else if self.is(FloatLiteralExprSyntax.self) {
            return "Swift.Double"
        } else if self.is(IntegerLiteralExprSyntax.self) {
            return "Swift.Int"
        } else if self.is(StringLiteralExprSyntax.self) {
            return "Swift.String"
        } else {
            return nil
        }
    }
}

extension SyntaxStringInterpolation {
    mutating func appendInterpolation<Node: SyntaxProtocol>(_ node: Node?) {
        if let node {
            self.appendInterpolation(node)
        }
    }
}
