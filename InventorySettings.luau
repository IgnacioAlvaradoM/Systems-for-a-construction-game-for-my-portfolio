-- Connected Discord-GitHub

-- Discord user name: ignacio_alvarado
-- Roblox user name: Ignayep

-- This script contains some of the following concepts:
-- Client-Server Interaction
-- Use of CFrames
-- Use of Roblox Studio objects: viewportFrames, Frames, Text Labels, Text Buttons, etc..
-- Use of services to detect user input: UserInputService, ContextActionService
-- Use of modules (createds by me)
-- Connections cleanup
-- And more...

-- Funcion de este Script dentro del juego:
--[[This script adds the blocks/objects that the player possesses in their DataStore and "creates" them, so to
speak. It adds them to their inventory so they can be seen, and adds the necessary functionalities so they can
be selected from the inventory and removed from the user interface at the bottom of the screen. It also includes
the functionality that allows the user to select a block/item so they can start building or place that block/item
and sends the signals to start the construction, such as when the user wants to build a specific block/item, the
signal to place the block/item, the signal to open or close the inventory, and the signals to rotate the
block/item around the axis the user desires. This script also updates the number of blocks/elements that the
user has so they can see them]]

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
local playerItems: Folder = player:WaitForChild("Items") --[[A folder created when loading player data, containing the items owned by
															the player, represented by a NumberValue for each block/item]]
local items: Folder = game.Workspace:WaitForChild("Items") --[[Reference to a folder located in the Workspace that contains
															  all current game items]]

local openBackpackButtonActivatedConnections = {}
local takenViewports = {}
local blockEquipped = {}
local buildConnections = {}

local actuallyItemOnBuild: any = nil
local playerOnBuild: boolean = false

task.wait(0.1)
--[[This function is connected to the "Activated" event of a text button and is used to open or close the inventory via the button,
which would be the button located in the UI at the bottom of the screen, at the far right, and which has the text "E" in the upper
right corner]]

eButton.Activated:Connect(function(inputObject: InputObject, clickCount: number) 
	openOrCloseInventory:FireServer() --[[We call a function from a module created by me that is responsible for making the player's
	inventory visible or invisible, from the server.]]
end)

--[[This function is connected to the "InputBegan" event of the "userInputService" service, which is triggered when the user interacts
with an input device such as a mouse or gamepad. It is used to receive the signal from the "E" key, that is, when the player presses
the "E" key to open or close the inventory]]

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean) 
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if gameProcessedEvent then return end
	openOrCloseInventory:FireServer() --[[We call the function of a module created by me that is responsible for making the player's
	inventory visible or invisible, from the server]]
end)

