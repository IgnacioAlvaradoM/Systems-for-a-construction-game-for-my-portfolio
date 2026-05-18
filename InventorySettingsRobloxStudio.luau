-- Services

local Players: Players, ReplicatedStorage: ReplicatedStorage = game:GetService("Players"), game:GetService("ReplicatedStorage")
local UserInputService: UserInputService, ContextActionService: ContextActionService = game:GetService("UserInputService"), game:GetService("ContextActionService")
local ReplicatedFirst: ReplicatedFirst = game:GetService("ReplicatedFirst")

-- Modules

local NetworkManagerClient = require(ReplicatedFirst:WaitForChild("NetworkManagerClient"))
local BuildModule = require(ReplicatedFirst:WaitForChild("BuildModule"))

-- Events

local openOrCloseInventory: RemoteEvent = ReplicatedStorage:WaitForChild("OpenOrCloseInventory")

-- Assets

local player: Player = Players.LocalPlayer
local character: Model = player.Character or player.CharacterAdded:Wait(0)
local camera: Camera = game.Workspace.CurrentCamera
local mouse: Mouse = player:GetMouse()
local inventoryGui: ScreenGui = script:FindFirstAncestorOfClass("ScreenGui")
local backPackFrame: Frame = inventoryGui:WaitForChild("BackPackFrame")
local buttonsFrame: Frame = inventoryGui:WaitForChild("ButtonsFrame")
local eViewportFrame: ViewportFrame = buttonsFrame:WaitForChild("E")
local eButton: TextButton = eViewportFrame:WaitForChild("E")
local onBuild: Folder = game.Workspace:WaitForChild("OnBuild")
local playerItems: Folder = player:WaitForChild("Items") --[[carpeta que se crea al cargar los datos del jugador y contiene los items
														   que este posee representado por un numberValue para cada bloque/item]]
local items: Folder = game.Workspace:WaitForChild("Items") --[[Referencia a una carpeta que se encuentra en el Workspace que contiene
															 todos los items actuales del juego]]

local openBackpackButtonActivatedConnections = {}
local takenViewports = {}
local blockEquipped = {}
local buildConnections = {}

local actuallyItemOnBuild: any = nil
local playerOnBuild: boolean = false

task.wait(0.1)
--[[Esta funcion esta conectada al evento "Activated" de un button text y sirve para abrir o cerrar el inventario a traves del boton, 
que seria el boton ubicado en la UI de abajo de la pantalla y que se encuentra al final a la derecha y que tiene 
en la esquina superior derecha el texto "E"]]

eButton.Activated:Connect(function(inputObject: InputObject, clickCount: number) 
	openOrCloseInventory:FireServer()
end)

--[[esta funcion esta conectada al evento "InputBegan" del servicio "userInputService"
que se activa cuando el usuario interactua con un dispositivo de entrada como un ráton 
o gamepad, se utiliza para recibir la señal de la tecla "E", es decir, cuando el jugador
aprieta la tecla "E", para abrir o cerrar el inventario]]

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean) 
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if gameProcessedEvent then return end
	openOrCloseInventory:FireServer()	
end)

