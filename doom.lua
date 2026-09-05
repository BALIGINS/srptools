-- =========================================================
--                    CCTWEAKED DOOM
-- =========================================================
-- Управление:
-- W / S       движение вперёд / назад
-- A / D       поворот
-- SPACE       выстрел
-- R           перезарядка
-- Q           выход
--
-- =========================================================

local VERSION = "1.0"

-- =========================================================
-- НАСТРОЙКИ
-- =========================================================

local FOV = math.pi / 3
local MAX_DISTANCE = 20

local MOVE_SPEED = 0.22
local ROT_SPEED = 0.13

local SHOOT_COOLDOWN = 0.35
local ENEMY_SPEED = 0.018
local ENEMY_DAMAGE = 8
local ENEMY_ATTACK_DISTANCE = 1.25
local ENEMY_ATTACK_COOLDOWN = 0.8

local MAGAZINE_SIZE = 12
local START_AMMO = 12

-- =========================================================
-- ЭКРАН
-- =========================================================

local W, H = term.getSize()

-- =========================================================
-- КАРТА
-- =========================================================

local map = {
    "############################",
    "#..........................#",
    "#..####....................#",
    "#................####......#",
    "#......................... #",
    "#.....####................#",
    "#..........................#",
    "#..........####............#",
    "#..........................#",
    "#.................####.....#",
    "#..........................#",
    "#....####................. #",
    "#..........................#",
    "############################"
}

-- Убираем случайные пробелы в карте
for y = 1, #map do
    map[y] = map[y]:gsub(" ", "#")
end

local MAP_W = #map[1]
local MAP_H = #map

-- =========================================================
-- ИГРОК
-- =========================================================

local player = {
    x = 2.5,
    y = 2.5,

    -- Смотрим вправо
    angle = 0,

    health = 100,

    ammo = START_AMMO,

    maxAmmo = MAGAZINE_SIZE,

    lastShot = 0,

    muzzleFlash = 0
}

-- =========================================================
-- ПРОТИВНИКИ
-- =========================================================

local enemies = {
    {
        x = 9.5,
        y = 2.5,
        health = 100,
        maxHealth = 100,
        damage = 8,
        attackTimer = 0,
        alive = true,
        char = "D"
    },

    {
        x = 18.5,
        y = 2.5,
        health = 100,
        maxHealth = 100,
        damage = 8,
        attackTimer = 0,
        alive = true,
        char = "D"
    },

    {
        x = 14.5,
        y = 6.5,
        health = 100,
        maxHealth = 100,
        damage = 8,
        attackTimer = 0,
        alive = true,
        char = "D"
    },

    {
        x = 7.5,
        y = 9.5,
        health = 100,
        maxHealth = 100,
        damage = 8,
        attackTimer = 0,
        alive = true,
        char = "D"
    },

    {
        x = 22.5,
        y = 11.5,
        health = 100,
        maxHealth = 100,
        damage = 10,
        attackTimer = 0,
        alive = true,
        char = "D"
    }
}

-- =========================================================
-- СЛУЖЕБНЫЕ ФУНКЦИИ
-- =========================================================

local function clamp(value, min, max)
    if value < min then
        return min
    end

    if value > max then
        return max
    end

    return value
end


local function distance(x1, y1, x2, y2)

    local dx = x2 - x1
    local dy = y2 - y1

    return math.sqrt(dx * dx + dy * dy)
end


local function normalizeAngle(angle)

    while angle > math.pi do
        angle = angle - math.pi * 2
    end

    while angle < -math.pi do
        angle = angle + math.pi * 2
    end

    return angle
end


local function isWall(x, y)

    local mx = math.floor(x)
    local my = math.floor(y)

    if mx < 1 or mx > MAP_W then
        return true
    end

    if my < 1 or my > MAP_H then
        return true
    end

    return map[my]:sub(mx, mx) == "#"
end


-- =========================================================
-- LINE OF SIGHT
-- =========================================================