--[[This function creates the list of items the player has available in their inventory, allowing them to view them and manage their
settings (select, remove)]]
local function creatingItemsInThePlayerInventory()
	-- Cycle to cycle through the items the player has available and add them to their inventory so they can be selected
	for _, numberValue: NumberValue in pairs(playerItems:GetChildren()) do -- numberValue (name = item name, .Value = number of block(s)/item(s))
		local Item = nil
		for _, item in pairs(items:GetChildren()) do --[[We look for the instance/reference of the item object in the folder that contains
	all the game items using the name of the current numberValue, since there is a numberValue for each different item that
	the player owns (use a numberValue to also keep track of the number of blocks/items the player owns, storing it in
	its numberValue.Value property)]]
			print(item.Name)
			if numberValue.Name == item.Name  then
				Item = item
			end
		end
	--[[We use a ViewportFrame, a camera to add the block/item to the inventory so the player can see it, and a textLabel to indicate
		the number of blocks/items the player has. We also use a text button so the player can tap the block/item to select and add
		it to the UI at the bottom of the screen. Within this loop, we will also configure and add the ability for this to happen when
		the player taps the button]]
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
		-- To create a shadow effect when the player moves the mouse over an item in the inventory
		buttonText.MouseEnter:Connect(function(x: number, y: number) 
			buttonText.BackgroundTransparency = 0.8
		end)

		buttonText.MouseLeave:Connect(function(x: number, y: number) 
			buttonText.BackgroundTransparency = 1
		end)
	--[[ When the button text is activated, that is, when the player selects an item from the inventory, this function is responsible
	for sending the item to one of the viewport frames or buttons in the UI at the bottom of the screen. This allows the player to
	view and interact with it in the UI at the bottom of the screen]]
		buttonText.Activated:Connect(function(inputObject: InputObject, clickCount: number) 
			--[[We use a loop to find a viewportFrame that is not "Taken", that is, one that does not already have an item/block]]
			for _, viewportFrame in ipairs(buttonsFrame:GetChildren()) do
				if not viewportFrame:IsA("ViewportFrame") then continue end --[[We verify that it is a viewportFrame; if not, we
				continue with the next cycle.]]
				local taken: boolean = viewportFrame:GetAttribute("Taken") --[[We obtain the viewportFrame attribute that will tell
				us whether the viewportFrame is "Taken"]]
				if taken then continue end --[[We verify that the viewportframe is not "Taken," that is, that it does not already
				contain a block/item]]
				if blockEquipped[Item.Name] then return end --[[We check if the block/item is already equipped; this is to avoid
				equipping more than one block of the same type.]]

				if numberValue.Value == 0  then -- We verify that the player has blocks to build with.
					return warn("Player does not have enough blocks to build.")
				end
				--[[Here we set the object as equipped and the viewport frame as taken, and we create a clone of the current element,
				as well as a camera. We then look for an existing text button to display the element in the UI below the screen in the
				corresponding viewport frame. Through this button, we will link a function either to remove it from the UI below the
				screen or to select it so we can build with that block/item]]
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
				--[[ We activate the button we just created and store the connection of a function connected to the "Activated" event of
				the button in a variable. The function will then remove the item from the current viewport frame to remove it from the
				UI below the screen]]
				takenViewports[viewportFrame] = button --[[We store in a table the instance/reference of the viewportFrame object along
				with the button corresponding to its key or location]]

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
			--[[ We store the variable containing the connection for the button's activation event so we can access that connection and
			disconnect it within the function previously connected to the button's "Activated" event, line 154, and on line 155 we
			remove it from the table/dictionary]]
				openBackpackButtonActivatedConnections[button.Name] = openBackpackButtonActivatedConnection
				--[[This function performs the same function as the previous one, but instead of being activated by a connection linked
				to a button's "Activated" event, it will be activated by pressing a key. In this case, the key corresponds to the
				numeric value (excluding the letter "E") displayed in the upper right corner of each window of the graphical user
				interface, below the screen]]
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
					ContextActionService:UnbindAction("MoveToInventory"..button.Name)
				end
				--[[Here we link the previous onMoveToInventory() function to a key, through the "ContextActionService". The key
				corresponds to the number displayed in the upper right corner of each viewportFrame in the user interface below the
				screen (I named each button according to the key displayed in the upper right corner of its viewportFrame)]]
				ContextActionService:BindAction("MoveToInventory"..button.Name, onMoveToInventory, false,Enum.KeyCode[button.Name])
				return
			end
		end)
		--[[ Here we update the value that indicates how many blocks or elements the player has of the current element, each time the
		value of the .Value property of numberValue changes with a function connected to the "Changed" event that is triggered when the
		.Value property of numberValue changes]]
		numberValue.Changed:Connect(function(value)
			textLabel.Text = numberValue.Value
		end)
	end
end

--[[We access the event that is triggered when the "Visible" property of a Frame called "backPackFrame" changes, which will tell us when
the player opens or closes the inventory]]

