enum FunctionParameterType {
    case fixed(Parameter)
    case variadic(Parameter)
}

enum Parameter {
    case specific(ParameterType)
    case multi([ParameterType])
    case any
}

enum ParameterType {
    case type(LuaValueType)
    case schema(TableSchema)
}

struct TableSchema {
    let fields: [String: Parameter]
}

extension ScriptArguments {
    func checkArguments(expected: [FunctionParameterType]) -> Result<Void, String> {
        var argumentIndex = 1

        for (expectedIndex, expectedType) in expected.enumerated() {
            guard argumentIndex <= self.count else {
                if case .variadic = expectedType {
                    return .success(())
                }
                return .failure(
                    "Expected \(expectedType.describe()) at argument \(expectedIndex + 1), but only \(self.count) arguments were provided."
                )
            }

            switch expectedType {
                case .fixed(let type):
                    let result = checkArgument(at: argumentIndex, against: type)
                    if case .failure(let error) = result {
                        return .failure("At argument \(argumentIndex): \(error)")
                    }
                    argumentIndex += 1
                case .variadic(let type):
                    while argumentIndex <= self.count {
                        let result = checkArgument(at: argumentIndex, against: type)
                        if case .failure(let error) = result {
                            if expectedIndex + 1 == expected.count {
                                return .failure("At argument \(argumentIndex): \(error)")
                            } else {
                                break
                            }
                        }
                        argumentIndex += 1
                    }
            }
        }

        if (argumentIndex - 1) != self.count {
            return .failure(
                "Expected no more arguments, but received extra arguments starting at \(argumentIndex + 1)."
            )
        }

        return .success(())
    }

    private func checkArgument(at index: Int, against: Parameter) -> Result<Void, String> {
        switch against {
            case .specific(let type):
                return checkArgument(at: index, against: type)
            case .multi(let types):
                let isValid = types.contains(where: {
                    if case .success = checkArgument(at: index, against: $0) {
                        return true
                    } else {
                        return false
                    }
                })
                if isValid {
                    return .success(())
                } else {
                    let type = self.kind(at: index)
                    return .failure("Expected \(against.describe()), but got \(type.describe())")
                }
            case .any:
                return .success(())
        }
    }

    private func checkArgument(at index: Int, against: ParameterType) -> Result<Void, String> {
        switch against {
            case .type(let luaType):
                let type = self.kind(at: index)
                if type != luaType {
                    return .failure("Expected \(luaType.describe()), but got \(type.describe())")
                }
                return .success(())
            case .schema(let schema):
                let value = self.ctx.from(at: index)
                guard case .table(let table) = value else {
                    return .failure("Expected a table, but got \(value.describe())")
                }

                return checkArgument(table: table, against: schema)
        }
    }

    private func checkArgument(table: LuaTable, against schema: TableSchema, _ nested: Int = 0)
        -> Result<Void, String>
    {
        for (key, expectedType) in schema.fields {
            let result = checkArgument(table: table, field: key, against: expectedType, nested)
            if case .failure(let err) = result {
                if nested == 0 {
                    return .failure("\(err). Required schema for the table: \(schema.describe())")
                } else {
                    return .failure(err)
                }
            }
        }
        return .success(())
    }

    private func checkArgument(table: LuaTable, field: String, against: Parameter, _ nested: Int)
        -> Result<Void, String>
    {
        switch against {
            case .specific(let type):
                return checkArgument(table: table, field: field, against: type, nested)
            case .multi(let types):
                let isValid = types.contains(where: {
                    if case .success = checkArgument(
                        table: table, field: field, against: $0, nested)
                    {
                        return true
                    } else {
                        return false
                    }
                })
                if isValid {
                    return .success(())
                } else {
                    let value = table[field]
                    return .failure("Expected \(against.describe()), but got \(value.describe())")
                }
            case .any:
                return .success(())
        }
    }

    private func checkArgument(
        table: LuaTable, field: String, against: ParameterType, _ nested: Int
    )
        -> Result<
            Void, String
        >
    {
        switch against {
            case .type(let luaType):
                let type = table.fieldType(field)
                if type != luaType {
                    return .failure(
                        "Expected \(luaType.describe()) for field '\(field)', but got \(type.describe())"
                    )
                }
                return .success(())
            case .schema(let schema):
                let value = table[field]
                guard case .table(let innerTable) = value else {
                    return .failure(
                        "Expected a table for field '\(field)', but got \(value.describe())")
                }

                return checkArgument(table: innerTable, against: schema, nested + 1)
        }
    }
}

extension ParameterType {
    static var number: ParameterType {
        return .type(.number)
    }
    static var string: ParameterType {
        return .type(.string)
    }
    static var boolean: ParameterType {
        return .type(.boolean)
    }
    static var `nil`: ParameterType {
        return .type(.nil)
    }
    static var function: ParameterType {
        return .type(.function)
    }
    static var table: ParameterType {
        return .type(.table)
    }
}

extension Parameter {
    static var number: Parameter {
        return .specific(.type(.number))
    }
    static var string: Parameter {
        return .specific(.type(.string))
    }
    static var boolean: Parameter {
        return .specific(.type(.boolean))
    }
    static var `nil`: Parameter {
        return .specific(.type(.nil))
    }
    static var function: Parameter {
        return .specific(.type(.function))
    }
    static var table: Parameter {
        return .specific(.type(.table))
    }
    static func schema(_ fields: [String: Parameter]) -> Parameter {
        return .specific(.schema(TableSchema(fields: fields)))
    }
    static func optional(_ parameter: ParameterType) -> Parameter {
        return .multi([.nil, parameter])
    }
}

extension FunctionParameterType {
    static var number: FunctionParameterType {
        return .fixed(.number)
    }
    static var string: FunctionParameterType {
        return .fixed(.string)
    }
    static var boolean: FunctionParameterType {
        return .fixed(.boolean)
    }
    static var `nil`: FunctionParameterType {
        return .fixed(.nil)
    }
    static var function: FunctionParameterType {
        return .fixed(.function)
    }
    static var table: FunctionParameterType {
        return .fixed(.table)
    }
    static func multi(_ types: [ParameterType]) -> FunctionParameterType {
        return .fixed(.multi(types))
    }
    static func schema(_ fields: [String: Parameter]) -> FunctionParameterType {
        return .fixed(.specific(.schema(TableSchema(fields: fields))))
    }
}

extension ParameterType {
    func describe() -> String {
        switch self {
            case .type(let luaType):
                return luaType.describe()
            case .schema(let tableSchema):
                return tableSchema.describe()
        }
    }
}

extension Parameter {
    func describe() -> String {
        switch self {
            case .specific(let type):
                return type.describe()
            case .multi(let types):
                return types.map { $0.describe() }.joined(separator: ", or ")
            case .any:
                return "any"
        }
    }
}

extension TableSchema {
    func describe() -> String {
        let elements = fields.map { "\($0): \($1.describe())" }.joined(separator: ", ")
        return "{ \(elements) }"
    }
}

extension FunctionParameterType {
    func describe() -> String {
        switch self {
            case .fixed(let parameter):
                return parameter.describe()
            case .variadic(let parameter):
                return "variadic(\(parameter.describe()))"
        }
    }
}