--[[Funcion que se encargara de crear los items que el jugador tenga en su inventario disponibles, para que los pueda visualizar en su
inventario mas sus configuraciones (seleccionar, remover)]]
local function creatingItemsInThePlayerInventory()
	-- Ciclo para recorrer los items que el jugador tiene disponibles y añadirlos a su inventario para que los pueda seleccionar
	for _, numberValue: NumberValue in pairs(playerItems:GetChildren()) do -- numberValue (nombre = nombre del item, .Value =  cantidad de bloque(s)/item(s))
		local Item = nil
		for _, item in pairs(items:GetChildren()) do --[[Buscamos la instancia/referencia del objeto del item, en la carpeta que contiene 
		todos los items del juego a traves del nombre del numberValue actual,ya que existe un numberValue para cada item diferente que
		el jugador posea (utilice un numberValue para tambien tener la cantidad de bloques/items que el jugador posee, guardandolo en
		su propiedad numberValue.Value)]]
			print(item.Name)
			if numberValue.Name == item.Name  then
				Item = item
			end
		end
	--[[Utilizamos un ViewportFrame, una Camara para añadir el bloque/item al inventario y que el jugador lo pueda visualizar ademas de
	un textLabel para indicar la cantidad de bloques/Items que el jugador posee y un button text para que el jugador pueda
	apretar el bloque/item para que lo pueda seleccionar y añadir a la UI de abajo de la pantalla, dentro de este ciclo for tambien
	configuraremos y añadiremos la capacidad para que esto suceda cuando el jugador apriete el boton]]
		local blockViewportFrame = Instance.new("ViewportFrame", backPackFrame.Items)
		blockViewportFrame.Name = Item.Name
		local itemClon = Item:Clone()
		itemClon.Parent = blockViewportFrame
		local viewportCamera = Instance.new("Camera")
		viewportCamera.FieldOfView = 20
		viewportCamera.Parent = blockViewportFrame
		blockViewportFrame.CurrentCamera = viewportCamera
		viewportCamera.CFrame = itemClon.CFrame * CFrame.Angles(0,math.rad(45),0) * CFrame.new(0,0,20)
		local textLabel: TextLabel = Instance.new("TextLabel",blockViewportFrame)
		textLabel.AnchorPoint = Vector2.new(0.5,0.5)
		textLabel.Size = UDim2.new(0.2,0,0.2,0)
		textLabel.Position = UDim2.new(0.9,0,0.11,0)
		textLabel.Text = numberValue.Value
		textLabel.BackgroundTransparency = 1
		textLabel.TextScaled = true
		local buttonText = Instance.new("TextButton", blockViewportFrame)
		buttonText.Size = UDim2.new(1,0,1,0)
		buttonText.Text = ""
		buttonText.BackgroundTransparency = 1
		-- para crear un efecto de sombra cuando el jugador mueve el mouse por encima de un item en el inventario
		buttonText.MouseEnter:Connect(function(x: number, y: number) 
			buttonText.BackgroundTransparency = 0.8
		end)

		buttonText.MouseLeave:Connect(function(x: number, y: number) 
			buttonText.BackgroundTransparency = 1
		end)
	--[[ Cuando se activa el button text, es decir, el jugador selecciona un objeto del inventario, esta funcion se 
	encarga de enviar el objeto a uno de los viewportFrames o botones de la UI de abajo de la pantalla
	para que el jugador pueda visualizarlo en la UI de abajo de la pantalla y interactuar con él]]
		buttonText.Activated:Connect(function(inputObject: InputObject, clickCount: number) 
			--[[Utilizamos un ciclo for para encontrar un viewportFrame que no este "Taken", es decir, que no tenga ya un item/bloque]]
			for _, viewportFrame in ipairs(buttonsFrame:GetChildren()) do
				if not viewportFrame:IsA("ViewportFrame") then continue end --[[Verificamos que sea un viewportFrame, si no es asi
			continuamos con el siguiente ciclo]]
				local taken: boolean = viewportFrame:GetAttribute("Taken") --[[Obtenemos el atributo del viewportFrame que nos indicara
			si el viewportFrame esta "Tomado"]]
				if taken then continue end --[[Verificamos que el viewportFrame no este "Tomado", es decir,
			que no contenga ya un bloque/Item]]
				if blockEquipped[Item.Name] then return end --[[Verificamos si el bloque/Item esta equipado ya, esto es para no equipar
			mas de un bloque del mismo tipo]]

				if numberValue.Value == 0  then -- Verificamos que el jugador tenga bloques para construir
					return warn("Jugador no tiene suficientes bloques para construir")
				end
			--[[Aqui establecemos el objeto como equipado y el viewportFrame como tomado y creamos un clon
			del item actual ademas de una camara y buscamos un button text ya creado, para visualizar el item en la UI de abajo de
			la pantalla en el viewportFrame correspondiente y a traves del boton enlazaremos una funcion ya sea para poder removerlo
			de la UI de abajo de la pantalla o seleccionarlo para poder construir con ese bloque/item]]
				blockEquipped[Item.Name] = true
				viewportFrame:SetAttribute("Taken", true)
				local itemClon = Item:Clone()
				itemClon.Parent = viewportFrame
				viewportFrame.Name = itemClon.Name
				local viewportCamera = Instance.new("Camera")
				viewportCamera.FieldOfView = 20
				viewportCamera.Parent = viewportFrame
				viewportFrame.CurrentCamera = viewportCamera	
				viewportCamera.CFrame = itemClon.CFrame * CFrame.new(0,0,20)
				local button: TextButton = viewportFrame:FindFirstChildOfClass("TextButton")
				button.Active = true
			--[[ Activamos el boton que acabamos de crear y almacenaremos la conexion de una funcion conectada al evento "Activated"
			del boton en una variable, la funcion ara que sacara el item del viewportFrame actual para quitarlo de la UI de abajo
			de la pantalla]]
				takenViewports[viewportFrame] = button --[[Guardamos en una tabla la instancia/referencia del objeto viewportFrame junto al
			boton correspondiente a su tecla o ubicacion]]

				local openBackpackButtonActivatedConnection: RBXScriptConnection = button.Activated:Connect(function()
					print("Boton apretado")
					itemClon:Destroy()
					viewportCamera:Destroy()
					button.Active = false
					viewportFrame:SetAttribute("Taken", false)
					blockEquipped[itemClon.Name] = nil
					openBackpackButtonActivatedConnections[button.Name]:Disconnect()
					openBackpackButtonActivatedConnections[button.Name] = nil
					takenViewports[viewportFrame] = nil
					ContextActionService:UnbindAction("MoveToInventory"..button.Name)
				end)
			--[[ almacenamos la variable que almacena la conexion del evento activated del boton para poder acceder a la conexion y
			poder desconectarla dentro de la funcion anteriormente conectada al evento "Activated" del boton]]
				openBackpackButtonActivatedConnections[button.Name] = openBackpackButtonActivatedConnection
			--[[esta funcion realiza lo mismo que la anterior pero en vez de ser llamada a traves de una conexion conectada al evento
			"Activated" de un boton se llamara al apretar una tecla, en este caso la tecla deberia corresponder al "numero"
			mostrado arriba a la derecha de cada viewportFrame de la UI de abajo de la pantalla]]
				local function onMoveToInventory(actionName, inputState, _inputObject)
					if actionName ~= "MoveToInventory"..button.Name then return end
					if inputState ~= Enum.UserInputState.Begin then return end
					print("Moviendo bloque")
					itemClon:Destroy()
					viewportCamera:Destroy()
					button.Active = false
					viewportFrame:SetAttribute("Taken", false)
					blockEquipped[itemClon.Name] = nil
					openBackpackButtonActivatedConnections[button.Name]:Disconnect()
					openBackpackButtonActivatedConnections[button.Name] = nil
					takenViewports[viewportFrame] = nil
					ContextActionService:unbindAction("MoveToInventory"..button.Name)
				end
			--[[Aqui vinculamos la funcion anterior onMoveToInventory() a una tecla, a traves del servicio "ContextActionService",
			la tecla deberia corresponder al "numero" mostrado arriba a la derecha de cada viewportFrame de la UI de abajo 
			de la pantalla (le coloque a cada button text, como nombre la tecla mostrada en la parte de arriba ala derecha de su
			vieportFrame)]]
				ContextActionService:BindAction("MoveToInventory"..button.Name, onMoveToInventory, false,Enum.KeyCode[button.Name])
				return
			end
		end)
	--[[ Aqui cambiamos el valor que indica la cantidad de cuantos bloques o items tiene el jugador del item actual, cada vez por asi
	decirlo que se actualize el valor de la propiedad .Value del numberValue con una funcion conectada al evento "Changed" que se 
	activa cuando cambia la propiedad .Value del numberValue]]
		numberValue.Changed:Connect(function(value)
			textLabel.Text = numberValue.Value
			--local playerItems: Folder = player:FindFirstChild("Items")

		--[[for _, numberValue in pairs(playerItems:GetChildren()) do
			if numberValue.Name == Item.Name then
				for viewportFrame, button in pairs(takenViewports) do
					if viewportFrame.Name == numberValue.Name then
						local blockClon = viewportFrame:FindFirstChild(viewportFrame.Name)
						local viewportCamera: Camera = viewportFrame:FindFirstChildOfClass("Camera")
						blockClon:Destroy()
						viewportCamera:Destroy()
						button.Active = false
						viewportFrame:SetAttribute("Taken", false)		
						blockEquipped[blockClon.Name] = nil
						takenViewports[viewportFrame] = nil
						ContextActionService:UnbindAction("MoveToInventory"..button.Name)
					end
				end
			end
		end]]
		end)
	end