local function hasLineOfSight(x1, y1, x2, y2)

    local dx = x2 - x1
    local dy = y2 - y1

    local dist = math.sqrt(dx * dx + dy * dy)

    local steps = math.max(1, math.floor(dist * 12))

    for i = 1, steps do

        local t = i / steps

        local x = x1 + dx * t
        local y = y1 + dy * t

        if isWall(x, y) then
            return false
        end
    end

    return true
end


-- =========================================================
-- COUNT ENEMIES
-- =========================================================

local function aliveEnemies()

    local count = 0

    for _, enemy in ipairs(enemies) do

        if enemy.alive then
            count = count + 1
        end
    end

    return count
end


-- =========================================================
-- ЗВУК
-- =========================================================

local speaker = peripheral.find("speaker")


local function sound(note, instrument)

    if not speaker then
        return
    end

    pcall(function()
        speaker.playNote(instrument or "harp", 1, note)
    end)
end


-- =========================================================
-- ДВИЖЕНИЕ ИГРОКА
-- =========================================================

local function movePlayer(amount)

    local dx = math.cos(player.angle) * amount
    local dy = math.sin(player.angle) * amount

    local newX = player.x + dx
    local newY = player.y + dy

    -- Небольшой радиус игрока
    local radius = 0.20

    if not isWall(newX + radius, player.y)
        and not isWall(newX - radius, player.y) then

        player.x = newX
    end

    if not isWall(player.x, newY + radius)
        and not isWall(player.x, newY - radius) then

        player.y = newY
    end
end


-- =========================================================
-- ЛУЧ
-- =========================================================

local function castRay(angle)

    local rayX = math.cos(angle)
    local rayY = math.sin(angle)

    local distance = 0

    while distance < MAX_DISTANCE do

        distance = distance + 0.035

        local x = player.x + rayX * distance
        local y = player.y + rayY * distance

        if isWall(x, y) then

            return distance
        end
    end

    return MAX_DISTANCE
end


-- =========================================================
-- ВЫСТРЕЛ
-- =========================================================

local function shoot()

    local now = os.clock()

    if now - player.lastShot < SHOOT_COOLDOWN then
        return
    end

    player.lastShot = now

    if player.ammo <= 0 then

        sound(2, "bass")

        return
    end

    player.ammo = player.ammo - 1
    player.muzzleFlash = 0.10

    sound(12, "pling")

    local target = nil
    local targetDistance = 999

    -- Проверяем всех врагов
    for _, enemy in ipairs(enemies) do

        if enemy.alive then

            local dx = enemy.x - player.x
            local dy = enemy.y - player.y

            local dist = math.sqrt(dx * dx + dy * dy)

            local enemyAngle = math.atan(dy, dx)

            local angleDifference =
                normalizeAngle(enemyAngle - player.angle)

            -- Чем меньше угол — тем ближе к прицелу
            local hitWidth = 0.09 + (dist * 0.015)

            if math.abs(angleDifference) < hitWidth then

                if dist < targetDistance then

                    if hasLineOfSight(
                        player.x,
                        player.y,
                        enemy.x,
                        enemy.y
                    ) then

                        target = enemy
                        targetDistance = dist
                    end
                end
            end
        end
    end

    -- Попадание
    if target then

        local damage = 40

        target.health = target.health - damage

        sound(18, "bell")

        if target.health <= 0 then

            target.health = 0
            target.alive = false

            sound(6, "bass")
        end
    end
end


-- =========================================================
-- ПЕРЕЗАРЯДКА
-- =========================================================

local function reload()

    if player.ammo >= player.maxAmmo then
        return
    end

    player.ammo = player.maxAmmo

    sound(8, "hat")
end


-- =========================================================
-- ОБНОВЛЕНИЕ ВРАГОВ
-- =========================================================

