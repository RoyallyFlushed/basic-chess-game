
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionRemote = ReplicatedStorage.SessionRemote
local TurnRemote = ReplicatedStorage.TurnRemote
local UI = script.Parent.Parent
local chessButton = UI.ChessButton
local status = UI.Status

local sessionPlayers = 0

local teams = {
	BLACK = 1,
	WHITE = 2,
}

local playerColor = 0
local currentTurn = 0


chessButton.MouseButton1Click:Connect(function()
	SessionRemote:FireServer()
end)

SessionRemote.OnClientEvent:Connect(function(Data)
	if Data.PlayerCount then
		sessionPlayers = Data.PlayerCount
		
		status.Text = "Players: "..sessionPlayers
		
		if sessionPlayers == 2 then
			chessButton.Text = "Start"
		end
	elseif Data.CountdownBegin then
		if sessionPlayers == 2 then 
			chessButton.Visible = false

			for i = 3, 1, -1 do
				status.Text = "Starting in: "..i
				wait(1)
			end

			status.Text = "Starting..."
			wait(1)
			
			SessionRemote:FireServer()
		end
	end
end)


local function displayMoveColor(currentSquareData)
	local square = currentSquareData.Square
	local brickColorObject = square.brick_color_holder
	
	if brickColorObject.Value == BrickColor.new("Reddish brown") then
		square.BrickColor = BrickColor.new("Bright green")
	elseif brickColorObject.Value == BrickColor.new("Pastel brown") then
		square.BrickColor = BrickColor.new("Olivine")
	end
	
	if currentSquareData.Data and currentSquareData.Data.Team ~= playerColor then
		if brickColorObject.Value == BrickColor.new("Reddish brown") then
			square.BrickColor = BrickColor.new("Crimson")
		elseif brickColorObject.Value == BrickColor.new("Pastel brown") then
			square.BrickColor = BrickColor.new("Dusty Rose")
		end
	end
end

local function resetColor(currentSquareData)
	currentSquareData.Square.BrickColor = currentSquareData.Square.brick_color_holder.Value
end

local function removeControls(currentSquareData)
	for i,v in next, currentSquareData.Square:GetChildren() do
		if v.Name == "move_controller" or v.Name == "main_piece_controller" then
			v:Destroy()
		end
	end
end


--// Client turn logic
local function runTurn(Board)
	--// Loop through board, add click detectors for each piece and display option when clicked on
	local prevClick = nil
	for x, column in next, Board do
		for y, squareData in next, column do
			--// a square
			if squareData.Data and squareData.Data.Team == playerColor then
				--// our square
				local clickDetector = Instance.new("ClickDetector")
				
				clickDetector.Name = "main_piece_controller"
				clickDetector.Parent = squareData.Square
				
				clickDetector.MouseClick:Connect(function()
					--// Player clicked on one of our squares
					if prevClick == nil then
						prevClick = squareData.Square
						--// Selected square - 1st click
						if squareData.Moves then
							for index, moveSquareDataCoords in next, squareData.Moves do
								--// Add click detectors for each square in moves and add square colours
								local moveSquareData = Board[moveSquareDataCoords[1]][moveSquareDataCoords[2]]
								local moveClickDetector = Instance.new("ClickDetector")
								
								moveClickDetector.Name = "move_controller"
								moveClickDetector.Parent = moveSquareData.Square
								
								moveClickDetector.MouseClick:Connect(function()
									--// Player clicked a move
									for i,v in next, Board do
										for _,k in next, v do
											removeControls(k)
											resetColor(k)
										end
									end
									
									--// FIRE SERVER WITH MOVE
									TurnRemote:FireServer({CurrentTurn = playerColor, X = x,  Y = y, Move = index})
								end)
								
								--// Light up squares
								displayMoveColor(moveSquareData)
							end
						end
					elseif prevClick == squareData.Square then
						prevClick = nil
						--// Deselected square - 2nd click
						if squareData.Moves then
							for index, moveSquareDataCoords in next, squareData.Moves do
								--// Remove click detectors and reset square colours
								local moveSquareData = Board[moveSquareDataCoords[1]][moveSquareDataCoords[2]]
								
								removeControls(moveSquareData)
								resetColor(moveSquareData)
							end
						end
					end
				end)
			end
		end
	end
end


TurnRemote.OnClientEvent:Connect(function(Data)
	if Data.PlayerColor then
		playerColor = Data.PlayerColor
	elseif Data.CurrentTurn then
		currentTurn = Data.CurrentTurn
		
		if currentTurn == playerColor then
			--// Your turn
			status.Text = "Your Turn"
			
			runTurn(Data.State)
			
		else
			--// Opponent's turn
			if playerColor == teams.BLACK then
				status.Text = "White's Turn"
			else
				status.Text = "Black's Turn"
			end
		end
	end
end)
