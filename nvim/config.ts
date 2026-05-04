import {
    BaseConfig,
    ContextBuilder,
    Dpp,
    Plugin,
} from "https://deno.land/x/dpp_vim@v1.0.0/types.ts";
import { Denops, fn } from "https://deno.land/x/dpp_vim@v1.0.0/deps.ts";

type Toml = {
    hooks_file?: string;
    ftplugins?: Record<string, string>;
    plugins?: Plugin[];
};

type LazyMakeStateResult = {
    plugins: Plugin[];
    stateLines: string[];
};

export class Config extends BaseConfig {
    override async config(args: {
        denops: Denops;
        contextBuilder: ContextBuilder;
        basePath: string;
        dpp: Dpp;
    }): Promise<{
        plugins: Plugin[];
        stateLines: string[];
    }> {
        args.contextBuilder.setGlobal({
            protocols: ["git"],
        });

        const [context, options] = await args.contextBuilder.get(args.denops);
        const dotfilesDir = "~/.config/nvim/toml/";

        // use toml
        const tomls: Toml[] = [];
        const toml = (await args.dpp.extAction(
            args.denops,
            context,
            options,
            "toml",
            "load",
            {
                path: await fn.expand(args.denops, dotfilesDir + "/dein.toml"),
                options: {
                    lazy: false,
                },
            }
        )) as Toml | undefined;
        if (toml) {
            tomls.push(toml);
        }

        const lazyToml = (await args.dpp.extAction(
            args.denops,
            context,
            options,
            "toml",
            "load",
            {
                path: await fn.expand(
                    args.denops,
                    dotfilesDir + "/dein_lazy.toml"
                ),
                options: {
                    lazy: true,
                },
            }
        )) as Toml | undefined;
        if (lazyToml) {
            tomls.push(lazyToml);
        }

        const recordPlugins: Record<string, Plugin> = {};
        const ftplugins: Record<string, string> = {};
        const hooksFiles: string[] = [];

        tomls.forEach((toml) => {
            for (const plugin of toml.plugins) {
                recordPlugins[plugin.name] = plugin;
            }

            if (toml.ftplugins) {
                for (const filetype of Object.keys(toml.ftplugins)) {
                    if (ftplugins[filetype]) {
                        ftplugins[filetype] += `\n${toml.ftplugins[filetype]}`;
                    } else {
                        ftplugins[filetype] = toml.ftplugins[filetype];
                    }
                }
            }

            if (toml.hooks_file) {
                hooksFiles.push(toml.hooks_file);
            }
        });

        // use local
        const localPlugins = (await args.dpp.extAction(
            args.denops,
            context,
            options,
            "local",
            "local",
            {
                directory: "~/work",
                options: {
                    frozen: true,
                    merged: false,
                },
            }
        )) as Plugin[] | undefined;

        if (localPlugins) {
            // Merge localPlugins
            for (const plugin of localPlugins) {
                if (plugin.name in recordPlugins) {
                    recordPlugins[plugin.name] = Object.assign(
                        recordPlugins[plugin.name],
                        plugin
                    );
                } else {
                    recordPlugins[plugin.name] = plugin;
                }
            }
        }

        // use lazy
        const lazyResult = (await args.dpp.extAction(
            args.denops,
            context,
            options,
            "lazy",
            "makeState",
            {
                plugins: Object.values(recordPlugins),
            }
        )) as LazyMakeStateResult | undefined;

        return {
            ftplugins,
            hooksFiles,
            plugins: lazyResult?.plugins ?? [],
            stateLines: lazyResult?.stateLines ?? [],
        };
    }
}
/*
import {
    type ContextBuilder,
    type Plugin,
} from "jsr:@shougo/dpp-vim@~3.1.0/types";
import {
    BaseConfig,
    type ConfigReturn,
    type MultipleHook,
} from "jsr:@shougo/dpp-vim@~3.1.0/config";
import type {
    Ext as TomlExt,
    Params as TomlParams,
} from "jsr:@shougo/dpp-ext-toml@~1.3.0";
import type {
    Ext as LazyExt,
    LazyMakeStateResult,
    Params as LazyParams,
} from "jsr:@shougo/dpp-ext-lazy@~1.5.0";
import type {
    Ext as LocalExt,
    Params as LocalParams,
} from "jsr:@shougo/dpp-ext-local@~1.3.0";

import type { Denops } from "jsr:@denops/std@~7.3.0";
import * as fn from "jsr:@denops/std@~7.3.0/function";

type Toml = {
    hooks_file?: string;
    ftplugins?: Record<string, string>;
    plugins: Plugin[];
};

type LazyMakeStateResult = {
    plugins: Plugin[];
    stateLines: string[];
};

export class Config extends BaseConfig {
    override async config(args: {
        denops: Denops;
        contextBuilder: ContextBuilder;
        basePath: string;
    }): Promise<ConfigReturn> {
        args.contextBuilder.setGlobal({
            protocols: ["git"],
        });

        const [context, options] = await args.contextBuilder.get(args.denops);

        const recordPlugins: Record<string, Plugin> = {};
        const ftplugins: Record<string, string> = {};
        const hooksFiles: string[] = [];
        let multipleHooks: MultipleHook[] = [];

        // Load toml plugins
        const [tomlExt, tomlOptions, tomlParams]: [
            TomlExt | undefined,
            ExtOptions,
            TomlParams,
        ] = (await args.denops.dispatcher.getExt("toml")) as [
            TomlExt | undefined,
            ExtOptions,
            TomlParams,
        ];
        if (tomlExt) {
            const action = tomlExt.actions.load;
            const BASE_DIR = "~/.config/nvim/toml";

            const tomlPromises = [
                //{ path: "$BASE_DIR/dpp.toml", lazy: false },
                { path: `${BASE_DIR}/dein.toml`, lazy: false },
            ].map((tomlFile) =>
                action.callback({
                    denops: args.denops,
                    context,
                    options,
                    protocols,
                    extOptions: tomlOptions,
                    extParams: tomlParams,
                    actionParams: {
                        path: tomlFile.path,
                        options: {
                            lazy: tomlFile.lazy,
                        },
                    },
                })
            );

            const tomls = await Promise.all(tomlPromises);

            // Merge toml results
            for (const toml of tomls) {
                for (const plugin of toml.plugins ?? []) {
                    recordPlugins[plugin.name] = plugin;
                }

                if (toml.ftplugins) {
                    mergeFtplugins(ftplugins, toml.ftplugins);
                }

                if (toml.multiple_hooks) {
                    multipleHooks = multipleHooks.concat(toml.multiple_hooks);
                }

                if (toml.hooks_file) {
                    hooksFiles.push(toml.hooks_file);
                }
            }
        }

        const [localExt, localOptions, localParams]: [
            LocalExt | undefined,
            ExtOptions,
            LocalParams,
        ] = (await args.denops.dispatcher.getExt("local")) as [
            LocalExt | undefined,
            ExtOptions,
            LocalParams,
        ];
        if (localExt) {
            const action = localExt.actions.local;

            const localPlugins = await action.callback({
                denops: args.denops,
                context,
                options,
                protocols,
                extOptions: localOptions,
                extParams: localParams,
                actionParams: {
                    directory: "~/work",
                    options: {
                        frozen: true,
                        merged: false,
                    },
                },
            });

            for (const plugin of localPlugins) {
                if (plugin.name in recordPlugins) {
                    recordPlugins[plugin.name] = Object.assign(
                        recordPlugins[plugin.name],
                        plugin
                    );
                } else {
                    recordPlugins[plugin.name] = plugin;
                }
            }
        }

        const [lazyExt, lazyOptions, lazyParams]: [
            LazyExt | undefined,
            ExtOptions,
            LazyParams,
        ] = (await args.denops.dispatcher.getExt("lazy")) as [
            LazyExt | undefined,
            ExtOptions,
            PackspecParams,
        ];
        let lazyResult: LazyMakeStateResult | undefined = undefined;
        if (lazyExt) {
            const action = lazyExt.actions.makeState;

            lazyResult = await action.callback({
                denops: args.denops,
                context,
                options,
                protocols,
                extOptions: lazyOptions,
                extParams: lazyParams,
                actionParams: {
                    plugins: Object.values(recordPlugins),
                },
            });
        }

        return {
            ftplugins,
            hooksFiles,
            multipleHooks,
            plugins: lazyResult?.plugins ?? [],
            stateLines: lazyResult?.stateLines ?? [],
        };
    }
}
*/