local function updateEnemies(dt)

    for _, enemy in ipairs(enemies) do

        if enemy.alive then

            local dx = player.x - enemy.x
            local dy = player.y - enemy.y

            local dist =
                math.sqrt(dx * dx + dy * dy)

            -- Враг видит игрока
            if hasLineOfSight(
                enemy.x,
                enemy.y,
                player.x,
                player.y
            ) then

                -- Атака
                if dist <= ENEMY_ATTACK_DISTANCE then

                    enemy.attackTimer =
                        enemy.attackTimer - dt

                    if enemy.attackTimer <= 0 then

                        player.health =
                            player.health - enemy.damage

                        enemy.attackTimer =
                            ENEMY_ATTACK_COOLDOWN

                        sound(3, "bass")
                    end

                -- Движение
                elseif dist > 1.0 then

                    local speed =
                        ENEMY_SPEED * dt * 60

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

            else

                enemy.attackTimer =
                    math.max(
                        0,
                        enemy.attackTimer - dt
                    )
            end
        end
    end
end


-- =========================================================
-- РЕНДЕР
-- =========================================================

local function render()

    term.setBackgroundColor(colors.black)
    term.clear()

    local horizon = math.floor(H * 0.45)

    -- =====================================================
    -- НЕБО
    -- =====================================================

    for y = 2, horizon do

        term.setCursorPos(1, y)

        term.setBackgroundColor(colors.black)

        term.write(
            string.rep(" ", W)
        )
    end

    -- =====================================================
    -- ПОЛ
    -- =====================================================

    for y = horizon + 1, H - 3 do

        term.setCursorPos(1, y)

        term.setBackgroundColor(colors.gray)

        term.write(
            string.rep(" ", W)
        )
    end

    -- =====================================================
    -- СТЕНЫ
    -- =====================================================

    local wallDepth = {}

    for column = 1, W do

        local cameraX =
            (column - W / 2) /
            (W / 2)

        local rayAngle =
            player.angle +
            cameraX * (FOV / 2)

        local rawDistance =
            castRay(rayAngle)

        -- Коррекция fisheye
        local corrected =
            rawDistance *
            math.cos(rayAngle - player.angle)

        corrected =
            math.max(corrected, 0.05)

        wallDepth[column] = corrected

        local wallHeight =
            math.floor(
                (H - 5) / corrected * 2.2
            )

        wallHeight =
            clamp(
                wallHeight,
                1,
                H - 5
            )

        local top =
            horizon -
            math.floor(wallHeight / 2)

        local bottom =
            horizon +
            math.floor(wallHeight / 2)

        local brightness =
            1 - corrected / MAX_DISTANCE

        local bg

        if brightness > 0.75 then
            bg = colors.lightGray

        elseif brightness > 0.50 then
            bg = colors.gray

        elseif brightness > 0.25 then
            bg = colors.black

        else
            bg = colors.black
        end

        for y = top, bottom do

            if y >= 2 and y <= H - 4 then

                term.setCursorPos(
                    column,
                    y
                )

                term.setBackgroundColor(bg)

                term.write(" ")
            end
        end
    end


    -- =====================================================
    -- ВРАГИ
    -- =====================================================

    local visibleEnemies = {}

    for _, enemy in ipairs(enemies) do

        if enemy.alive then

            local dx = enemy.x - player.x
            local dy = enemy.y - player.y

            local dist =
                math.sqrt(dx * dx + dy * dy)

            local angle =
                math.atan(dy, dx)

            local relative =
                normalizeAngle(
                    angle - player.angle
                )

            if math.abs(relative) < FOV / 2
                and hasLineOfSight(
                    player.x,
                    player.y,
                    enemy.x,
                    enemy.y
                ) then

                table.insert(
                    visibleEnemies,
                    {
                        enemy = enemy,
                        distance = dist,
                        angle = relative
                    }
                )
            end
        end
    end


    -- Дальние враги рисуются первыми
    table.sort(
        visibleEnemies,
        function(a, b)
            return a.distance >
                   b.distance
        end
    )


    for _, data in ipairs(visibleEnemies) do

        local enemy = data.enemy
        local dist = data.distance

        local screenX =
            math.floor(
                W / 2 +
                (
                    data.angle /
                    (FOV / 2)
                ) * (W / 2)
            )

        local size =
            math.floor(
                (H - 5) /
                dist *
                1.5
            )

        size =
            clamp(
                size,
                1,
                math.floor(H / 2)
            )

        local top =
            horizon -
            math.floor(size / 2)

        local bottom =
            horizon +
            math.floor(size / 2)

        local left =
            screenX -
            math.floor(size / 2)

        local right =
            screenX +
            math.floor(size / 2)

        for x = left, right do

            if x >= 1 and x <= W then

                if dist <
                    (wallDepth[x] or MAX_DISTANCE) then

                    for y = top, bottom do

                        if y >= 2
                            and y <= H - 4 then

                            term.setCursorPos(
                                x,
                                y
                            )

                            term.setBackgroundColor(
                                colors.red
                            )

                            term.setTextColor(
                                colors.white
                            )

                            -- Глаза / тело
                            if y ==
                                math.floor(
                                    (top + bottom) / 2
                                ) then

                                term.write("D")
                            else
                                term.write(" ")
                            end
                        end
                    end
                end
            end
        end

        -- HP врага
        if size >= 4
            and screenX >= 1
            and screenX <= W then

            local hpWidth =
                math.max(
                    1,
                    math.floor(
                        size *
                        enemy.health /
                        enemy.maxHealth
                    )
                )

            local hpY =
                math.max(
                    2,
                    top - 1
                )

            if hpY <= H - 4 then

                term.setCursorPos(
                    screenX -
                    math.floor(size / 2),
                    hpY
                )

                term.setBackgroundColor(
                    colors.black
                )

                term.setTextColor(
                    colors.red
                )

                term.write(
                    string.rep(
                        "#",
                        hpWidth
                    )
                )
            end
        end
    end


    -- =====================================================
    -- ПРИЦЕЛ
    -- =====================================================

    local cx =
        math.floor(W / 2)

    local cy =
        horizon

    term.setBackgroundColor(
        colors.black
    )

    term.setTextColor(
        colors.white
    )

    term.setCursorPos(cx, cy)
    term.write("+")


    -- =====================================================
    -- ОРУЖИЕ
    -- =====================================================

    local gunY = H - 4

    term.setTextColor(colors.lightGray)
    term.setBackgroundColor(colors.black)

    if player.muzzleFlash > 0 then

        term.setTextColor(colors.yellow)

        term.setCursorPos(
            cx - 3,
            gunY - 1
        )

        term.write("\\|/")
    end

    term.setCursorPos(
        cx - 4,
        gunY
    )

    term.write(" /===\\ ")

    term.setCursorPos(
        cx - 2,
        gunY + 1
    )

    term.write(" ||| ")

    term.setCursorPos(
        cx - 2,
        gunY + 2
    )

    term.write(" ||| ")


    -- =====================================================
    -- HUD
    -- =====================================================

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)

    term.setCursorPos(1, 1)

    term.write(
        "DOOM " ..
        VERSION
    )

    term.setCursorPos(1, 2)

    term.setTextColor(colors.red)

    term.write(
        "HP: " ..
        tostring(
            math.max(
                0,
                player.health
            )
        )
    )

    term.setTextColor(colors.yellow)

    term.setCursorPos(10, 2)

    term.write(
        "AMMO: " ..
        tostring(player.ammo) ..
        "/" ..
        tostring(player.maxAmmo)
    )

    term.setTextColor(colors.orange)

    term.setCursorPos(23, 2)

    term.write(
        "DEMONS: " ..
        tostring(aliveEnemies())
    )

    -- =====================================================
    -- ПЕРЕЗАРЯДКА
    -- =====================================================

    if player.ammo == 0 then

        term.setCursorPos(
            math.floor(W / 2) - 5,
            2
        )

        term.setTextColor(colors.red)

        term.write("RELOAD!")
    end

    -- =====================================================
    -- НИЖНЯЯ ПАНЕЛЬ
    -- =====================================================

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.gray)

    term.setCursorPos(
        1,
        H
    )

    term.write(
        "W/S MOVE  A/D TURN  SPACE FIRE  R RELOAD  Q QUIT"
    )