end

--[[Accedemos al evento que se activa cuando cambia la propiedad "Visible" de un Frame llamado "backPackFrame" que nos indicara cuando
el jugador abre o cierra el inventario]]

backPackFrame:GetPropertyChangedSignal("Visible"):Connect(function(...) 
	if backPackFrame.Visible == true  then --[[Cuando el jugador abre el inventario, verificaremos si hay conexiones de construccion,
	es decir, conexiones que hagan que el usuario pueda colocar un bloque/item, si las hay las desconectaremos]]
		if next(buildConnections) ~= nil  then
			print("desconectando conexiones")
			--[[Utilizamos un ciclo for en la tabla/diccionario "buildConnections" que contiene las conexiones que hacen que el usuario
			pueda colocar un bloque/item a traves de apretar un boton y las desconectamos y tambien desvinculamos las funciones que
			realizan lo mismo que las funciones desconectadas anteriormente pero que estas se activan al apretar una tecla a traves del
			servicio de "ContextActionService"]]
			for buttonName: string, connection: RBXScriptConnection in pairs(buildConnections) do
				connection:Disconnect()
				--buildConnections[buttonName] = nil
				ContextActionService:UnbindAction("Build"..buttonName)
			end
		end
		--[[verificaremos
		si el jugador tiene algun bloque seleccionado y por tanto se encuentra en la UI de abajo de la pantalla, si es asi, buscaremos
		el viewportFrame y boton correspondiente de ese bloque/Item y conectaremos las funciones que hacen que el bloque/item se
		devuelva al inventario, ya que estas conexiones se crean cuando el jugador abre el inventario y selecciona un bloque/item y
		cuando cierra el inventario se eliminan, por tanto si nos las creamos ahora el jugador no podra devolver los bloques/Items
		que tiene seleccionado o que tiene en la UI de abajo de la pantalla]]
		if next(takenViewports) ~= nil then
			--[[Con un ciclo for recorremos la tabla/diccionario "takenViewports" y creamos las conexiones que permiten que el jugador
			pueda remover los bloque(s)/items(s) a traves de apretar un boton o una tecla por cada viewportFrame en la tabla, es decir,
			por cada bloque/item que el jugador tenga seleccionado o tenga en la UI de abajo de la pantalla]]
			for viewportFrame, button in pairs(takenViewports) do
				--[[Funcion que remueve el bloque de la UI de abajo de la pantalla, que se llamara cuando se active el evento "Activated"
				de un button text]]
				local openBackpackButtonActivatedConnection: RBXScriptConnection = button.Activated:Connect(function()
					local blockClon = viewportFrame:FindFirstChild(viewportFrame.Name)
					local viewportCamera: Camera = viewportFrame:FindFirstChildOfClass("Camera")
					blockClon:Destroy()
					viewportCamera:Destroy()
					button.Active = false
					viewportFrame:SetAttribute("Taken", false)		
					blockEquipped[blockClon.Name] = nil
					openBackpackButtonActivatedConnections[button.Name]:Disconnect()
					openBackpackButtonActivatedConnections[button.Name] = nil
					takenViewports[viewportFrame] = nil
					ContextActionService:UnbindAction("MoveToInventory"..button.Name)
				end)

				openBackpackButtonActivatedConnections[button.Name] = openBackpackButtonActivatedConnection
				-- Funcion que remueve el bloque de la UI de abajo de la pantalla
				local function OnMoveToInventory(actionName, inputState, _inputObject)
					if actionName ~= "MoveToInventory"..button.Name then return end
					if inputState ~= Enum.UserInputState.Begin then return end
					print("Moviendo bloque")
					local blockClon = viewportFrame:FindFirstChild(viewportFrame.Name)
					local viewportCamera: Camera = viewportFrame:FindFirstChildOfClass("Camera")
					blockClon:Destroy()
					viewportCamera:Destroy()
					button.Active = false
					viewportFrame:SetAttribute("Taken", false)		
					blockEquipped[blockClon.Name] = nil
					openBackpackButtonActivatedConnections[button.Name]:Disconnect()
					openBackpackButtonActivatedConnections[button.Name] = nil
					takenViewports[viewportFrame] = nil
					ContextActionService:UnbindAction("MoveToInventory"..button.Name)
				end
				--[[Vinculamos la funcion anterior a una tecla a traves del servicio "ContextActionService" para cuando esta se
				aprete sea llamada]]
				ContextActionService:BindAction("MoveToInventory"..button.Name, OnMoveToInventory, false,Enum.KeyCode[button.Name])
			end
		end
	else --[[ Cuando el jugador cierra el inventario verificaremos si se encuentra alguna conexion conectadas a las funciones que
		remueven el bloque/item de la interfaz de usuario de abajo de la pantalla, para desconectarlas y removerlas de la 
		tabla/diccionario y/o desvincularlas del servicio "ContextActionService" y conectaremos las funciones que aran que el
		jugador pueda colocar un bloque, la funcion conectada al evento "Activated" del boton es para que si el jugador realiza
		click izquierdo o aprieta el viewportFrame donde se visualiza el item/bloque que selecciono
		tengan esta funcionalidad y la funcion vinculada a una entrada del usuario en este caso la tecla correspondiente al
		viewportFrame donde se encuentra el bloque/item a traves del servicio "ContextActionService", realiza lo mismo que
		la funcion anterior solo que se activa a traves de una tecla]]
		if next(openBackpackButtonActivatedConnections) ~= nil then
			--[[Con un ciclo for recorremos la tabla/diccionario "takenViewports" para primeramente desconectar y desvincular las
			funciones que hacen que el jugador pueda remover los bloque(s)/item(s) de la UI de abajo de la pantalla y conectaremos
			las funciones que aran que el jugador pueda colocar un bloque]]
			for viewportFrame, button in pairs(takenViewports) do
				openBackpackButtonActivatedConnections[button.Name]:Disconnect()
				openBackpackButtonActivatedConnections[button.Name] = nil
				ContextActionService:UnbindAction("MoveToInventory"..button.Name)
				--[[Esta funcion hace que el jugador pueda construir o colocar un bloque en el lugar donde realice click izquierdo
				o presione, la conectamos al evento "Activated" del button text que se encuentra debajo de el viewportFrame donde se
				visualiza el bloque/item para que esta funcionalidad funcione al apretar el viewportFrame donde se encuentre el
				bloque/item que el jugador desea construir o colocar y la almacenamos en una variable]]
				local buildBottonActivatedConnection = button.Activated:Connect(function(inputObject: InputObject, clickCount: number)
					print("para construir")
					if playerOnBuild  then
						if actuallyItemOnBuild.Name == viewportFrame.Name  then
							BuildModule.unbuiltItem()
							playerOnBuild = false
							return
						end
						BuildModule.unbuiltItem()
					end
					NetworkManagerClient.FireServer("ItemOnBuild",viewportFrame.Name)
					local onBuildPlayerFolder: Folder = onBuild:WaitForChild(player.Name)
					local currentItemOnBuild = onBuildPlayerFolder:WaitForChild(viewportFrame.Name,1)
					if currentItemOnBuild == nil then return end
					local flecha3D = onBuildPlayerFolder:FindFirstChild("Flecha3D")
					BuildModule.build(currentItemOnBuild, mouse, camera)
					playerOnBuild = true
					actuallyItemOnBuild = currentItemOnBuild
					ContextActionService:BindAction("PlaceItem", onBuildClickPress, false, Enum.UserInputType.MouseButton1)
					--ContextActionService:BindAction("RotateItem", onBuildRotation, true)
				end)
				--[[Almacenamos la variable que contiene la conexion anterior en una tabla para poder acceder a ella y desconectarla
				cuando lo necesitemos]]
				buildConnections[button.Name] = buildBottonActivatedConnection
				--[[Esta funcion realiza lo mismo que la anterior, solo que se le agregan las vinculaciones de las funciones a las
				teclas correspondientes para rotar el bloque/Item]]
				local function buildOn(actionName, inputState, _inputObject)
					if actionName ~= "Build"..button.Name then return end
					if inputState ~= Enum.UserInputState.Begin then return end
					print(" a construir")
					if playerOnBuild  then
						print("PlayerConstruyendo")
						if actuallyItemOnBuild.Name == viewportFrame.Name  then
							print("Mismo Bloque")
							BuildModule.UnbuiltItem()
							playerOnBuild = false
							actuallyItemOnBuild = nil
							return
						end
						BuildModule.unbuiltItem()
					end
					NetworkManagerClient.FireServer("ItemOnBuild",viewportFrame.Name)
					local onBuildPlayerFolder: Folder = onBuild:WaitForChild(player.Name)
					local currentItemOnBuild = onBuildPlayerFolder:WaitForChild(viewportFrame.Name,1)
					if currentItemOnBuild == nil then return end
					BuildModule.build(currentItemOnBuild, mouse, camera)
					playerOnBuild = true
					actuallyItemOnBuild = currentItemOnBuild
					ContextActionService:BindAction("PlaceItem", onBuildClickPress, false, Enum.UserInputType.MouseButton1)
					ContextActionService:BindAction("RotateItemX", onBuildRotation,false, Enum.KeyCode.R)
					ContextActionService:BindAction("RotateItemZ", onBuildRotation,false, Enum.KeyCode.Q)
					ContextActionService:BindAction("RotateItemY", onBuildRotation,false, Enum.KeyCode.Z)
				end
				--[[Vinculamos la funcion anterior a la tecla correspondiente que se muestra arriba a la derecha del viewportFrame
				actual para que esta funcionalidad tambien se ejecute cuando se aprieta una tecla, en este caso la tecla correspondiente
				que se muestra arriba a la derecha del viewportFrame actual]]
				ContextActionService:BindAction("Build"..button.Name, buildOn, false,Enum.KeyCode[button.Name])
			end
		end
	end
end)

