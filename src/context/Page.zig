const Page = @This();

const std = @import("std");
const ziggy = @import("ziggy");
const scripty = @import("scripty");
const supermd = @import("supermd");
const utils = @import("utils.zig");
const render = @import("../render.zig");
const Signature = @import("doctypes.zig").Signature;
const DateTime = @import("DateTime.zig");
const context = @import("../context.zig");
const join = @import("../root.zig").join;
const Allocator = std.mem.Allocator;
const Value = context.Value;
const Optional = context.Optional;
const Bool = context.Bool;
const String = context.String;

const log = std.log.scoped(.page);

var asset_undef: context.AssetExtern = .{};
var page_undef: context.PageExtern = .{};

title: []const u8,
description: []const u8 = "",
author: []const u8,
date: DateTime,
layout: []const u8,
draft: bool = false,
tags: []const []const u8 = &.{},
aliases: []const []const u8 = &.{},
alternatives: []const Alternative = &.{},
skip_subdirs: bool = false,
translation_key: ?[]const u8 = null,
custom: ziggy.dynamic.Value = .{ .kv = .{} },

_meta: struct {
    site: *const context.Site = undefined,
    md_path: []const u8 = "",
    md_rel_path: []const u8 = "",
    md_asset_dir_path: []const u8 = "",
    md_asset_dir_rel_path: []const u8 = "",

    // true when this page has not been loaded via Scripty
    is_root: bool = false,
    parent_section_path: ?[]const u8 = null,
    index_in_section: ?usize = null,
    word_count: u64 = 0,
    is_section: bool = false,
    key_variants: []const Translation = &.{},
    src: []const u8 = "",
    ast: ?supermd.Ast = null,

    const Self = @This();
    pub const ziggy_options = struct {
        pub fn stringify(
            value: Self,
            opts: ziggy.serializer.StringifyOptions,
            indent_level: usize,
            depth: usize,
            writer: anytype,
        ) !void {
            _ = value;
            _ = opts;
            _ = indent_level;
            _ = depth;

            try writer.writeAll("{}");
        }

        pub fn parse(
            p: *ziggy.Parser,
            first_tok: ziggy.Tokenizer.Token,
        ) !Self {
            try p.must(first_tok, .lb);
            _ = try p.nextMust(.rb);
            return .{};
        }
    };
} = .{},

pub const Translation = struct {
    site: *const context.Site,
    md_rel_path: []const u8,
};

pub const Alternative = struct {
    name: []const u8,
    layout: []const u8,
    output: []const u8,
    type: []const u8 = "",
    _prefix: []const u8 = "",

    pub const dot = scripty.defaultDot(Alternative, Value, false);
    // pub const PassByRef = true;

    pub const docs_description =
        \\An alternative version of the current page. Title and type
        \\can be used when generating `<link rel="alternate">` elements.
    ;
    pub const Fields = struct {
        pub const layout =
            \\The SuperHTML layout to use to generate this alternative version of the page.
        ;
        pub const output =
            \\Output path where to to put the generated alternative.
        ;
        pub const name =
            \\A name that can be used to fetch this alternative version
            \\of the page.
        ;
        pub const @"type" =
            \\A metadata field that can be used to set the content-type of this alternative version of the Page. 
            \\
            \\Useful for example to generate RSS links:
            \\
            \\```superhtml
            \\<ctx alt="$page.alternative('rss')">
            \\  <a href="$ctx.alt.link()" 
            \\     type="$ctx.alt.type" 
            \\     :text="$ctx.alt.name"
            \\  ></a>
            \\</ctx>
            \\```
        ;
    };
    pub const Builtins = struct {
        pub const link = struct {
            pub const signature: Signature = .{ .ret = .String };
            pub const docs_description =
                \\Returns the URL of the target alternative.
            ;
            pub const examples =
                \\$page.alternative("rss").link()
            ;
            pub fn call(
                alt: Alternative,
                gpa: Allocator,
                args: []const Value,
            ) !Value {
                if (args.len != 0) return .{ .err = "expected 0 arguments" };

                const result = try join(gpa, &.{
                    "/",
                    alt._prefix,
                    alt.output,
                    "/",
                });

                return String.init(result);
            }
        };
    };
};

