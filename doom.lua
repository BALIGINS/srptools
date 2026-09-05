-- ==========================================
--          CCTWEAKED DOOM
-- ==========================================

term.clear()
term.setCursorPos(1, 1)

local W, H = term.getSize()

-- Карта
local map = {
    "####################",
    "#..................#",
    "#..####............#",
    "#..................#",
    "#.........####.....#",
    "#..................#",
    "#....####..........#",
    "#..................#",
    "#.............####.#",
    "#..................#",
    "####################"
}

local mapW = #map[1]
local mapH = #map

-- Игрок
local player = {
    x = 2.5,
    y = 2.5,
    angle = 0,
    health = 100,
    ammo = 30
}

-- Враги
local enemies = {
    {x = 10.5, y = 2.5, health = 30},
    {x = 15.5, y = 4.5, health = 30},
    {x = 7.5, y = 6.5, health = 30},
    {x = 12.5, y = 8.5, health = 30}
}

local FOV = math.pi / 3
local MAX_DIST = 20

local function isWall(x, y)
    local mx = math.floor(x)
    local my = math.floor(y)

    if mx < 1 or mx > mapW or my < 1 or my > mapH then
        return true
    end

    return map[my]:sub(mx, mx) == "#"
end

local function distance(x1, y1, x2, y2)
    return math.sqrt((x2-x1)^2 + (y2-y1)^2)
end

local function normalizeAngle(a)
    while a > math.pi do
        a = a - math.pi * 2
    end

    while a < -math.pi do
        a = a + math.pi * 2
    end

    return a
end

-- Проверка попадания луча
local function shoot()
    if player.ammo <= 0 then
        return
    end

    player.ammo = player.ammo - 1

    local closest = nil
    local closestDist = 999

    for _, enemy in ipairs(enemies) do

        if enemy.health > 0 then

            local dx = enemy.x - player.x
            local dy = enemy.y - player.y

            local dist = math.sqrt(dx * dx + dy * dy)

            local angle = math.atan2(dy, dx)
            local diff = normalizeAngle(angle - player.angle)

            if math.abs(diff) < 0.12 then

                -- Проверяем стену между игроком и врагом
                local blocked = false

                local steps = math.floor(dist * 10)

                for i = 1, steps do
                    local t = i / steps

                    local x = player.x + dx * t
                    local y = player.y + dy * t

                    if isWall(x, y) then
                        blocked = true
                        break
                    end
                end

                if not blocked and dist < closestDist then
                    closest = enemy
                    closestDist = dist
                end
            end
        end
    end

    if closest then
        closest.health = closest.health - 30

        term.setCursorPos(1, H)
        term.write("💥 HIT!")

        if closest.health <= 0 then
            term.write(" ENEMY DOWN!")
        end
    end
end

-- Рендер стены
local function render()

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()

    local centerY = math.floor(H / 2)

    for column = 1, W do

        local cameraX = (column - W / 2) / (W / 2)

        local rayAngle =
            player.angle + cameraX * (FOV / 2)

        local rayX = math.cos(rayAngle)
        local rayY = math.sin(rayAngle)

        local dist = 0
        local hit = false

        while dist < MAX_DIST do

            dist = dist + 0.05

            local x = player.x + rayX * dist
            local y = player.y + rayY * dist

            if isWall(x, y) then
                hit = true
                break
            end
        end

        if hit then

            -- Коррекция эффекта fisheye
            local corrected =
                dist * math.cos(rayAngle - player.angle)

            if corrected < 0.1 then
                corrected = 0.1
            end

            local wallHeight =
                math.floor((H - 3) / corrected)

            if wallHeight > H - 3 then
                wallHeight = H - 3
            end

            local top =
                centerY - math.floor(wallHeight / 2)

            local bottom =
                centerY + math.floor(wallHeight / 2)

            for y = top, bottom do

                if y >= 2 and y < H - 1 then

                    local brightness =
                        1 - corrected / MAX_DIST

                    if brightness > 0.75 then
                        term.setBackgroundColor(colors.lightGray)
                    elseif brightness > 0.45 then
                        term.setBackgroundColor(colors.gray)
                    else
                        term.setBackgroundColor(colors.black)
                    end

                    term.setCursorPos(column, y)
                    term.write(" ")
                end
            end
        end
    end

    -- Прицел
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)

    term.setCursorPos(
        math.floor(W / 2),
        centerY
    )

    term.write("+")

    -- Оружие
    term.setTextColor(colors.white)

    local gunY = H - 2

    term.setCursorPos(
        math.floor(W / 2) - 5,
        gunY
    )

    term.write("  /===\\  ")

    term.setCursorPos(
        math.floor(W / 2) - 3,
        gunY + 1
    )

    term.write(" ||| ")

    -- Интерфейс
    term.setBackgroundColor(colors.black)

    term.setCursorPos(1, 1)

    term.setTextColor(colors.red)

    term.write(
        "HP: " ..
        player.health ..
        "   AMMO: " ..
        player.ammo
    )

    -- Враги в интерфейсе
    local alive = 0

    for _, enemy in ipairs(enemies) do
        if enemy.health > 0 then
            alive = alive + 1
        end
    end

    term.setCursorPos(
        W - 15,
        1
    )

    term.write(
        "DEMONS: " .. alive
    )
