
-- Keep active until done.
gpio.mode(2, gpio.OUTPUT)
gpio.write(2, gpio.HIGH)

print("Starting AButton")

-- GPIO5
PIN_LED = 1
TIMER_INTERVAL = 200
timer = tmr.create()
count_remaining = 0
LED_OFF = string.char(0, 0, 0)
led_color = LED_OFF
timer:register(TIMER_INTERVAL, tmr.ALARM_AUTO, function ()
                  count_remaining = count_remaining - 1
                  if count_remaining <= 0 then
                     timer:stop()
                     print("Stopping AButton")
                     ws2812.write(PIN_LED, LED_OFF)
                     gpio.write(2, gpio.LOW)
                     return
                  elseif count_remaining % 2 == 0 then
                     ws2812.write(PIN_LED, led_color)
                  else
                     ws2812.write(PIN_LED, LED_OFF)
                  end
end)

function blink_and_die(count, red, green, blue)
   timer:stop()
   count_remaining = (count + 1) * 2
   led_color = string.char(green, red, blue)
   ws2812.write(PIN_LED, led_color)
   timer:start()
end

blink_and_die(5 * 5, 255, 0, 255)

-- Read config.json into config table.
config = {}
local decoder = sjson.decoder()
local config_file = file.open("config.json")
if config_file then
   local chunk
   repeat
      chunk = config_file:read()
      if chunk then decoder:write(chunk) end
   until chunk == null
   file.close()
   config = decoder:result()
end

if config.hostname then
   wifi.sta.sethostname(config.hostname)
end

wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
                          timer:stop()
                          print("IP address " .. T.IP)
                          blink_and_die(5 * 5, 255, 255, 0)
                          print("POST to " .. config.url)
                          http.post(config.url,
                                    "Content-Type: application/json\r\n",
                                    sjson.encode(config.body or {}),
                                    function(code, data)
                                       timer:stop()
                                       print(code, data)
                                       wifi.sta.disconnect()
                                       if code < 0 then
                                          blink_and_die(3, 255, 0, 0)
                                       elseif code ~= 200 then
                                          blink_and_die(4, 255, 0, 0)
                                       else
                                          blink_and_die(3, 0, 255, 0)
                                       end
                          end)
end)

-- Now turn on WiFi to start everything.
wifi.sta.connect()
