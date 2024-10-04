import Common

extension ScriptEngine {
    func createCallbacksApi() -> LuaTable {
        let callbacks = LuaTable.empty(ctx: ctx)

        /* Adds 'on-focus-changed' callbacks
         * @param command...  string | function(env)
         *
         * If the command is a Lua function, it's called with the
         * table represents the CmdEnv struct: {
         *   windowID: string,
         *   workspaceName:
         *   string, pwd: string
         * }
         *
         * Example:
         * aero.callbacks.on_focus_changed("move-mouse window-lazy-center", "...")
         * aero.callbacks.on_focus_changed(function() print("on-focus-changed triggered") end)
         */
        callbacks["on_focus_changed"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.callbacks.on_focus_changed",
                    expectedArgs: [
                        .multi([.string, .function]),
                        .variadic(.multi([.string, .function])),
                    ]
                ) { args in
                    let commands = (1 ... args.count).compactMap {
                        switch ScriptEngine.argToCommand(args.at($0)) {
                            case .success(let command):
                                return command
                            case .failure(let err):
                                args.ctx.yieldError(err)
                        }
                    }

                    config.onFocusChanged.append(contentsOf: commands)
                    return .single(.boolean(true))
                }
            }.asLuaValue

        /* Adds 'on-focused-monitor-changed' callbacks
         * @param command...  string | function(env)
         *
         * If the command is a Lua function, it's called with the
         * table represents the CmdEnv struct: {
         *   windowID: string,
         *   workspaceName:
         *   string, pwd: string
         * }
         *
         * Example:
         * aero.callbacks.on_focused_monitor_changed("move-mouse monitor-lazy-center", "...")
         * aero.callbacks.on_focused_changed(function() print("on-focus-changed triggered") end)
         */
        callbacks["on_focused_monitor_changed"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.callbacks.on_focused_monitor_changed",
                    expectedArgs: [
                        .multi([.string, .function]),
                        .variadic(.multi([.string, .function])),
                    ]
                ) { args in
                    let commands = (1 ... args.count).compactMap {
                        switch ScriptEngine.argToCommand(args.at($0)) {
                            case .success(let command):
                                return command
                            case .failure(let err):
                                args.ctx.yieldError(err)
                        }
                    }

                    config.onFocusedMonitorChanged.append(contentsOf: commands)
                    return .single(.boolean(true))
                }
            }.asLuaValue

        /* Adds 'on-focused-monitor-changed' callbacks
         * @param opts       table {
         *                      appId: string|nil,
         *                      appNameRegexSubstring: string|nil,
         *                      windowTitleRegexSubstring: string|nil,
         *                      workspace: string|nil,
         *                      duringAeroSpaceStartup: boolean|nil,
         *                      checkFurtherCallbacks: boolean|nil
         *                    }
         * @param command...  string | function(env)
         *
         * If the command is a Lua function, it's called with the
         * table represents the CmdEnv struct: {
         *   windowID: string|nil,
         *   workspaceName: string|nil
         *   string, pwd: string|nil
         * }
         *
         * Example:
         * aero.callbacks.on_window_detected(
         *  {appId: "com.apple.systempreferences"},
         *  "layout floating",
         *  "move-node-to-workspace S"
         * )
         */
        callbacks["on_window_detected"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.callbacks.on_window_detected",
                    expectedArgs: [
                        .schema([
                            "appId": .optional(.string),
                            "appNameRegexSubstring": .optional(.string),
                            "windowTitleRegexSubstring": .optional(.string),
                            "workspace": .optional(.string),
                            "duringAerospaceStartup": .optional(.boolean),
                            "checkFurtherCallbacks": .optional(.boolean),
                        ]),
                        .multi([.string, .function]),
                        .variadic(.multi([.string, .function])),
                    ]
                ) { args in
                    let opts = args.at(1).asTable()!
                    let commands = (2 ... args.count).compactMap {
                        switch ScriptEngine.argToCommand(args.at($0)) {
                            case .success(let command):
                                return command
                            case .failure(let err):
                                args.ctx.yieldError(err)
                        }
                    }

                    let matcher = WindowDetectedCallbackMatcher(
                        appId: opts["appId"].asString(),
                        appNameRegexSubstring:
                        opts["appNameRegexSubstring"].asString().flatMap {
                            try? Regex($0)
                        }.map { $0.ignoresCase() },  //TODO: Report error on Regex parse failure
                        windowTitleRegexSubstring:
                        opts["windowTitleRegexSubstring"].asString().flatMap {
                            try? Regex($0)
                        }.map { $0.ignoresCase() },  //TODO: Report error on Regex parse failure
                        workspace: opts["workspace"].asString(),
                        duringAeroSpaceStartup: opts["duringAerospaceStartup"].asBool()
                    )

                    let callback = WindowDetectedCallback(
                        matcher: matcher,
                        checkFurtherCallbacks: opts["checkFurtherCallbacks"].asBool() ?? false,
                        rawRun: commands)

                    config.onWindowDetected.append(callback)
                    return .single(.boolean(true))
                }
            }.asLuaValue
        return callbacks
    }
}
