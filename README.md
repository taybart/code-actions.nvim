# code-actions.nvim

Add custom code actions to Neovim


## Install

**Minimal config**

```lua
{
    'taybart/code-actions.nvim',
    opts = {
        actions = {
            {
                command = 'hello world', -- what will show up in the picker
                fn = function(action) -- action is passed back with context
                  vim.notify( 'from '.. action.command, vim.log.levels.INFO, { title = 'hello!' })
                end,
            }
        },
    },
}
```

## Config

```lua
{
    'taybart/code-actions.nvim',
    opts = {
        register_keymap = true, -- register nmap("ca") for code actions in buffer
                                -- ie: vim.keymap.set("n", "ca", vim.lsp.buf.code_action, { buffer = ev.buf })
        filetypes = {
            exclude = {},
            include = {},
        },
        -- a server "global" context where additonal functions or modules can be added
        -- this can be a function that returns a table or a table
        ctx = {
            happy = true,
        }
        actions = {
            {
                command = 'hello world', -- what will show up in the picker
                -- check whether to show the action, this defaults always show if not provided
                show = function(ctx) -- here only ctx is passed in
                    -- here we are checking if the global ctx has happy and if we are in a markdown file
                    return ctx.g.happy or ctx.filetype == 'markdown'
                end,
                -- show can also be a table with conditions such as filetype
                show = { ft = { 'markdown' }} -- only show in markdown files
                fn = function(action) -- action is passed back to the fn including ctx
                  vim.notify(
                        'from: '.. action.command,
                        vim.log.levels.INFO,
                        { title = 'hello!' }
                    )
                end,
            }
        },
        -- named servers to differentiate action groups, see below for example
        servers = {
            server_name = {
                -- copy of upper config, filetypes/ctx/actions
            }
        }
    },
}
```


### Context

This would be the context generated from a code action on the install example on the fn line:

```lua
   action.ctx = {
     buf = 1,
     bufname = "/path/to/taybart/code-actions.nvim/README.md",
     col = 4,
     filetype = "markdown",
     g = { -- global context, see gitsigns implementation as an example of using g
     },
     line = "                fn = function(params) -- action is passed back with context ",
     range = {
       ["end"] = <1>{
         character = 4,
         line = 16
       },
       rc = { 16, 4, 16, 4 },
       start = <table 1>
     },
     root = "/path/to/code-actions.nvim",
     row = 16,
     ts_range = { 10, 0, 27, 0 },
     ts_type = "code_fence_content",
     win = 1000,
     word = "fn"
   },
```

### Servers

Here is an example of a server that implements [gitsigns](https://github.com/lewis6991/gitsigns.nvim) actions

**NOTE**: if you are including this as a dependency for your own plugin, make sure to use the `add_server` option so you don't clobber users default actions

```lua
{
    'taybart/code-actions.nvim',
    opts = {
        servers = {
            gitsigns = {
                ctx = {
                    action_exists = function(name)
                        local actions = require('gitsigns').get_actions()
                        return actions ~= nil and actions[name] ~= nil
                    end,
                    get_action = function(name)
                        local actions = require('gitsigns').get_actions()
                        if actions ~= nil and actions[name] ~= nil then
                          return actions[name]
                        end
                        return function() end
                    end,
                },
                -- stylua: ignore
                actions = {
                    {
                      command = 'Preview hunk',
                      show = function(ctx) return ctx.g.action_exists('preview_hunk') end,
                      fn = function(a) a.ctx.g.get_action('preview_hunk')() end,
                    },
                    {
                      command = 'Reset hunk',
                      show = function(ctx) return ctx.g.action_exists('reset_hunk') end,
                      fn = function(a) a.ctx.g.get_action('reset_hunk')() end,
                    },
                    {
                      command = 'Select hunk',
                      show = function(ctx) return ctx.g.action_exists('select_hunk') end,
                      fn = function(a) a.ctx.g.get_action('select_hunk')() end,
                    },
                    {
                      command = 'Stage hunk',
                      show = function(ctx) return ctx.g.action_exists('stage_hunk') end,
                      fn = function(a) a.ctx.g.get_action('stage_hunk')() end,
                    },
                },
            },
        },
    },
}
```

Thanks to [YaroSpace](https://github.com/YaroSpace) for the initial lsp code