end


-- =========================================================
-- ЭКРАН ПОБЕДЫ
-- =========================================================

local function victory()

    term.setBackgroundColor(colors.black)
    term.clear()

    term.setCursorPos(
        math.floor(W / 2) - 12,
        math.floor(H / 2) - 3
    )

    term.setTextColor(colors.lime)

    print("========================")
    print("     LEVEL COMPLETE     ")
    print("========================")

    term.setTextColor(colors.white)

    print("")
    print("Все демоны уничтожены!")
    print("")
    print("RIP AND TEAR!")

    os.pullEvent("key")
end


-- =========================================================
-- ЭКРАН СМЕРТИ
-- =========================================================

local function gameOver()

    term.setBackgroundColor(colors.black)
    term.clear()

    term.setCursorPos(
        math.floor(W / 2) - 12,
        math.floor(H / 2) - 3
    )

    term.setTextColor(colors.red)

    print("========================")
    print("        YOU DIED        ")
    print("========================")

    term.setTextColor(colors.white)

    print("")
    print("Демоны победили.")
    print("")
    print("RIP AND TEAR!")

    os.pullEvent("key")
end


-- =========================================================
-- МЕНЮ
-- =========================================================

term.setBackgroundColor(colors.black)
term.clear()

term.setCursorPos(
    math.floor(W / 2) - 14,
    3
)