backPackFrame:GetPropertyChangedSignal("Visible"):Connect(function(...) 
	if backPackFrame.Visible == true  then --[[When the player opens their inventory, we'll check for any building connections. These
	are connections that allow the user to place a block/item. If any are found, we'll disconnect them]]
		if next(buildConnections) ~= nil  then
			print("desconectando conexiones")
			--[[We use a loop in the "buildConnections" table/dictionary, which contains the connections that allow the user to place a
			block/item by pressing a button, and we disconnect them. We also unlink the functions that perform the same function as the
			previously disconnected functions, but these are activated by pressing a key through the "ContextActionService"]]
			for buttonName: string, connection: RBXScriptConnection in pairs(buildConnections) do
				connection:Disconnect()
				--buildConnections[buttonName] = nil
				ContextActionService:UnbindAction("Build"..buttonName)
			end
		end
		--[[We will check if the player has any blocks selected, which would indicate that they are displayed in the UI at the bottom of
		the screen. If so, we will locate the viewport frame and the corresponding button for that block/object and connect the functions
		that allow the block/object to return to the inventory. These connections are created when the player opens the inventory and
		selects a block/object, and are removed when the inventory is closed. Therefore, if we don't create them now, the player will
		not be able to return any blocks/objects they have selected or that are displayed in the UI at the bottom of the screen after
		opening the inventory with selected blocks/objects]]
		if next(takenViewports) ~= nil then
			--[[Using a loop, we iterate through the "takenViewports" table/dictionary and create the connections that allow the player
			to remove the block(s)/item(s) by pressing a button or key for each viewportframe in the table, that is, for each
			block/element that the player has selected or has in the UI below the screen]]
			for viewportFrame, button in pairs(takenViewports) do
				--[[Function that removes the user interface block from the bottom of the screen, which will be called when the
				"Activated" event of the corresponding button text is triggered]]
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
				-- Function that removes a block of the UI from the bottom of the screen
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
				--[[We link the previous function to a key through the "ContextActionService" so that when it is pressed, it is called]]
				ContextActionService:BindAction("MoveToInventory"..button.Name, OnMoveToInventory, false,Enum.KeyCode[button.Name])
			end
		end
	else --[[ When the player closes the inventory, we will check if there are any connections to the functions that remove the
	block/item from the user interface at the bottom of the screen, to disconnect and remove them from the table/dictionary and/or
	unlink them from the "ContextActionService". We will then connect the functions that will allow the player to place a block. The
	function connected to the "Activated" event of the button is so that if the player clicks the left button to open the viewport
	frame where the selected element/block is displayed, this functionality will be enabled. The function linked to user input, in
	this case the key corresponding to the viewport frame where the block/item is located, via the "ContextActionService", performs
	the same function as the previous one, except that it is activated by a key]]
		if next(openBackpackButtonActivatedConnections) ~= nil then
			--[[With a for loop, we iterate thru the "takenViewports" table/dictionary to first disconnect and unlink the functions
			that allow the player to remove the block(s)/item(s) from the UI at the bottom of the screen and we will connect the
			functions that will allow the player to place a block]]
			for viewportFrame, button in pairs(takenViewports) do
				openBackpackButtonActivatedConnections[button.Name]:Disconnect()
				openBackpackButtonActivatedConnections[button.Name] = nil
				ContextActionService:UnbindAction("MoveToInventory"..button.Name)
				--[[This function allows the player to build or place a block in the location where they left-click or press. We connect
				it to the "Activated" event of the text button located below the viewportFrame where the block/object is displayed so
				that this functionality works when pressing the viewport.Frame where the block/element the player wants to build or
				place is located, and we store it in a variable]]
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
				--[[We store the variable that contains the previous connection in a table so that we can access it and disconnect it
				when we need to]]
				buildConnections[button.Name] = buildBottonActivatedConnection
				--[[This function does the same as the previous one, but it adds the function bindings to the corresponding keys to
				rotate the block/element]]
				local function buildOn(actionName, inputState, _inputObject)
					if actionName ~= "Build"..button.Name then return end
					if inputState ~= Enum.UserInputState.Begin then return end
					print(" a construir")
					if playerOnBuild  then
						print("PlayerConstruyendo")
						if actuallyItemOnBuild.Name == viewportFrame.Name  then
							print("Mismo Bloque")
							BuildModule.unbuiltItem()
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
				--[[We bind the previous function to the corresponding key shown at the top right of the current viewportFrame so that
				this functionality also executes when a key is pressed, in this case, the corresponding key shown at the top right of
				the current viewportFrame]]
				ContextActionService:BindAction("Build"..button.Name, buildOn, false,Enum.KeyCode[button.Name])
			end
		end
	end
end)

function onBuildRotation(actionName, inputState, _inputObject) -- Function to rotate the block/element
	if actionName == "RotateItemZ" or actionName == "RotateItemX" or actionName == "RotateItemY" then -- We verify which axis the user wants to rotate
		if inputState == Enum.UserInputState.Begin then -- We check if the status of the entry is of type "Begin"
			local eje: string = string.gsub(actionName,"RotateItem","")
			BuildModule.rotateItem(eje) -- We call the function of a module I created to rotate the item on that axis by 15 degrees
		else
			return
		end
	else
		return
	end
end

function onBuildClickPress(actionName, inputState, _inputObject) -- Function to place the block/item
	if actionName ~= "PlaceItem" then return end -- We verify that the name of the action is correct
	if inputState ~= Enum.UserInputState.Begin then return end -- We check if the status of the entry is of type "Begin"
	BuildModule.placeItem() --[[We call a function from a module I created that will take care of placing the block.
	in the world at the point where the player clicked]]
	playerOnBuild = false -- We establish that the player is no longer in "build" mode or is not building any block/item
	ContextActionService:UnbindAction("PlaceItem") --[[We unlink the functions corresponding to the actions of placing an element and
	rotating it on the corresponding axis]]
	ContextActionService:UnbindAction("RotateItemZ")
	ContextActionService:UnbindAction("RotateItemY")
	ContextActionService:UnbindAction("RotateItemX")
end

-- Functions called

creatingItemsInThePlayerInventory()