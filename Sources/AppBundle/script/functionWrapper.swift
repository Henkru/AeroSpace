import Common

extension ScriptEngine {
    static func functionWrapper(
        _ state: OpaquePointer?,
        name: String,
        expectedArgs: [FunctionParameterType]?,
        body: (ScriptArguments) -> LuaFunctionResult
    ) -> Int32 {
        let args = ScriptArguments.fromState(state)

        if let expectedArgs,
           case .failure(let msg) = args.checkArguments(expected: expectedArgs)
        {
            args.ctx.yieldError("\(name): \(msg)")
        }

        let returnValue = body(args)

        switch returnValue {
            case .none:
                return 0
            case .single(let result):
                args.ctx.push(result)
                return 1
            case .many(let result):
                result.forEach { args.ctx.push($0) }
                return Int32(result.count)
            case .err(let msg):
                args.ctx.yieldError("\(name): \(msg.message)")
        }
    }
}
