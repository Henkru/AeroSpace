import Common
import TOMLKit

struct PerMonitorValue<Value: Equatable>: Equatable {
    let description: MonitorDescription
    let value: Value
}

enum DynamicConfigValue<Value: Equatable>: Equatable {
    case constant(Value)
    case perMonitor([PerMonitorValue<Value>], default: Value)
    case dynamic(LuaFunction, LuaValue)
}

extension DynamicConfigValue {
    func getValue(for monitor: any Monitor) -> Value {
        switch self {
            case .constant(let value):
                return value
            case .perMonitor(let array, let defaultValue):
                let sortedMonitors = sortedMonitors
                return array
                    .lazy
                    .compactMap {
                        $0.description.resolveMonitor(sortedMonitors: sortedMonitors)?.rect.topLeftCorner == monitor.rect.topLeftCorner
                            ? $0.value
                            : nil
                    }
                    .first ?? defaultValue
            case .dynamic(let function, let id):
                let monitorInfo = LuaTable.empty(ctx: function.ctx)
                monitorInfo["id"] = LuaValue.fromInt(monitor.monitorId)
                monitorInfo["name"] = LuaValue.fromString(monitor.name)
                monitorInfo["width"] = .number(monitor.width)
                monitorInfo["height"] = .number(monitor.height)
                monitorInfo["activeWorkspace"] = LuaValue.fromString(monitor.activeWorkspace.id)

                switch function.call(args: [id, .table(monitorInfo)]) {
                    case .none:
                        error("Lua callback did not return a value")
                    case .single(let result):
                        guard let value = castLuaValue(result) else {
                            error("Could not cast the return value of Lua callback to dynamic config value")
                        }
                        return value
                    case .many(let result):
                        guard let value = result.first,
                              let value = castLuaValue(value)
                        else {
                            error("Could not cast the return value of Lua callback to dynamic config value")
                        }
                        return value
                    case .err(let err):
                        error("Failed to call the Lua callback for dynamic config value: \(err.message)")
                }
        }
    }

    private func castLuaValue(_ luaValue: LuaValue) -> Value? {
        if Value.self == String.self, let value = luaValue.asString() as? Value {
            return value
        } else if Value.self == Int.self, let value = luaValue.asInteger() as? Value {
            return value
        } else if Value.self == Bool.self, let value = luaValue.asBool() as? Value {
            return value
        } else {
            return nil
        }
    }
}

func parseDynamicValue<T>(
    _ raw: TOMLValueConvertible,
    _ valueType: T.Type,
    _ fallback: T,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError]
) -> DynamicConfigValue<T> {
    if let simpleValue = parseSimpleType(raw) as T? {
        return .constant(simpleValue)
    } else if let array = raw.array {
        if array.isEmpty {
            errors.append(.semantic(backtrace, "The array must not be empty"))
            return .constant(fallback)
        }

        guard let defaultValue = array.last.flatMap({ parseSimpleType($0) as T? }) else {
            errors.append(.semantic(backtrace, "The last item in the array must be of type \(T.self)"))
            return .constant(fallback)
        }

        if array.dropLast().isEmpty {
            errors.append(.semantic(backtrace, "The array must contain at least one monitor pattern"))
            return .constant(fallback)
        }

        let rules: [PerMonitorValue<T>] = parsePerMonitorValues(TOMLArray(array.dropLast()), backtrace, &errors)

        return .perMonitor(rules, default: defaultValue)
    } else {
        errors.append(.semantic(backtrace, "Unsupported type: \(raw.type), expected: \(valueType) or array"))
        return .constant(fallback)
    }
}

func parsePerMonitorValues<T>(_ array: TOMLArray, _ backtrace: TomlBacktrace, _ errors: inout [TomlParseError]) -> [PerMonitorValue<T>] {
    array.enumerated().compactMap { (index: Int, raw: TOMLValueConvertible) -> PerMonitorValue<T>? in
        var backtrace = backtrace + .index(index)

        guard let (key, value) = raw.unwrapTableWithSingleKey(expectedKey: "monitor", &backtrace)
            .flatMap({ $0.value.unwrapTableWithSingleKey(expectedKey: nil, &backtrace) })
            .getOrNil(appendErrorTo: &errors)
        else {
            return nil
        }

        let monitorDescriptionResult = parseMonitorDescription(key, backtrace)

        guard let monitorDescription = monitorDescriptionResult.getOrNil(appendErrorTo: &errors) else { return nil }

        guard let value = parseSimpleType(value) as T? else {
            errors.append(.semantic(backtrace, "Expected type is '\(T.self)'. But actual type is '\(value.type)'"))
            return nil
        }

        return PerMonitorValue(description: monitorDescription, value: value)
    }
}
