-- =======================================================================
-- ==                     АВТОМОБИЛЬНАЯ ПАНЕЛЬ (F3)                     ==
-- =======================================================================

local screenW, screenH = guiGetScreenSize()

main = {}
destroy = {}
sell = {}

main.timer = false

-- =======================================================================
-- ==     ОСНОВНОЕ ОКНО (MAIN PANEL)                                    ==
-- =======================================================================

main.window = guiCreateWindow(screenW/2-500/2, screenH/2-300/2, 500, 300, "Avtomobil İdarə Etmə Paneli", false)
guiWindowSetSizable(main.window, false)

main.grid = guiCreateGridList(10, 25, 375, 265, false, main.window)
guiGridListAddColumn(main.grid, "ID", 0.15)
guiGridListAddColumn(main.grid, "Ad", 0.4)
guiGridListAddColumn(main.grid, "Nömrə", 0.25)
guiGridListAddColumn(main.grid, "Benzin", 0.2)

main.spawn      = guiCreateButton(390, 25,  105, 26, "Teleport",            false, main.window)
main.destroy    = guiCreateButton(390, 56,  105, 26, "Qaraja qoy",          false, main.window)
main.destroyAll = guiCreateButton(390, 87,  105, 26, "Hamısını Qaraja Qoy", false, main.window)
main.frozen     = guiCreateButton(390, 118, 105, 26, "Ruçnoy Çək",          false, main.window)
main.lock       = guiCreateButton(390, 149, 105, 26, "Aç/Bağla",            false, main.window)
main.delete     = guiCreateButton(390, 180, 105, 26, "Sat",                 false, main.window)
main.sell       = guiCreateButton(390, 211, 105, 26, "Oyunçuya Sat",        false, main.window)
main.salonTp    = guiCreateButton(390, 242, 105, 26, "Salona Teleport",     false, main.window)

guiSetVisible(main.window, false)

-- =======================================================================
-- ==     ОКНО ПОДТВЕРЖДЕНИЯ (DESTROY CONFIRMATION)                     ==
-- =======================================================================

destroy.data = {}
destroy.window = guiCreateWindow(screenW/2-350/2, screenH/2-150/2, 350, 150, "Satışı Təsdiqlə", false)
guiWindowSetSizable(destroy.window, false)

destroy.label = guiCreateLabel(10, 30, 330, 60, "", false, destroy.window)
guiLabelSetHorizontalAlign(destroy.label, "center", true)

destroy.yes = guiCreateButton(30,  100, 130, 35, "Bəli, Sat",              false, destroy.window)
destroy.no  = guiCreateButton(190, 100, 130, 35, "Xeyr, Fikrimi Dəyişdim", false, destroy.window)

guiSetVisible(destroy.window, false)

-- =======================================================================
-- ==     ФУНКЦИИ-ЗАГЛУШКИ                                              ==
-- =======================================================================

function openSell()
	outputChatBox("Интерфейс продажи игроку должен открыться сейчас.", 255, 194, 14)
end

-- =======================================================================
-- ==     ОСНОВНЫЕ ФУНКЦИИ И ОБРАБОТЧИКИ                                ==
-- =======================================================================

function showMainWindow(bool)
	guiSetVisible(main.window, bool)
	showCursor(bool)
end

bindKey("F3", "down", function ()
	if guiGetVisible(destroy.window) then return end
	local isVisible = guiGetVisible(main.window)
	showMainWindow(not isVisible)
	if not isVisible then
		triggerServerEvent("refreshMainWindow", localPlayer)
	end
end)