function onBuildRotation(actionName, inputState, _inputObject) -- Funcion para rotar el bloque/item
	if actionName == "RotateItemZ" or actionName == "RotateItemX" or actionName == "RotateItemY" then -- Verificamos que eje se rotara
		if inputState == Enum.UserInputState.Begin then -- Verificamos si el estado de la entrada, es de tipo "Begin"
			local eje: string = string.gsub(actionName,"RotateItem","")
			BuildModule.rotateItem(eje) -- Llamamos a la funcion de un modulo que cree para que rote el item en ese eje en 45 grados
		else
			return
		end
	else
		return
	end
end

function onBuildClickPress(actionName, inputState, _inputObject) -- Funcion para colocar el bloque/item
	if actionName ~= "PlaceItem" then return end -- Verficamos que el nombre de la accion sea el correspondiente
	if inputState ~= Enum.UserInputState.Begin then return end -- Verificamos si el estado de la entrada, es de tipo "Begin"
	BuildModule.placeItem() --[[Llamamos a una funcion de un modulo que cree que se encargara de poner el bloque
	en el mundo en el punto donde el jugador le dio click]]
	playerOnBuild = false -- Establecemos que el jugador ya no esta en modo "construccion" o no esta construyendo ningun bloque/item
	ContextActionService:UnbindAction("PlaceItem") --[[Desvinculamos las funciones correspondientes a las acciones de colocar un item
	y de rotacion en el eje correspondiente]]
	ContextActionService:UnbindAction("RotateItemZ")
	ContextActionService:UnbindAction("RotateItemY")
	ContextActionService:UnbindAction("RotateItemX")
end

-- Functions called

creatingItemsInThePlayerInventory()