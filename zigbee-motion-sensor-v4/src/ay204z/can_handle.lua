local function can_handle(opts, driver, device, ...)
  return device:get_manufacturer() == "AOYAN"
    and device:get_model() == "AY-204Z"
end

return can_handle