term.setTextColor(colors.red)

print("================================")
print("         CCTWEAKED DOOM         ")
print("================================")

term.setTextColor(colors.white)

print("")
print("        R I P   A N D   T E A R")
print("")
print("")
print("  W / S       Движение")
print("  A / D       Поворот")
print("  SPACE       Стрелять")
print("  R           Перезарядка")
print("  Q           Выход")
print("")
print("  Демоны: " .. tostring(#enemies))
print("  Патроны: " .. tostring(player.maxAmmo))
print("")
print("Нажми любую клавишу...")

os.pullEvent("key")


-- =========================================================
-- ОСНОВНОЙ ЦИКЛ
-- =========================================================

local running = true
local lastTime = os.clock()

while running do

    local currentTime = os.clock()

    local dt =
        math.min(
            currentTime - lastTime,
            0.1
        )

    lastTime = currentTime

    -- Вспышка выстрела
    if player.muzzleFlash > 0 then

        player.muzzleFlash =
            player.muzzleFlash - dt

        if player.muzzleFlash < 0 then
            player.muzzleFlash = 0
        end
    end


    -- =====================================================
    -- ОТРИСОВКА
    -- =====================================================

    render()


    -- =====================================================
    -- ПРОВЕРКА ПОБЕДЫ
    -- =====================================================

    if aliveEnemies() == 0 then

        victory()
        break
    end


    -- =====================================================
    -- ПРОВЕРКА СМЕРТИ
    -- =====================================================

    if player.health <= 0 then

        gameOver()
        break
    end


    -- =====================================================
    -- СОБЫТИЯ
    -- =====================================================

    local timer =
        os.startTimer(0.03)

    local event, p1, p2 =
        os.pullEvent()

    if event == "key" then

        local key = p1

        if key == keys.w then

            movePlayer(MOVE_SPEED)

        elseif key == keys.s then

            movePlayer(-MOVE_SPEED)

        elseif key == keys.a then

            player.angle =
                player.angle -
                ROT_SPEED

        elseif key == keys.d then

            player.angle =
                player.angle +
                ROT_SPEED

        elseif key == keys.space then

            shoot()

        elseif key == keys.r then

            reload()

        elseif key == keys.q then

            running = false
        end

    elseif event == "timer" and p1 == timer then

        updateEnemies(dt)
    end

end


-- =========================================================
-- ВЫХОД
-- =========================================================

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

print("DOOM завершён.")
