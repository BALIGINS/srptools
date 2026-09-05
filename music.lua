local speaker = peripheral.find("speaker")

if not speaker then
    print("Ошибка: Speaker не найден!")
    return
end

local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

local file = fs.open("music.dfpwm", "rb")

if not file then
    print("Ошибка: music.dfpwm не найден!")
    return
end

print("Воспроизведение...")

while true do
    local chunk = file.read(16 * 1024)

    if not chunk then
        break
    end

    local audio = decoder(chunk)

    while not speaker.playAudio(audio) do
        os.pullEvent("speaker_audio_empty")
    end
end

file.close()

print("Музыка закончилась.")