pub const Footnote = struct {
    def_id: []const u8,
    ref_ids: []const []const u8,

    _page: *const Page,
    _idx: usize,

    pub const docs_description =
        \\A footnote from a page.
    ;
    pub const Fields = struct {
        pub const def_id =
            \\The ID for the footnote definition.
        ;
        pub const ref_ids =
            \\The IDs of the footnote's references,
            \\to be used for creating backlinks.
        ;
    };
    pub const Builtins = struct {
        pub const html = struct {
            pub const signature: Signature = .{ .ret = .String };
            pub const docs_description =
                \\Renders the footnote definition.
            ;
            pub const examples = "";
            pub fn call(
                f: Footnote,
                gpa: Allocator,
                args: []const Value,
            ) !Value {
                if (args.len != 0) return .{ .err = "expected 0 arguments" };

                var buf = std.ArrayList(u8).init(gpa);
                const ast = f._page._meta.ast orelse unreachable;
                const node = ast.footnotes.values()[f._idx].node;

                try render.html(gpa, ast, node, "", buf.writer());
                return String.init(try buf.toOwnedSlice());
            }
        };
    };
    pub const dot = scripty.defaultDot(Footnote, Value, false);
};

pub const dot = scripty.defaultDot(Page, Value, false);
pub const PassByRef = true;

pub const docs_description =
    \\The page currently being rendered.
