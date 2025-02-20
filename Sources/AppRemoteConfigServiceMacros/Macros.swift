@attached(member, names: named(init), named(apply(settings:)))
public macro AppRemoteConfigValues() =
#externalMacro(
    module: "AppRemoteConfigServiceMacrosPlugin", type: "AppRemoteConfigValuesMacro"
)
