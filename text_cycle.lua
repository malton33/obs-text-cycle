-- Import the OBS library
obs = obslua

--[[
=================================================================================
DESCRIPTION
=================================================================================
This script changes the text of a specified GDI+ Text Source at a regular interval.
You can define a list of text strings, and the script will cycle through them.
--]]

--[[
=================================================================================
GLOBAL VARIABLES
=================================================================================
--]]
source_name = ""              -- The name of the text source to update
text_list = {}                -- The list of strings to cycle through
interval = 30                 -- The time in seconds between text changes
current_index = 1             -- The index of the current string in the list
timer_active = false          -- A flag to track if the timer is running

--[[
=================================================================================
SCRIPT FUNCTIONS
=================================================================================
--]]

-- This function is called every frame but we only use it to start our timer
function script_tick(seconds)
  if not timer_active then
    -- Start the timer to call the update_text function repeatedly
    obs.timer_add(update_text, interval * 1000)
    timer_active = true
  end
end

-- Button callback to force the text to cycle immediately
function force_cycle_text(props, prop)
  update_text()
  return true
end

-- This function updates the text source with the next string in the list
function update_text()
  -- Get the source by its name
  local source = obs.obs_get_source_by_name(source_name)

  -- Check if the source exists
  if source ~= nil then
    -- Get the current settings of the source
    local settings = obs.obs_data_create()

    -- Create a table with the new text
    local new_settings = {
      text = text_list[current_index]
    }

    -- Set the new text in the settings object
    obs.obs_data_set_string(settings, "text", new_settings.text)

    -- Update the source with the new settings
    obs.obs_source_update(source, settings)

    -- Release the settings object to free memory
    obs.obs_data_release(settings)

    -- Move to the next index in the list
    current_index = current_index + 1

    -- If we've reached the end of the list, loop back to the beginning
    if current_index > #text_list then
      current_index = 1
    end

    -- Release the source object
    obs.obs_source_release(source)
  else
    -- Log an error if the source is not found
    obs.script_log(obs.LOG_WARNING, "Source '" .. source_name .. "' not found.")
  end
end

--[[
=================================================================================
SCRIPT PROPERTIES
=================================================================================
This function defines the user-configurable properties that appear in the
OBS Scripts window.
--]]
function script_properties()
  local props = obs.obs_properties_create()

  -- Try to create a dropdown list; fallback to text input if the API differs
  local list_prop
  local ok = pcall(function()
    list_prop = obs.obs_properties_add_list(
      props,
      "source_name",
      "Text Source",
      obs.OBS_COMBO_TYPE_EDITABLE,
      obs.OBS_COMBO_FORMAT_STRING
    )
  end)

  if ok and list_prop ~= nil then
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
      for _, source in ipairs(sources) do
        local id = obs.obs_source_get_unversioned_id(source)
        if id == "text_gdiplus_v2" or id == "text_gdiplus" then
          local name = obs.obs_source_get_name(source)
          obs.obs_property_list_add_string(list_prop, name, name)
        end
      end
      obs.source_list_release(sources)
    end
  else
    -- Fallback for environments where obs_properties_add_list signature differs
    obs.obs_properties_add_text(props, "source_name", "Text Source", obs.OBS_TEXT_DEFAULT)
  end

  -- Text list and interval
  obs.obs_properties_add_text(props, "text_list", "Text List (one per line)", obs.OBS_TEXT_MULTILINE)
  obs.obs_properties_add_int(props, "interval", "Interval (seconds)", 5, 3600, 1)

  -- Button to immediately cycle the text
  obs.obs_properties_add_button(props, "force_cycle_btn", "Cycle Text Now", force_cycle_text)

  return props
end

--[[
=================================================================================
SCRIPT UPDATE
=================================================================================
This function is called when the user changes the script's properties.
--]]
function script_update(settings)
  -- Get the values from the properties
  source_name = obs.obs_data_get_string(settings, "source_name")
  local text_data = obs.obs_data_get_string(settings, "text_list")
  interval = obs.obs_data_get_int(settings, "interval")

  -- Split the text area content into a list of strings
  text_list = {}
  for str in string.gmatch(text_data, "([^\r\n]*)") do
    if #str > 0 then
      table.insert(text_list, str)
    end
  end

  -- Reset the timer and index if settings change
  obs.timer_remove(update_text)
  timer_active = false
  current_index = 1

  -- Immediately update the text to the first item
  if #text_list > 0 then
    update_text()
  end
end

--[[
=================================================================================
SCRIPT DEFAULTS
=================================================================================
This function sets the default values for the properties.
--]]
function script_defaults(settings)
  obs.obs_data_set_default_int(settings, "interval", 30)
  obs.obs_data_set_default_string(settings, "text_list", "First message\nSecond message\nAnother one!")
end

--[[
=================================================================================
SCRIPT DESCRIPTION
=================================================================================
Provides a description of the script.
--]]
function script_description()
  return "Cycles through a list of text strings for a specified text source at a set interval."
end

--[[
=================================================================================
SCRIPT HOTKEYS
=================================================================================
--]]
local hotkey_id = obs.OBS_INVALID_HOTKEY_ID

-- Hotkey callback to cycle the text now
function on_cycle_hotkey(pressed)
  if pressed then
    update_text()
  end
end

function script_load(settings)
  -- Register a frontend hotkey and load saved binding
  hotkey_id = obs.obs_hotkey_register_frontend("force_cycle_text.hotkey", "(Text Cycle) Cycle Text Now", on_cycle_hotkey)
  local a = obs.obs_data_get_array(settings, "force_cycle_text.hotkey")
  obs.obs_hotkey_load(hotkey_id, a)
  obs.obs_data_array_release(a)
end

function script_save(settings)
  -- Persist the hotkey binding
  local a = obs.obs_hotkey_save(hotkey_id)
  obs.obs_data_set_array(settings, "force_cycle_text.hotkey", a)
  obs.obs_data_array_release(a)
end