;
pub const Fields = struct {
    pub const title =
        \\Title of the page, 
        \\as set in the SuperMD frontmatter.
    ;
    pub const description =
        \\Description of the page, 
        \\as set in the SuperMD frontmatter.
    ;
    pub const author =
        \\Author of the page, 
        \\as set in the SuperMD frontmatter.
    ;
    pub const date =
        \\Publication date of the page, 
        \\as set in the SuperMD frontmatter.
        \\
        \\Used to provide default ordering of pages.
    ;
    pub const layout =
        \\SuperHTML layout used to render the page, 
        \\as set in the SuperMD frontmatter.
    ;
    pub const draft =
        \\When set to true the page will not be rendered in release mode, 
        \\as set in the SuperMD frontmatter.
    ;
    pub const tags =
        \\Tags associated with the page, 
        \\as set in the SuperMD frontmatter.
    ;
    pub const aliases =
        \\Aliases of the current page, 
        \\as set in the SuperMD frontmatter.
        \\
        \\Aliases can be used to make the same page available
        \\from different locations.
        \\
        \\Every entry in the list is an output location where the 
        \\rendered page will be copied to.
    ;
    pub const alternatives =
        \\Alternative versions of the page, 
        \\as set in the SuperMD frontmatter.
        \\
        \\Alternatives are a good way of implementing RSS feeds, for example.
    ;
    pub const skip_subdirs =
        \\Skips any other potential content present in the subdir of the page, 
        \\as set in the SuperMD frontmatter.
        \\
        \\Can only be set to true on section pages (i.e. `index.smd` pages).
    ;
    pub const translation_key =
        \\Translation key used to map this page with corresponding localized variants, 
        \\as set in the SuperMD frontmatter.
        \\
        \\See the docs on i18n for more info.
    ;
    pub const custom =
        \\A Ziggy map where you can define custom properties for the page, 
        \\as set in the SuperMD frontmatter.
    ;
};
pub const Builtins = struct {
    pub const isCurrent = struct {
        pub const signature: Signature = .{ .ret = .Bool };
        pub const docs_description =
            \\Returns true if the target page is the one currently being 
            \\rendered. 
            \\
            \\To be used in conjunction with the various functions that give 
            \\you references to other pages, like `$site.page()`, for example.
        ;
        pub const examples =
            \\<div class="$site.page('foo').isCurrent().then('selected')"></div>
        ;
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            _ = gpa;
            if (args.len != 0) return .{ .err = "expected 0 arguments" };
            return Bool.init(p._meta.is_root);
        }
    };

    pub const asset = struct {
        pub const signature: Signature = .{
            .params = &.{.String},
            .ret = .Asset,
        };
        pub const docs_description =
            \\Retuns an asset by name from inside the page's asset directory.
            \\
            \\Assets for a non-section page must be placed under a subdirectory 
            \\that shares the same name with the corresponding markdown file.
            \\
            \\(as a reminder sections are defined by pages named `index.smd`)
            \\
            \\| section? |     page path      | asset directory |
            \\|----------|--------------------|-----------------|
            \\|   yes    | blog/foo/index.smd |    blog/foo/    |
            \\|   no     | blog/bar.smd       |    blog/bar/    |
        ;
        pub const examples =
            \\<img src="$page.asset('foo.png').link(false)">
        ;
        pub fn call(
            p: *const Page,
            _: Allocator,
            args: []const Value,
        ) !Value {
            if (!p._meta.is_root) return .{
                .err = "accessing assets of other pages has not been implemented yet, sorry!",
            };

            const bad_arg: Value = .{
                .err = "expected 1 string argument",
            };
            if (args.len != 1) return bad_arg;

            const ref = switch (args[0]) {
                .string => |s| s.value,
                else => return bad_arg,
            };

            return context.assetFind(ref, .{ .page = p });
        }
    };
    pub const site = struct {
        pub const signature: Signature = .{ .ret = .Site };
        pub const docs_description =
            \\Returns the Site that the page belongs to.
        ;
        pub const examples =
            \\<div :text="$page.site().localeName()"></div>
        ;
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            _ = gpa;
            if (args.len != 0) return .{ .err = "expected 0 arguments" };
            return .{ .site = p._meta.site };
        }
    };

    pub const locale = struct {
        pub const signature: Signature = .{
            .params = &.{.String},
            .ret = .{ .Opt = .Page },
        };
        pub const docs_description =
            \\Returns a reference to a localized variant of the target page.
            \\
        ;
        pub const examples =
            \\<div :text="$page.locale('en-US').title"></div>
        ;
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            _ = gpa;

            const bad_arg: Value = .{
                .err = "expected 1 string argument",
            };
            if (args.len != 1) return bad_arg;

            const code = switch (args[0]) {
                .string => |s| s.value,
                else => return bad_arg,
            };

            const other_site = context.siteGet(code) orelse return .{
                .err = "unknown locale code",
            };
            if (p.translation_key) |tk| {
                for (p._meta.key_variants) |*v| {
                    if (std.mem.eql(u8, v.site._meta.kind.multi.code, code)) {
                        const other = context.pageGet(other_site, tk, null, null, false) catch @panic("TODO: report that a localized variant failed to load");
                        return .{ .page = other };
                    }
                }
                return .{ .err = "locale not found" };
            } else {
                const other = context.pageGet(
                    other_site,
                    p._meta.md_rel_path,
                    null,
                    null,
                    false,
                ) catch @panic("Trying to access a non-existent localized variant of a page is an error for now, sorry! As a temporary workaround you can set a translation key for this page (and its localized variants). This limitation will be lifted in the future.");
                return .{ .page = other };
            }
        }
    };

    pub const @"locale?" = struct {
        pub const signature: Signature = .{
            .params = &.{.String},
            .ret = .{ .Opt = .Page },
        };
        pub const docs_description =
            \\Returns a reference to a localized variant of the target page, if
            \\present. Returns null otherwise.
            \\
            \\To be used in conjunction with an `if` attribute.
        ;
        pub const examples =
            \\<div :if="$page.locale?('en-US')">
            \\  <a href="$if.link()" :text="$if.title"></a>
            \\</div>
        ;
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            const bad_arg: Value = .{
                .err = "expected 1 string argument",
            };
            if (args.len != 1) return bad_arg;

            const code = switch (args[0]) {
                .string => |s| s.value,
                else => return bad_arg,
            };

            const other_site = context.siteGet(code) orelse return .{
                .err = "unknown locale code",
            };
            if (p.translation_key) |tk| {
                for (p._meta.key_variants) |*v| {
                    if (std.mem.eql(u8, v.site._meta.kind.multi.code, code)) {
                        const other = context.pageGet(other_site, tk, null, null, false) catch @panic("TODO: report that a localized variant failed to load");
                        return Optional.init(gpa, other);
                    }
                }
                return Optional.Null;
            } else {
                const other = context.pageGet(
                    other_site,
                    p._meta.md_rel_path,
                    null,
                    null,
                    false,
                ) catch @panic("trying to access a non-existent localized variant of a page is an error for now, sorry! give the same translation key to all variants of this page and you won't see this error anymore.");
                return Optional.init(gpa, other);
            }
        }
    };

    pub const locales = struct {
        pub const signature: Signature = .{ .ret = .{ .Many = .Page } };
        pub const docs_description =
            \\Returns the list of localized variants of the current page.
        ;
        pub const examples =
            \\<div :loop="$page.locales()"><a href="$loop.it.link()" :text="$loop.it.title"></a></div>
        ;
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            if (args.len != 0) return .{ .err = "expected 0 arguments" };

            // if (true) return .{
            //     .iterator = try context.Iterator.init(gpa, .{
            //         .translation_it = context.Iterator.TranslationIterator.init(p),
            //     }),
            // };

            const all_sites = context.allSites();

            // Because of a limitation of how indexing works, we
            // assume that all translations will be present if there is no
            // translation_key specified.
            const total_variants = if (p.translation_key == null)
                all_sites.len
            else
                p._meta.key_variants.len;

            const localized_pages = try gpa.alloc(Value, total_variants);

            var last_page = p;
            for (localized_pages, 0..) |*lp, idx| {
                const t: Page.Translation = if (p.translation_key == null) .{
                    .site = &all_sites[idx],
                    .md_rel_path = last_page._meta.md_rel_path,
                } else last_page._meta.key_variants[idx];

                const found_page = context.pageGet(
                    t.site,
                    t.md_rel_path,
                    null,
                    null,
                    false,
                ) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.PageLoad => @panic("trying to access a non-existent localized variant of a page is an error for now, sorry! give the same translation key to all variants of this page and you won't see this error anymore."),
                };

                lp.* = .{ .page = found_page };
                last_page = found_page;
            }

            return context.Array.init(gpa, Value, localized_pages) catch unreachable;
        }
    };

    pub const wordCount = struct {
        pub const signature: Signature = .{ .ret = .Int };
        pub const docs_description =
            \\Returns the word count of the page.
            \\
            \\The count is performed assuming 5-letter words, so it actually
            \\counts all characters and divides the result by 5.
        ;
        pub const examples =
            \\<div :loop="$page.wordCount()"></div>
        ;
        pub fn call(
            self: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            _ = gpa;
            if (args.len != 0) return .{ .err = "expected 0 arguments" };
            return .{ .int = .{ .value = @intCast(self._meta.word_count) } };
        }
    };

    pub const parentSection = struct {
        pub const signature: Signature = .{ .ret = .Page };
        pub const docs_description =
            \\Returns the parent section of a page. 
            \\
            \\It's always an error to call this function on the site's main 
            \\index page as it doesn't have a parent section.
        ;
        pub const examples =
            \\$page.parentSection()
        ;
        pub fn call(
            self: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            _ = gpa;
            if (args.len != 0) return .{ .err = "expected 0 arguments" };
            const p = self._meta.parent_section_path orelse return .{
                .err = "root index page has no parent path",
            };
            return context.pageFind(.{
                .ref = .{
                    .path = p,
                    .site = self._meta.site,
                },
            });
        }
    };

    pub const isSection = struct {
        pub const signature: Signature = .{ .ret = .Bool };
        pub const docs_description =
            \\Returns true if the current page defines a section (i.e. if 
            \\the current page is an 'index.smd' page).
            \\
        ;
        pub const examples =
            \\$page.isSection()
        ;
        pub fn call(
            self: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            _ = gpa;
            if (args.len != 0) return .{ .err = "expected 0 arguments" };
            return Bool.init(self._meta.is_section);
        }
    };

    pub const subpages = struct {
        pub const signature: Signature = .{ .ret = .{ .Many = .Page } };
        pub const docs_description =
            \\Returns a list of all the pages in this section. If the page is 
            \\not a section, returns an empty list.
            \\
            \\Sections are defined by `index.smd` files, see the content 
            \\structure section in the official docs for more info.
        ;
        pub const examples =
            \\<div :loop="$page.subpages()">
            \\  <span :text="$loop.it.title"></span>
            \\</div>
        ;
        pub fn call(
            p: *const Page,
            _: Allocator,
            args: []const Value,
        ) !Value {
            if (args.len != 0) return .{ .err = "expected 0 arguments" };
            return context.pageFind(.{ .subpages = p });
        }
    };

    pub const subpagesAlphabetic = struct {
        pub const signature: Signature = .{ .ret = .{ .Many = .Page } };
        pub const docs_description =
            \\Same as `subpages`, but returns the pages in alphabetic order by
            \\comparing their titles. 
        ;
        pub const examples =
            \\<div :loop="$page.subpagesAlphabetic()">
            \\  <span :text="$loop.it.title"></span>
            \\</div>
        ;
        pub fn call(
            p: *const Page,
            _: Allocator,
            args: []const Value,
        ) !Value {
            if (args.len != 0) return .{ .err = "expected 0 arguments" };
            const pages = try context.pageFind(.{ .subpages = p });

            std.mem.sort(Value, @constCast(pages.array._items), {}, struct {
                fn alphaLessThan(_: void, lhs: Value, rhs: Value) bool {
                    return std.mem.lessThan(u8, lhs.page.title, rhs.page.title);
                }
            }.alphaLessThan);

            return pages;
        }
    };

    pub const @"nextPage?" = struct {
        pub const signature: Signature = .{ .ret = .{ .Opt = .Page } };
        pub const docs_description =
            \\Returns the next page in the same section, sorted by date. 
            \\
            \\The returned value is an optional to be used in conjunction 
            \\with an `if` attribute. Use `$if` to access the unpacked value
            \\within the `if` block.
        ;
        pub const examples =
            \\<div :if="$page.nextPage()">
            \\  <span :text="$if.title"></span>
            \\</div>
        ;

        pub fn call(
            p: *const Page,
            _: Allocator,
            args: []const Value,
        ) !Value {
            if (args.len != 0) return .{ .err = "expected 0 arguments" };

            if (p._meta.index_in_section == null) return .{
                .err = "unable to do next on a page loaded by scripty, for now",
            };

            return context.pageFind(.{ .next = p });
        }
    };
    pub const @"prevPage?" = struct {
        pub const signature: Signature = .{ .ret = .{ .Opt = .Page } };
        pub const docs_description =
            \\Tries to return the page before the target one (sorted by date), to be used with an `if` attribute.
        ;
        pub const examples =
            \\<div :if="$page.prevPage()"></div>
        ;

        pub fn call(
            p: *const Page,
            _: Allocator,
            args: []const Value,
        ) !Value {
            if (args.len != 0) return .{ .err = "expected 0 arguments" };

            const idx = p._meta.index_in_section orelse return .{
                .err = "unable to do prev on a page loaded by scripty, for now",
            };

            if (idx == 0) return .{ .optional = null };

            return context.pageFind(.{ .prev = p });
        }
    };

    pub const hasNext = struct {
        pub const signature: Signature = .{ .ret = .Bool };
        pub const docs_description =
            \\Returns true of the target page has another page after (sorted by date) 
        ;
        pub const examples =
            \\$page.hasNext()
        ;

        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            _ = gpa;
            if (args.len != 0) return .{ .err = "expected 0 arguments" };

            if (p._meta.index_in_section == null) return .{
                .err = "unable to do next on a page loaded by scripty, for now",
            };

            const other = try context.pageFind(.{ .next = p });
            return Bool.init(other.optional != null);
        }
    };
    pub const hasPrev = struct {
        pub const signature: Signature = .{ .ret = .Bool };
        pub const docs_description =
            \\Returns true of the target page has another page before (sorted by date) 
        ;
        pub const examples =
            \\$page.hasPrev()
        ;
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            _ = gpa;
            if (args.len != 0) return .{ .err = "expected 0 arguments" };

            const idx = p._meta.index_in_section orelse return .{
                .err = "unable to do prev on a page loaded by scripty, for now",
            };

            if (idx == 0) return Bool.False;

            const other = try context.pageFind(.{ .prev = p });
            return Bool.init(other.optional != null);
        }
    };

    pub const link = struct {
        pub const signature: Signature = .{ .ret = .String };
        pub const docs_description =
            \\Returns the URL of the target page.
        ;
        pub const examples =
            \\$page.link()
        ;
        pub fn call(
            self: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            if (args.len != 0) return .{ .err = "expected 0 arguments" };
            const p = self._meta.md_rel_path;
            const path = switch (self._meta.is_section) {
                true => p[0 .. p.len - "index.smd".len],
                false => p[0 .. p.len - ".smd".len],
            };

            const result = try join(gpa, &.{
                "/",
                self._meta.site._meta.url_path_prefix,
                path,
                "/",
            });

            return String.init(result);
        }
    };

    pub const linkRef = struct {
        pub const signature: Signature = .{
            .params = &.{.String},
            .ret = .String,
        };
        pub const docs_description =
            \\Returns the URL of the target page, allowing you 
            \\to specify a fragment id to deep-link to a specific
            \\element of the content page.
            \\
            \\The id will be checked by Zine and an error will be  
            \\reported if it does not exist.
            \\
            \\See the SuperMD reference documentation to learn how to give
            \\ids to elements.
        ;
        pub const examples =
            \\$page.linkRef('foo')
        ;
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            const bad_arg: Value = .{
                .err = "expected 1 string argument",
            };
            if (args.len != 1) return bad_arg;

            const elem_id = switch (args[0]) {
                .string => |s| s.value,
                else => return bad_arg,
            };

            const ast = p._meta.ast.?;
            if (!ast.ids.contains(elem_id)) return Value.errFmt(
                gpa,
                "cannot find id ='{s}' in the content page",
                .{elem_id},
            );

            const relp = p._meta.md_rel_path;
            const path = switch (p._meta.is_section) {
                true => relp[0 .. relp.len - "index.smd".len],
                false => relp[0 .. relp.len - ".smd".len],
            };

            const fragment = try std.fmt.allocPrint(gpa, "#{s}", .{elem_id});
            const result = try join(gpa, &.{
                "/",
                p._meta.site._meta.url_path_prefix,
                path,
                fragment,
            });

            return String.init(result);
        }
    };

    pub const alternative = struct {
        pub const signature: Signature = .{
            .params = &.{.String},
            .ret = .Alternative,
        };
        pub const docs_description =
            \\Returns an alternative by name.
        ;
        pub const examples =
            \\<ctx alt="$page.alternative('rss')">
            \\  <a href="$ctx.alt.link()" 
            \\     type="$ctx.alt.type" 
            \\     :text="$ctx.alt.name"
            \\  ></a>
        ;
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            const bad_arg: Value = .{
                .err = "expected 1 string argument",
            };
            if (args.len != 1) return bad_arg;

            const alt_name = switch (args[0]) {
                .string => |s| s.value,
                else => return bad_arg,
            };

            for (p.alternatives) |alt| {
                if (std.mem.eql(u8, alt.name, alt_name)) {
                    return Value.from(gpa, alt);
                }
            }

            return .{
                .err = "unable to find an alertnative with the provided name",
            };
        }
    };

    pub const content = struct {
        pub const signature: Signature = .{ .ret = .String };
        pub const docs_description =
            \\Renders the full Markdown page to HTML
        ;
        pub const examples = "";
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            if (args.len != 0) return .{ .err = "expected 0 arguments" };

            var buf = std.ArrayList(u8).init(gpa);
            const ast = p._meta.ast orelse unreachable;

            if (!p._meta.is_root) return .{
                .err = "only the main page can be rendered for now, sorry!",
            };

            try render.html(gpa, ast, ast.md.root, "", buf.writer());
            return String.init(try buf.toOwnedSlice());
        }
    };
    pub const contentSection = struct {
        pub const signature: Signature = .{
            .params = &.{.String},
            .ret = .String,
        };
        pub const docs_description =
            \\Renders the specified [content section]($link.page('docs/supermd/scripty').ref('Section')) of a page.
        ;
        pub const examples =
            \\<div :html="$page.contentSection('section-id')"></div>
            \\<div :html="$page.contentSection('other-section')"></div>
        ;
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            const bad_arg: Value = .{
                .err = "expected 1 string argument",
            };
            if (args.len != 1) return bad_arg;

            const section_id = switch (args[0]) {
                .string => |s| s.value,
                else => return bad_arg,
            };

            const ast = p._meta.ast orelse return .{
                .err = "only the main page can be rendered for now",
            };
            var buf = std.ArrayList(u8).init(gpa);

            const node = ast.ids.get(section_id) orelse {
                return Value.errFmt(
                    gpa,
                    "content section '{s}' doesn't exist",
                    .{section_id},
                );
            };

            if (node.getDirective() == null or node.getDirective().?.kind != .section) {
                return Value.errFmt(
                    gpa,
                    "id '{s}' exists but is not a section",
                    .{section_id},
                );
            }

            try render.html(gpa, ast, node, "", buf.writer());
            return String.init(try buf.toOwnedSlice());
        }
    };
    pub const hasContentSection = struct {
        pub const signature: Signature = .{
            .params = &.{.String},
            .ret = .String,
        };
        pub const docs_description =
            \\Returns true if the page contains a content-section with the given id
        ;
        pub const examples =
            \\<div :html="$page.hasContentSection('section-id')"></div>
            \\<div :html="$page.hasContentSection('other-section')"></div>
        ;
        pub fn call(
            p: *const Page,
            _: Allocator,
            args: []const Value,
        ) !Value {
            const bad_arg: Value = .{
                .err = "expected 1 string argument argument",
            };
            if (args.len != 1) return bad_arg;

            const section_id = switch (args[0]) {
                .string => |s| s.value,
                else => return bad_arg,
            };

            const ast = p._meta.ast orelse return .{
                .err = "only the main page can be rendered for now",
            };
            // a true value indicates that `contentSection` will not error
            const has_section = blk: {
                const section = ast.ids.get(section_id) orelse break :blk false;
                const directive = section.getDirective() orelse break :blk false;
                break :blk directive.kind == .section;
            };
            return Bool.init(has_section);
        }
    };

    pub const contentSections = struct {
        pub const signature: Signature = .{
            .params = &.{},
            .ret = .{ .Many = .ContentSection },
        };
        pub const docs_description =
            \\Returns a list of sections for the current page.
            \\
            \\A page that doesn't define any section will have
            \\a default section for the whole document with a 
            \\null id.
        ;
        pub const examples =
            \\<div :html="$page.contentSections()"></div>
        ;
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            const bad_arg: Value = .{
                .err = "expected 0 arguments",
            };
            if (args.len != 0) return bad_arg;

            const ast = p._meta.ast.?;

            var sections = std.ArrayList(ContentSection).init(gpa);
            var it = ast.ids.iterator();
            while (it.next()) |kv| {
                const d = kv.value_ptr.getDirective() orelse continue;
                if (d.kind == .section) {
                    try sections.append(.{
                        .id = d.id orelse "",
                        .data = d.data,
                        ._node = kv.value_ptr.*,
                        ._ast = ast,
                    });
                }
            }

            return Value.from(gpa, try sections.toOwnedSlice());
        }
    };

    pub const @"footnotes?" = struct {
        pub const signature: Signature = .{
            .params = &.{},
            .ret = .{ .Opt = .{ .Many = .Footnote } },
        };
        pub const docs_description =
            \\Returns a list of footnotes for the current page, if any exist.
        ;
        pub const examples =
            \\<ctx :if="$page.footnotes?()">
            \\  <ol :loop="$if">
            \\    <li id="$loop.it.def_id">
            \\      <ctx :html="$loop.it.html()"></ctx>
            \\      <ctx :loop="$loop.it.ref_ids">
            \\        <a href="$loop.it.prefix('#')" :html="$loop.idx"></a>
            \\      </ctx>
            \\    </li>
            \\  </ol>
            \\</ctx>
        ;
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            const bad_arg: Value = .{
                .err = "expected 0 arguments",
            };
            if (args.len != 0) return bad_arg;

            const ast = p._meta.ast.?;
            if (ast.footnotes.count() == 0) {
                return Optional.Null;
            }
            var _footnotes = try gpa.alloc(Footnote, ast.footnotes.count());
            for (ast.footnotes.values(), 0..) |footnote, i| {
                _footnotes[i] = .{
                    .def_id = footnote.def_id,
                    .ref_ids = footnote.ref_ids,
                    ._page = p,
                    ._idx = i,
                };
            }
            return Optional.init(gpa, _footnotes);
        }
    };

    pub const toc = struct {
        pub const signature: Signature = .{ .ret = .String };
        pub const docs_description =
            \\Renders the table of content.
        ;
        pub const examples =
            \\<div :html="$page.toc()"></div>
        ;
        pub fn call(
            p: *const Page,
            gpa: Allocator,
            args: []const Value,
        ) !Value {
            const bad_arg: Value = .{
                .err = "expected 0 arguments",
            };
            if (args.len != 0) return bad_arg;

            const ast = p._meta.ast orelse return .{
                .err = "only the main page can be rendered for now",
            };
            var buf = std.ArrayList(u8).init(gpa);
            try render.htmlToc(ast, buf.writer());

            return String.init(try buf.toOwnedSlice());
        }
    };
};

