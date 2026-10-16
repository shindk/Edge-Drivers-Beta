local messages = require "st.zigbee.messages"
local zcl_messages = require "st.zigbee.zcl"
local data_types = require "st.zigbee.data_types"
local constants = require "st.zigbee.constants"

local TUYA_CLUSTER = 0xEF00
local TUYA_CMD_SET_DATA = 0x00

local DP_SENSITIVITY = 0x09
local DP_KEEP_TIME   = 0x0A

local sequence = 0

local function next_sequence()
  sequence = (sequence + 1) % 256
  return sequence
end

local function build_tuya_enum_message(device, dp, value)
  local seq = next_sequence()

  -- Tuya DP payload
  -- transaction/status = 00
  -- transaction sequence = seq
  -- DP ID
  -- DP type = 04 (ENUM)
  -- length = 0001
  -- value = xx
  local payload = string.char(
    0x00,
    seq,
    dp,
    0x04,
    0x00,
    0x01,
    value
  )

  local frame_ctrl = zcl_messages.FrameCtrl(0x11)

  local zcl_header = zcl_messages.ZclHeader({
    frame_ctrl = frame_ctrl,
    cmd = data_types.ZCLCommandId(TUYA_CMD_SET_DATA)
  })

  local zcl_body = messages.GenericBody(payload)

  local addr_header = messages.AddressHeader(
    constants.HUB.ADDR,
    constants.HUB.ENDPOINT,
    device:get_short_address(),
    device:get_endpoint(TUYA_CLUSTER),
    constants.HA_PROFILE_ID,
    TUYA_CLUSTER
  )

  local message_body = zcl_messages.ZclMessageBody({
    zcl_header = zcl_header,
    zcl_body = zcl_body
  })

  return messages.ZigbeeMessageTx({
    address_header = addr_header,
    body = message_body
  })
end

local function send_sensitivity(device, preference)
  local values = {
    low = 0,
    medium = 1,
    high = 2
  }

  local value = values[preference]

  if value ~= nil then
    print(string.format(
      "AY-204Z: sending sensitivity %s -> DP 0x09 value %d",
      tostring(preference),
      value
    ))

    device:send(
      build_tuya_enum_message(
        device,
        DP_SENSITIVITY,
        value
      )
    )
  end
end

local function send_keep_time(device, preference)
  local values = {
    ["10"]  = 0,
    ["30"]  = 1,
    ["60"]  = 2,
    ["120"] = 3
  }

  local value = values[tostring(preference)]

  if value ~= nil then
    print(string.format(
      "AY-204Z: sending keep time %s sec -> DP 0x0A value %d",
      tostring(preference),
      value
    ))

    device:send(
      build_tuya_enum_message(
        device,
        DP_KEEP_TIME,
        value
      )
    )
  end
end

local function info_changed(driver, device, event, args)
  local old_preferences =
    args.old_st_store
    and args.old_st_store.preferences
    or {}

  if old_preferences.ay204zSensitivity
      ~= device.preferences.ay204zSensitivity then

    send_sensitivity(
      device,
      device.preferences.ay204zSensitivity
    )
  end

  if old_preferences.ay204zKeepTime
      ~= device.preferences.ay204zKeepTime then

    send_keep_time(
      device,
      device.preferences.ay204zKeepTime
    )
  end
end

local ay204z = {
  NAME = "AOYAN AY-204Z",

  lifecycle_handlers = {
    infoChanged = info_changed
  },

  can_handle = require("ay204z.can_handle")
}

return ay204z