local url = "https://videotourl.com/audio/1788632194035-558e9b01-58e4-46e7-b2ee-28bccc38e2e4.mp3"

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

print("▶ Воспроизведение...")

while true do
    -- Небольшой кусок DFPWM
    local chunk = response.read(1600)

    if not chunk then
        break
    end

    local audio = decoder(chunk)

    -- Ждём, пока динамик сможет принять следующий кусок
    while not speaker.playAudio(audio) do
        os.pullEvent("speaker_audio_empty")
    end
end

response.close()

print("■ Музыка закончилась.")