end

-- Движение
local function move(dx, dy)

    local nx = player.x + dx
    local ny = player.y + dy

    if not isWall(nx, player.y) then
        player.x = nx
    end

    if not isWall(player.x, ny) then
        player.y = ny
    end
end

-- Атака врагов
local function enemyAttack()

    for _, enemy in ipairs(enemies) do

        if enemy.health > 0 then

            local dist =
                distance(
                    player.x,
                    player.y,
                    enemy.x,
                    enemy.y
                )

            if dist < 1.5 then
                player.health =
                    player.health - 5
            end
        end
    end
end

-- Движение врагов
local function updateEnemies()

    for _, enemy in ipairs(enemies) do

        if enemy.health > 0 then

            local dx =
                player.x - enemy.x

            local dy =
                player.y - enemy.y

            local dist =
                math.sqrt(dx * dx + dy * dy)

            if dist > 1.2 then

                local speed = 0.025

                local nx =
                    enemy.x + dx / dist * speed

                local ny =
                    enemy.y + dy / dist * speed

                if not isWall(nx, enemy.y) then
                    enemy.x = nx
                end

                if not isWall(enemy.x, ny) then
                    enemy.y = ny
                end
            end
        end
    end
end

-- Победа
local function checkWin()

    for _, enemy in ipairs(enemies) do
        if enemy.health > 0 then
            return false
        end
    end

    return true
end

-- Главное меню
term.clear()
term.setCursorPos(1, 3)

print("================================")
print("          CCTWEAKED DOOM        ")
print("================================")
print("")
print("      RIP AND TEAR!")
print("")
print("W / S  - движение")
print("A / D  - поворот")
print("SPACE  - стрелять")
print("Q      - выход")
print("")
print("Нажми любую клавишу...")

os.pullEvent("key")

term.clear()

-- Игровой цикл
while true do

    render()

    if player.health <= 0 then
        term.clear()
        term.setCursorPos(1, 4)

        print("================================")
        print("            YOU DIED             ")
        print("================================")
        print("")
        print("Твоя душа принадлежит демонам.")
        print("")
        print("Нажми любую клавишу для выхода.")

        os.pullEvent("key")
        break
    end

    if checkWin() then
        term.clear()
        term.setCursorPos(1, 4)

        print("================================")
        print("          LEVEL COMPLETE!        ")
        print("================================")
        print("")
        print("Все демоны уничтожены!")
        print("")
        print("RIP AND TEAR!")
        print("")
        print("Нажми любую клавишу.")

        os.pullEvent("key")
        break
    end

    local event, key = os.pullEvent("key")

    if key == keys.w then
        move(
            math.cos(player.angle) * 0.25,
            math.sin(player.angle) * 0.25
        )

    elseif key == keys.s then
        move(
            -math.cos(player.angle) * 0.25,
            -math.sin(player.angle) * 0.25
        )

    elseif key == keys.a then
        player.angle =
            player.angle - 0.15

    elseif key == keys.d then
        player.angle =
            player.angle + 0.15

    elseif key == keys.space then
        shoot()

    elseif key == keys.q then
        break
    end

    updateEnemies()
    enemyAttack()

    sleep(0.03)
end
