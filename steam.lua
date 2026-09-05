local url = "https://raw.githubusercontent.com/BALIGINS/srptools/main/ENZRO_-_Ty_ne_bojjsya_nochi_81423717.dfpwm"

local speaker = peripheral.find("speaker")

if not speaker then
    print("Speaker не найден!")
    return
end

local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

local response, err = http.get(url, nil, true)

if not response then
    print("Ошибка загрузки:")
    print(err or "Неизвестная ошибка")
    return
end

print("Музыка загружается...")

while true do
    local chunk = response.read(16 * 1024)

    if not chunk then
        break
    end

    local audio = decoder(chunk)

    while not speaker.playAudio(audio) do
        os.pullEvent("speaker_audio_empty")
    end
end

response.close()

print("Готово!")
