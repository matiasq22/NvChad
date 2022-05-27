_G.nvchad = {}

local merge_tb = vim.tbl_deep_extend

nvchad.close_buffer = function(force)
   if vim.bo.buftype == "terminal" then
      vim.api.nvim_win_hide(0)
      return
   end

   local fileExists = vim.fn.filereadable(vim.fn.expand "%p")
   local modified = vim.api.nvim_buf_get_option(vim.fn.bufnr(), "modified")

   -- if file doesnt exist & its modified
   if fileExists == 0 and modified then
      print "no file name? add it now!"
      return
   end

   force = force or not vim.bo.buflisted or vim.bo.buftype == "nofile"

   -- if not force, change to prev buf and then close current
   local close_cmd = force and ":bd!" or ":bp | bd" .. vim.fn.bufnr()
   vim.cmd(close_cmd)
end

nvchad.load_config = function()
   local config = require "core.default_config"
   local chadrc_exists = vim.fn.filereadable(vim.fn.stdpath "config" .. "/lua/custom/chadrc.lua") == 1

   if chadrc_exists then
      -- merge user config if it exists and is a table; otherwise display an error
      local user_config = require "custom.chadrc"

      if type(user_config) == "table" then
         nvchad.remove_default_keys()
         config = merge_tb("force", config, user_config)
      else
         error "chadrc must return a table!"
      end
   end

   config.mappings.disabled = nil
   return config
end

nvchad.remove_default_keys = function()
   local defaults = require "core.default_config"
   local chadrc = require "custom.chadrc"

   local matched_disabled_keys = function(mode, mapping, keybind)
      local disabled_keys = chadrc.mappings.disabled or {}
      if vim.tbl_contains(disabled_keys[mode] or {}, keybind) then
         mapping[keybind] = nil
      end
   end

   -- a table of strings + no keys -> un-needed

   for _, section_mappings in pairs(defaults.mappings) do
      for mode, mapping in pairs(section_mappings) do
         for keybind, _ in pairs(mapping) do
            matched_disabled_keys(mode, mapping, keybind)
         end
      end
   end
end

nvchad.load_mappings = function(mappings, mapping_opt)
   mappings = mappings or nvchad.load_config().mappings

   -- set map function if whichkey exists or no
   local whichkey_exists, wk = pcall(require, "which-key")
   local default_opts = mapping_opt or {}

   for section, section_mappings in pairs(mappings) do
      -- skip some mappings
      if section == "lspconfig" then
         goto continue
      end

      for mode, mode_mappings in pairs(section_mappings) do
         for keybind, mapping_info in pairs(mode_mappings) do
            -- whichkey

            if whichkey_exists then
               default_opts = { mode = mode }
               local opts = merge_tb("force", default_opts, mapping_info.opts or {})

               if mapping_info.opts then
                  mapping_info.opts = nil
               end

               local mapping = { [keybind] = mapping_info }
               wk.register(mapping, opts)

               -- without whichkey
            else
               local opts = merge_tb("force", default_opts, mapping_info.opts or {})
               vim.keymap.set(mode, keybind, mapping_info[1], opts)
            end
         end
      end

      ::continue::
   end
end

-- load plugin after entering vim ui
nvchad.packer_lazy_load = function(plugin, timer)
   if plugin then
      timer = timer or 0
      vim.defer_fn(function()
         require("packer").loader(plugin)
      end, timer)
   end
end

-- remove plugins defined in chadrc
nvchad.remove_default_plugins = function(plugins)
   local removals = nvchad.load_config().plugins.remove or {}

   if not vim.tbl_isempty(removals) then
      for _, plugin in pairs(removals) do
         plugins[plugin] = nil
      end
   end

   return plugins
end

-- merge default/user plugin tables
nvchad.merge_plugins = function(default_plugins)
   local user_plugins = nvchad.load_config().plugins.user

   -- merge default + user plugin table
   default_plugins = merge_tb("force", default_plugins, user_plugins)

   local final_table = {}

   for key, _ in pairs(default_plugins) do
      default_plugins[key][1] = key

      final_table[#final_table + 1] = default_plugins[key]
   end

   return final_table
end

nvchad.load_override = function(default_table, plugin_name)
   local user_table = nvchad.load_config().plugins.override[plugin_name]

   if type(user_table) == "table" then
      default_table = merge_tb("force", default_table, user_table)
   else
      default_table = default_table
   end

   return default_table
end
