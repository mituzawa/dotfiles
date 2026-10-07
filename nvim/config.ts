import type { Plugin } from "jsr:@shougo/dpp-vim@~6.3.1/types";
import {
    BaseConfig,
    type ConfigArguments,
    type ConfigReturn,
} from "jsr:@shougo/dpp-vim@~6.3.1/config";
import * as fn from "jsr:@denops/std@~8.2.0/function";

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
    override async config(args: ConfigArguments): Promise<ConfigReturn> {
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
            for (const plugin of toml.plugins ?? []) {
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