function refreshMainWindow(list)
	local old, _ = guiGridListGetSelectedItem(main.grid)
	guiGridListClear(main.grid)
	if not list then return end

	for _, row in pairs(list) do
		local plate = ""
		if row["plate"] then
			local plates = fromJSON(row["plate"])
			if plates and plates["plate"] then
				plate = plates["plate"]
			end
		end

		local newRow = guiGridListAddRow(main.grid)
		guiGridListSetItemText(main.grid, newRow, 1, tostring(row["ID"]), false, false)
		guiGridListSetItemData(main.grid, newRow, 1, tostring(row["ID"]))
		guiGridListSetItemText(main.grid, newRow, 2, getVehicleData(row["model"], "name"), false, false)

		local vehicle = getVehicleFromID(row["ID"])
		if isElement(vehicle) then
			guiGridListSetItemText(main.grid, newRow, 3, (getElementData(vehicle, "vehicle:plate") or ""), false, false)
			guiGridListSetItemText(main.grid, newRow, 4, math.floor(getElementData(vehicle, "vehicle:fuel") or 0).."%", false, false)
		else
			guiGridListSetItemText(main.grid, newRow, 3, plate, false, false)
			guiGridListSetItemText(main.grid, newRow, 4, math.floor(row["fuel"] or 0).."%", false, false)
		end
	end

	if old and old ~= -1 then
		guiGridListSetSelectedItem(main.grid, old, 1)
	end
end
addEvent("refreshMainWindow", true)
addEventHandler("refreshMainWindow", root, refreshMainWindow)

function getVehicleFromID(ID)
	for i, v in pairs(getElementsByType("vehicle")) do
		if getElementData(v, "vehicle:ID") == tonumber(ID) then
			return v
		end
	end
	return false
end

addEventHandler("onClientGUIClick", root, function ()
	if main.timer then return end

	local function setClickTimer()
		main.timer = setTimer(function() main.timer = false end, 1000, 1)
	end

	-- Телепорт в автосалон — не требует выбранной машины
	if source == main.salonTp then
		if isPedInVehicle(localPlayer) then
			outputChatBox("Avtomobildən düş!", 255, 100, 100)
			return
		end
		setElementPosition(localPlayer, 1706.2312011719, -1116.5513916016, 24.090625762939)
		setElementInterior(localPlayer, 0)
		setElementDimension(localPlayer, 0)
		showMainWindow(false)
		setClickTimer()
		return
	end

	local selectedRow, _ = guiGridListGetSelectedItem(main.grid)
	if selectedRow == -1 and source ~= main.destroyAll and source ~= destroy.no and source ~= destroy.yes then
		return
	end

	local selectedID = guiGridListGetItemData(main.grid, selectedRow, 1)

	if source == main.spawn then
		if not isPedInVehicle(localPlayer) and selectedID then
			triggerServerEvent("spawnVehicleFromID", localPlayer, selectedID)
			setClickTimer()
		end
	elseif source == main.destroy then
		if selectedID then
			triggerServerEvent("destroyVehicleFromID", localPlayer, selectedID)
			setClickTimer()
		end
	elseif source == main.destroyAll then
		triggerServerEvent("destroyVehiclesFromOwner", localPlayer)
		setClickTimer()
	elseif source == main.frozen then
		if selectedID then
			triggerServerEvent("frozenVehicleFromID", localPlayer, selectedID)
			setClickTimer()
		end
	elseif source == main.lock then
		if selectedID then
			triggerServerEvent("lockedVehicleFromID", localPlayer, selectedID)
			setClickTimer()
		end
	elseif source == main.delete then
		if selectedID then
			destroy.data.ID = selectedID
			guiSetText(destroy.label, "Maşını həqiqətən satmaq istəyirsən?\nSatdıqdan sonra pul geri qaytarılmayacaq və maşını bərpa etmək mümkün olmayacaq!")
			guiSetVisible(destroy.window, true)
			guiSetVisible(main.window, false)
		end
	elseif source == main.sell then
		if selectedID then
			sell.carID = selectedID
			sell.carName = guiGridListGetItemText(main.grid, selectedRow, 2)
			sell.carPlate = guiGridListGetItemText(main.grid, selectedRow, 3)
			guiSetVisible(main.window, false)
			openSell()
			setClickTimer()
		end
	elseif source == destroy.yes then
		if destroy.data.ID then
			triggerServerEvent("deleteVehiclePermanently", localPlayer, destroy.data.ID)
			guiSetVisible(destroy.window, false)
			showCursor(false)
		end
	elseif source == destroy.no then
		guiSetVisible(destroy.window, false)
		showMainWindow(true)
	end
end)