pub const ContentSection = struct {
    id: []const u8,
    data: supermd.Directive.Data = .{},
    _node: supermd.Node,
    _ast: supermd.Ast,

    pub const dot = scripty.defaultDot(ContentSection, Value, false);
    pub const docs_description =
        \\A content section from a page.
    ;
    pub const Fields = struct {
        pub const id =
            \\The id of the current section.
        ;
        pub const data =
            \\A Ziggy Map that contains data key-value pairs set in SuperMD
        ;
    };
    pub const Builtins = struct {
        pub const heading = struct {
            pub const signature: Signature = .{ .ret = .String };
            pub const docs_description =
                \\If the section starts with a heading element,
                \\this function returns the heading as simple text.           
            ;
            pub const examples =
                \\<div :html="$loop.it.heading()"></div>
            ;
            pub fn call(
                cs: ContentSection,
                gpa: Allocator,
                args: []const Value,
            ) !Value {
                const bad_arg: Value = .{
                    .err = "expected 0 arguments",
                };
                if (args.len != 0) return bad_arg;

                const err = Value.errFmt(gpa, "section '{s}' has no heading", .{
                    cs.id,
                });

                if (cs._node.nodeType() != .HEADING) {
                    return err;
                }

                // const link_node = cs._node.firstChild() orelse {
                //     return err;
                // };

                // const text_node = link_node.firstChild() orelse {
                //     return err;
                // };

                // const text = text_node.literal() orelse {
                //     return err;
                // };

                const text = try cs._node.renderPlaintext();

                return String.init(text);
            }
        };
        pub const @"heading?" = struct {
            pub const signature: Signature = .{ .ret = .{ .Opt = .String } };
            pub const docs_description =
                \\If the section starts with a heading element,
                \\this function returns the heading as simple text.           
            ;
            pub const examples =
                \\<div :html="$loop.it.heading()"></div>
            ;
            pub fn call(
                cs: ContentSection,
                gpa: Allocator,
                args: []const Value,
            ) !Value {
                const bad_arg: Value = .{
                    .err = "expected 0 arguments",
                };
                if (args.len != 0) return bad_arg;

                if (cs._node.nodeType() != .HEADING) {
                    return Optional.Null;
                }

                const link_node = cs._node.firstChild() orelse {
                    return Optional.Null;
                };

                const text = link_node.literal() orelse {
                    return Optional.Null;
                };

                return Optional.init(gpa, String.init(text));
            }
        };
        pub const html = struct {
            pub const signature: Signature = .{ .ret = .String };
            pub const docs_description =
                \\Renders the section.
            ;
            pub const examples =
                \\<div :html="$loop.it.html()"></div>
            ;
            pub fn call(
                cs: ContentSection,
                gpa: Allocator,
                args: []const Value,
            ) !Value {
                const bad_arg: Value = .{
                    .err = "expected 0 arguments",
                };
                if (args.len != 0) return bad_arg;

                var buf = std.ArrayList(u8).init(gpa);

                log.debug("rendering content section [#{s}]", .{cs.id});
                try render.html(
                    gpa,
                    cs._ast,
                    cs._node,
                    "",
                    buf.writer(),
                );
                return String.init(try buf.toOwnedSlice());
            }
        };
    };
};
