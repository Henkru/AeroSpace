import Common

extension ScriptEngine {
    func createApi() -> LuaTable {
        let api = LuaTable.empty(ctx: ctx)

        /* Executes aero command
         * @param command string
         * @param arg...  string
         *
         * @return table {
         *              stdout: string
         *              stderr: string
         *              exitCode: number
         *          }
         *
         * Example:
         * aero.api.command("move-node-to-workspace", "S")
         * aero.api.command("list-windows", "--all", "--count")
         */
        api["command"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "command",
                    expectedArgs: [
                        .string,
                        .variadic(.string),
                    ]
                ) { args in
                    let allArgs = args.collect().compactMap { $0.asString()! }
                    let (command, _, err) = parseCommand(allArgs).unwrap()

                    if let command {
                        let cmdResult = command.run(.defaultEnv, .emptyStdin)
                        let result = LuaTable.empty(ctx: args.ctx)
                        result["stdout"] = cmdResult.stdout.joined(separator: "\n").asLuaValue
                        result["stderr"] = cmdResult.stderr.joined(separator: "\n").asLuaValue
                        result["exitCode"] = cmdResult.exitCode.asLuaValue
                        return .single(.table(result))
                    } else if let err {
                        let result = LuaTable.empty(ctx: args.ctx)
                        result["stdout"] = err.asLuaValue
                        result["exitCode"] = (-1).asLuaValue
                        return .single(.table(result))
                    }

                    return .single(.nil)
                }
            }.asLuaValue

        /* Activate the specified binding mode
         * @param mode string
         *
         * Example:
         * aero.api.activate_mode("main")
         */
        api["activate_mode"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "activate_mode",
                    expectedArgs: [.string]
                ) { args in
                    activateMode(args.at(1).asString())
                    return .none
                }
            }.asLuaValue

        /* Query window's title
         * @param windowId number
         *
         * @return string
         *
         * Example:
         * aero.api.window_get_title(123)
         */
        api["window_get_title"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.api.window_get_title",
                    expectedArgs: [.number]
                ) { args in
                    let windowId = args.at(1).asInteger()!
                    guard let window = Window.get(byId: UInt32(windowId)) else {
                        return .single(.nil)
                    }
                    return .single(.string(window.title))
                }
            }.asLuaValue

        /* Query window's app name
         * @param windowId number
         *
         * @return string
         *
         * Example:
         * aero.api.window_get_app_name(123)
         */
        api["window_get_app_name"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.api.window_get_app_name",
                    expectedArgs: [.number]
                ) { args in
                    let windowId = UInt32(args.at(1).asInteger()!)
                    if let window = Window.get(byId: windowId),
                       let name = window.app.asMacApp().name
                    {
                        return .single(.string(name))
                    }
                    return .single(.nil)
                }
            }.asLuaValue

        /* Query the number of windows on specific workspace
         * @param workspace string
         *
         * @return number
         *
         * The special 'focused' workspane name can be used to query
         * from the currently focused workspace
         *
         * Example:
         * aero.api.workspace_windows_count("main")
         * aero.api.workspace_windows_count("focused")
         */
        api["workspace_windows_count"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.api.workspace_windows_count",
                    expectedArgs: [.string]
                ) { args in
                    let workspaceName = args.at(1).asString()!
                    let workspace =
                        workspaceName == "focused"
                            ? focus.workspace : Workspace.get(byName: workspaceName)
                    return .single(workspace.allLeafWindowsRecursive.count.asLuaValue)
                }
            }.asLuaValue

        ctx.setGlobal(key: "GAP_INNER_HORIZONTAL", value: GapPosition.gapInnerHorizontal)
        ctx.setGlobal(key: "GAP_INNER_VERTICAL", value: GapPosition.gapInnerVertical)
        ctx.setGlobal(key: "GAP_OUTER_LEFT", value: GapPosition.gapOuterLeft)
        ctx.setGlobal(key: "GAP_OUTER_BOTTOM", value: GapPosition.gapOuterBottom)
        ctx.setGlobal(key: "GAP_OUTER_TOP", value: GapPosition.gapOuterTop)
        ctx.setGlobal(key: "GAP_OUTER_RIGHT", value: GapPosition.gapOuterRight)
        /* Set the gap value
         * @param location number
         * @param value    number | function(location, monitorInfo)
         *
         * Possible values for the location:
         *   - GAP_INNER_HORIZONTAL
         *   - GAP_INNER_VERTICAL
         *   - GAP_OUTER_LEFT
         *   - GAP_OUTER_BOTTOM
         *   - GAP_OUTER_TOP
         *   - GAP_OUTER_RIGHT
         *
         * If a Lua function as provided as a value, then
         * it is called everytime the gap value is accecssed,
         * and the function must return the desired gap as number.
         * The gap callback function is called with the location number
         * and the monitor info table: {
         *   id: string
         *   name: string
         *   width: number
         *   height: number
         *   activeWorkspace: string
         * }
         *
         * Example:
         * aero.api.gap_set(GAP_OUTER_TOP, 10)
         * aero.api.gap_set(
            GAP_OUTER_LEFT,
            function(id, info)
                if info.name == "Dell U4919DW" and
                    aero.api.workspace_windows_count(monitor.activeWorkspace) = 1
                then
                    return 1280
                else
                    return 10
                end
            end
           )
         */
        api["gap_set"] =
            ctx.createFunction { state in
                return ScriptEngine.functionWrapper(
                    state,
                    name: "aero.api.gap_set",
                    expectedArgs: [
                        .number,
                        .multi([.number, .function]),
                    ]
                ) { args in
                    let gapId = args.at(1)

                    let gap: DynamicConfigValue<Int>
                    switch args.at(2) {
                        case .number(let value):
                            gap = .constant(Int(value))
                        case .function(let callback):
                            gap = .dynamic(callback, gapId)
                        default:
                            error("unreachable")
                    }

                    switch GapPosition(rawValue: gapId.asInteger()!) {
                        case .gapInnerHorizontal:
                            config.gaps.inner.horizontal = gap
                        case .gapInnerVertical:
                            config.gaps.inner.vertical = gap
                        case .gapOuterLeft:
                            config.gaps.outer.left = gap
                        case .gapOuterBottom:
                            config.gaps.outer.bottom = gap
                        case .gapOuterTop:
                            config.gaps.outer.top = gap
                        case .gapOuterRight:
                            config.gaps.outer.right = gap
                        default:
                            args.ctx.yieldError("Invalid gap position value")
                    }

                    return .none
                }
            }.asLuaValue

        return api
    }
}

private enum GapPosition: Int {
    case gapInnerHorizontal = 1
    case gapInnerVertical
    case gapOuterLeft
    case gapOuterBottom
    case gapOuterTop
    case gapOuterRight
}

extension GapPosition: IntoLuaValue {
    var asLuaValue: LuaValue {
        return self.rawValue.asLuaValue
    }
}
