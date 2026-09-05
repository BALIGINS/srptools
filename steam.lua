local url = "https://raw.githubusercontent.com/BALIGINS/srptools/main/Noze_MC_-_Ustrojj_Destrojj_b64f0d240.dfpwm"

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
