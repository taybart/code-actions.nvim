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
                fn = function(action) -- action is passed back to the fn including ctx
                  vim.notify(
                        'from '.. action.command,
                        vim.log.levels.INFO,
                        { title = 'hello!' }
                    )
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
                show = function(ctx)
                    if ctx.g.happy or ctx.filetype == 'markdown' then
                        return true
                    end
                    return false
                end,
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


### Servers

Here is an example of a server that implements [gitsigns](https://github.com/lewis6991/gitsigns.nvim) actions

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
                      command = 'preview hunk',
                      show = function(ctx) return ctx.g.action_exists('preview_hunk') end,
                      fn = function(action) action.ctx.g.get_action('preview_hunk')() end,
                    },
                    {
                      command = 'reset hunk',
                      show = function(ctx) return ctx.g.action_exists('reset_hunk') end,
                      fn = function(action) action.ctx.g.get_action('reset_hunk')() end,
                    },
                    {
                      command = 'select hunk',
                      show = function(ctx) return ctx.g.action_exists('select_hunk') end,
                      fn = function(action) action.ctx.g.get_action('select_hunk')() end,
                    },
                    {
                      command = 'stage hunk',
                      show = function(ctx) return ctx.g.action_exists('stage_hunk') end,
                      fn = function(action) action.ctx.g.get_action('stage_hunk')() end,
                    },
                },
            },
        },
    },
}
```

Thanks to [YaroSpace](https://github.com/YaroSpace) for the inital lsp code
