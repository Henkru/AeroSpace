import CLua
import Common

enum LuaValueType {
    case number
    case string
    case boolean
    case `nil`
    case table
    case function
}

extension LuaContext {
    func luaType(at: Int32) -> LuaValueType {
        switch lua_type(state, at) {
            case LUA_TNUMBER:
                return .number
            case LUA_TSTRING:
                return .string
            case LUA_TBOOLEAN:
                return .boolean
            case LUA_TTABLE:
                return .table
            case LUA_TFUNCTION:
                return .function
            case LUA_TNIL:
                return .nil
            case LUA_TUSERDATA:
                error("TODO: LUA_TUSERDATA not implemented")
            case LUA_TTHREAD:
                error("TODO: LUA_TTHREAD not implemented")
            case LUA_TLIGHTUSERDATA:
                error("TODO: LUA_TLIGHTUSERDATA not implemented")
            default:
                return .nil
        }
    }

    func luaType(at: Int) -> LuaValueType {
        return luaType(at: Int32(at))
    }
}

enum LuaValue: Hashable, IntoLuaValue {
    case number(lua_Number)
    case string(String)
    case boolean(Bool)
    case `nil`
    case table(LuaTable)
    case function(LuaFunction)

    var asLuaValue: LuaValue {
        return self
    }
}

protocol IntoLuaValue {
    var asLuaValue: LuaValue { get }
}

extension LuaContext {
    func push(_ value: LuaValue) {
        switch value {
            case .number(let value):
                lua_pushnumber(state, value)
            case .string(let value):
                lua_pushstring(state, value)
            case .boolean(let value):
                lua_pushboolean(state, value ? 1 : 0)
            case .nil:
                lua_pushnil(state)
            case .table(let table):
                lua_rawgeti(state, LUA_REGISTRYINDEX, table.ref)
            case .function(let f):
                lua_rawgeti(state, LUA_REGISTRYINDEX, f.ref)
        }
    }

    func from(at: Int32 = -1) -> LuaValue {
        switch luaType(at: at) {
            case .number:
                return .number(lua_tonumber(state, at))
            case .string:
                return .string(String(cString: lua_tolstring(state, at, nil)))
            case .boolean:
                return .boolean(lua_toboolean(state, at) != 0)
            case .table:
                return .table(LuaTable(ctx: self, at: at))
            case .function:
                return .function(LuaFunction(ctx: self, at: at))
            case .nil:
                return .nil
        }
    }

    func from(at: Int) -> LuaValue {
        return from(at: Int32(at))
    }
}

extension LuaValue {
    func asInteger() -> Int? {
        guard case .number(let n) = self else {
            return nil
        }
        return Int(n)
    }

    func asDouble() -> Double? {
        guard case .number(let n) = self else {
            return nil
        }
        return Double(n)
    }

    func asString() -> String? {
        guard case .string(let str) = self else {
            return nil
        }
        return str
    }

    func asBool() -> Bool? {
        guard case .boolean(let b) = self else {
            return nil
        }
        return b
    }

    func asFunction() -> LuaFunction? {
        guard case .function(let f) = self else {
            return nil
        }
        return f
    }

    func asTable() -> LuaTable? {
        guard case .table(let table) = self else {
            return nil
        }
        return table
    }

    static func fromInt(_ n: Int?) -> LuaValue {
        return n.map { $0.asLuaValue } ?? .nil
    }

    static func fromString(_ str: String?) -> LuaValue {
        return str.map { $0.asLuaValue } ?? .nil
    }

    static func fromBool(_ b: Bool?) -> LuaValue {
        return b.map { $0.asLuaValue } ?? .nil
    }
}

extension LuaValueType {
    func describe() -> String {
        switch self {
            case .number:
                return "number"
            case .string:
                return "string"
            case .boolean:
                return "boolean"
            case .nil:
                return "nil"
            case .table:
                return "table"
            case .function:
                return "function"
        }
    }
}

extension LuaValue {
    func describe() -> String {
        switch self {
            case .number:
                return "number"
            case .string:
                return "string"
            case .boolean:
                return "boolean"
            case .nil:
                return "nil"
            case .table:
                return "table"
            case .function:
                return "function"
        }
    }
}

extension Int: IntoLuaValue {
    var asLuaValue: LuaValue {
        return .number(Double(self))
    }
}

extension UInt32: IntoLuaValue {
    var asLuaValue: LuaValue {
        return .number(Double(self))
    }
}

extension Int32: IntoLuaValue {
    var asLuaValue: LuaValue {
        return .number(Double(self))
    }
}

extension String: IntoLuaValue {
    var asLuaValue: LuaValue {
        return .string(self)
    }
}

extension Bool: IntoLuaValue {
    var asLuaValue: LuaValue {
        return .boolean(self)
    }
}

protocol FromLuaValue {
    init?(luaValue: LuaValue)
}

extension Int: FromLuaValue {
    init?(luaValue: LuaValue) {
        guard let value = luaValue.asInteger() else {
            return nil
        }
        self = value
    }
}

extension String: FromLuaValue {
    init?(luaValue: LuaValue) {
        guard let value = luaValue.asString() else {
            return nil
        }
        self = value
    }
}

extension Bool: FromLuaValue {
    init?(luaValue: LuaValue) {
        guard let value = luaValue.asBool() else {
            return nil
        }
        self = value
    }
}

extension LuaValue {
    func asType<T>(_ type: T.Type) -> T? {
        switch T.self {
            case is Bool.Type:
                return self.asBool() as? T
            case is Int.Type:
                return self.asInteger() as? T
            case is String.Type:
                return self.asString() as? T
            default:
                return nil
        }
    }
}
