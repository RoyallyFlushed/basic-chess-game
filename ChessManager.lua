

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SessionRemote = ReplicatedStorage.SessionRemote
local TurnRemote = ReplicatedStorage.TurnRemote

local session = {}
local beginFlag = false
local physicalBoard = workspace.Board
local Board
local moveComplete = false

local checkTypes = {
	EMPTY = 1,
	OPPONENT = 2,
	ALL = 3,
}

local teams = {
	BLACK = 1,
	WHITE = 2,
}

local pieces = {
	PAWN = 1,
	ROOK = 2,
	KNIGHT = 3,
	BISHOP = 4,
	QUEEN = 5,
	KING = 6,
}

local physicalPieces = {
	ServerStorage.Pawn,
	ServerStorage.Rook,
	ServerStorage.Knight,
	ServerStorage.Bishop,
	ServerStorage.Queen,
	ServerStorage.King,
}


local function isBlack(enumTeam)
	return enumTeam == teams.BLACK
end

local function isWhite(enumTeam)
	return enumTeam == teams.WHITE
end



--// Crude session system, 2 players and a person presses play again to start match
SessionRemote.OnServerEvent:Connect(function(player)
	if not beginFlag then
		if table.find(session, player) then
			beginFlag = true
			SessionRemote:FireAllClients({CountdownBegin = true})
		else
			session[#session + 1] = player
			SessionRemote:FireAllClients({PlayerCount = #session})
		end
	elseif beginFlag and session[1] == player then
		startGame()
	end
end)


--// Move actual piece model to square
local function physicallyMovePiece(piece, square, enumTeam)
	if isBlack(enumTeam) then
		piece:SetPrimaryPartCFrame((square.Square.CFrame + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.rad(180), 0))
	else
		piece:SetPrimaryPartCFrame(square.Square.CFrame + Vector3.new(0, 1, 0))
	end
end

--// Move piece to square
local function movePiece(currentSquare, moveIndex)
	local piece = currentSquare.Data.Piece
	local newSquareCoords = currentSquare.Moves[moveIndex]
	local newSquare = Board[newSquareCoords[1]][newSquareCoords[2]]
	
	physicallyMovePiece(piece, newSquare, currentSquare.Data.Team)
	
	--// Remove opponent's piece
	if newSquare.Data and newSquare.Data.Team ~= currentSquare.Data.Team then
		newSquare.Data.Piece:Destroy()
	end
	
	--// add to new square table, remove from old square table
	newSquare.Data = currentSquare.Data
	currentSquare.Data = nil
end

--// Add piece to board
local function addPiece(enumType, squareTable, enumTeam)
	local piece = physicalPieces[enumType]:Clone()
	piece.Parent = workspace
	
	physicallyMovePiece(piece, squareTable, enumTeam)
	
	if isBlack(enumTeam) then
		for i,v in next, piece:GetChildren() do
			v.BrickColor = BrickColor.new("Reddish brown")
		end
	end
	
	squareTable.Data = {
		Type = enumType,
		Team = enumTeam,
		Piece = piece
	}
end

--// Maintenance Function
local function printBoard()
	for i,v in next, Board do
		print(table.unpack(v))
		--[[for _,k in next, v do
			print(table.unpack(v))
		end]]
	end
end


--// Initialise chess board and spawn in pieces
--// White is bottom of board, black is top
local function initBoard()
	Board = {
		{},
		{},
		{},
		{},
		{},
		{},
		{},
		{},
	}
	
	local y = 0
	for i = 1, 64 do
		local x = ((i - 1) % 8) + 1
		
		if (i - 1) % 8 == 0 then
			y += 1
		end
		
		Board[x][y] = {Square = physicalBoard[i]}
	end
	
	--// Load Pawns
	for i = 1, 8 do
		addPiece(pieces.PAWN, Board[i][2], teams.BLACK)
		addPiece(pieces.PAWN, Board[i][7], teams.WHITE)
	end
	--
	
	--// Load Rooks	
	addPiece(pieces.ROOK, Board[1][1], teams.BLACK)
	addPiece(pieces.ROOK, Board[8][1], teams.BLACK)
	addPiece(pieces.ROOK, Board[1][8], teams.WHITE)
	addPiece(pieces.ROOK, Board[8][8], teams.WHITE)
	--
	
	--// Load Knights
	addPiece(pieces.KNIGHT, Board[2][1], teams.BLACK)
	addPiece(pieces.KNIGHT, Board[7][1], teams.BLACK)
	addPiece(pieces.KNIGHT, Board[2][8], teams.WHITE)
	addPiece(pieces.KNIGHT, Board[7][8], teams.WHITE)
	--
	
	--// Load Bishops
	addPiece(pieces.BISHOP, Board[3][1], teams.BLACK)
	addPiece(pieces.BISHOP, Board[6][1], teams.BLACK)
	addPiece(pieces.BISHOP, Board[3][8], teams.WHITE)
	addPiece(pieces.BISHOP, Board[6][8], teams.WHITE)
	--
	
	--// Load Queens
	addPiece(pieces.QUEEN, Board[4][1], teams.BLACK)
	addPiece(pieces.QUEEN, Board[4][8], teams.WHITE)
	--
	
	--// Load Kings
	addPiece(pieces.KING, Board[5][1], teams.BLACK)
	addPiece(pieces.KING, Board[5][8], teams.WHITE)
	--
end

local function squareFree(x, y)
	if Board[x] and Board[x][y] then
		--// This is a valid square
		if not Board[x][y].Data then
			--// Empty square
			return true
		end
		
		--// Occupied
		return false
	end
	
	--// Not a valid square
	return nil
end

local function isOwned(x, y, enumCurrentTeam)
	if squareFree(x, y) == false then
		--// Occupied
		if Board[x][y].Data and Board[x][y].Data.Team == enumCurrentTeam then
			--// Our square
			return true
		end
		
		--// Opponent's square
		return false
	end
	
	--// Not a valid square
	return nil
end

--// Check move is valid
local function moveExists(currentSquareData, index)
	if currentSquareData.Moves and currentSquareData.Moves[index] then
		return true
	end
	
	return false
end

--// Client turn response handler
TurnRemote.OnServerEvent:Connect(function(player, Response)
	--// Review player's chosen move and compare to server board state to confirm choice, move pieces, update board
	--// Once move over, loop through board and clear old movements, run nextTurn with opposite player
	local currentTurn = Response.CurrentTurn
	local x = Response.X
	local y = Response.Y
	local move = Response.Move
	
	if moveExists(Board[x][y], move) then
		--// Move is listed
		if currentTurn == Board[x][y].Data.Team then
			--// They are the right team
			movePiece(Board[x][y], move)
		end
	end
	
	--// Remove all current moves
	for x, column in next, Board do
		for y, squareData in next, column do
			if squareData.Moves then
				squareData.Moves = nil
			end
		end
	end
	
	--// Start next turn
	local opponent = teams.WHITE - (currentTurn - 1)
	nextTurn(opponent)
end)





--// Add move to moves cache
local function addMove(square, newSquareCoords)	
	if square.Moves then
		square.Moves[#square.Moves + 1] = newSquareCoords
	else
		square.Moves = {newSquareCoords}
	end
end

--// Flips the operators
local function flipOperators(aX, aY, bX, bY, flip)
	if flip then
		local dX = bX - aX
		local dY = bY - aY

		aX = bX + dX
		aY = bY + dY
	end
	
	return aX, aY
end

--// Gets the difference in X and Y
local function difference(aX, aY, bX, bY)
	return aX - bX, aY - bY
end



--// Run checks and add move
local function checkMove(aX, aY, bX, bY, enumCurrentTurn, addType)
	local currentSquareData = Board[bX][bY]
	
	--// Determine the team to flip operators
	aX, aY = flipOperators(aX, aY, bX, bY, isWhite(enumCurrentTurn))
	
	if squareFree(aX, aY) and (addType == 1 or addType == 3) then
		--// Free square, Add move to board
		addMove(currentSquareData, {aX, aY})
	elseif isOwned(aX, aY, enumCurrentTurn) == false and (addType == 2 or addType == 3) then
		--// Opponent's square, Add move to board
		addMove(currentSquareData, {aX, aY})
	end
	
	return false
end

--// Run checks iteratively and add move
local function checkMoveLoop(aX, aY, bX, bY, enumCurrentTurn)
	local currentSquareData = Board[bX][bY]
	
	--// Get difference (unit values for loop multiplication)
	aX, aY = difference(aX, aY, bX, bY)
	
	for i = 1, 7 do
		
		local iX, iY = aX * i, aY * i
		local nX, nY = bX + iX, bY + iY
		
		if squareFree(nX, nY) then
			addMove(currentSquareData, {nX, nY})
		elseif isOwned(nX, nY, enumCurrentTurn) == false then
			--// Opponent's piece, add as target
			addMove(currentSquareData, {nX, nY})
			break
		else
			break
		end
		
	end
end



--// Calculate all possible moves for the current player
local function calculateMoves(enumCurrentTurn)
	--// Calculate all possible moves for each piece that the current player owns, add to board in moves table
	for x, column in next, Board do
		for y, squareData in next, column do
			--// a square
			if squareData.Data and squareData.Data.Team == enumCurrentTurn then
				--// x,y is our square
				
				--// Movement logic for each piece type
				if squareData.Data.Type == pieces.PAWN then
					
					--// Check forward
					checkMove(x, y + 1, x, y, enumCurrentTurn, checkTypes.EMPTY)
					--// Check right take
					checkMove(x - 1, y + 1, x, y, enumCurrentTurn, checkTypes.OPPONENT)
					--// Check left take
					checkMove(x + 1, y + 1, x, y, enumCurrentTurn, checkTypes.OPPONENT)
					--// Beginning 2 ahead
					if y == 2 or y == 7 then
						checkMove(x, y + 2, x, y, enumCurrentTurn, checkTypes.EMPTY)
					end
					
				elseif squareData.Data.Type == pieces.ROOK then
					
					--// Check Forward
					checkMoveLoop(x, y + 1, x, y, enumCurrentTurn)
					--// Check Left
					checkMoveLoop(x + 1, y, x, y, enumCurrentTurn)
					--// Check Right
					checkMoveLoop(x - 1, y, x, y, enumCurrentTurn)
					--// Check Backward
					checkMoveLoop(x, y - 1, x, y, enumCurrentTurn)
					
				elseif squareData.Data.Type == pieces.KNIGHT then
					
					--// Right Top
					checkMove(x - 2, y + 1, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Right Bottom
					checkMove(x - 2, y - 1, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Top Right
					checkMove(x - 1, y + 2, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Top Left
					checkMove(x + 1, y + 2, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Left Top
					checkMove(x + 2, y + 1, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Left Bottom
					checkMove(x + 2, y - 1, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Bottom Left
					checkMove(x + 1, y - 2, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Bottom Right
					checkMove(x - 1, y - 2, x, y, enumCurrentTurn, checkTypes.ALL)
					
				elseif squareData.Data.Type == pieces.BISHOP then
					
					--// Check Top Left
					checkMoveLoop(x + 1, y + 1, x, y, enumCurrentTurn)
					--// Check Top Right
					checkMoveLoop(x - 1, y + 1, x, y, enumCurrentTurn)
					--// Check Bottom Left
					checkMoveLoop(x + 1, y - 1, x, y, enumCurrentTurn)
					--// Check Bottom Right
					checkMoveLoop(x - 1, y - 1, x, y, enumCurrentTurn)
					
				elseif squareData.Data.Type == pieces.QUEEN then
					
					--// Check Forward
					checkMoveLoop(x, y + 1, x, y, enumCurrentTurn)
					--// Check Left
					checkMoveLoop(x + 1, y, x, y, enumCurrentTurn)
					--// Check Right
					checkMoveLoop(x - 1, y, x, y, enumCurrentTurn)
					--// Check Backward
					checkMoveLoop(x, y - 1, x, y, enumCurrentTurn)
					
					--// Check Top Left
					checkMoveLoop(x + 1, y + 1, x, y, enumCurrentTurn)
					--// Check Top Right
					checkMoveLoop(x - 1, y + 1, x, y, enumCurrentTurn)
					--// Check Bottom Left
					checkMoveLoop(x + 1, y - 1, x, y, enumCurrentTurn)
					--// Check Bottom Right
					checkMoveLoop(x - 1, y - 1, x, y, enumCurrentTurn)
					
				elseif squareData.Data.Type == pieces.KING then
					
					--// Check Top Left
					checkMove(x + 1, y + 1, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Check Top Middle
					checkMove(x, y + 1, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Check Top Right
					checkMove(x - 1, y + 1, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Check Middle Right
					checkMove(x - 1, y, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Check Bottom Right
					checkMove(x - 1, y - 1, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Check Bottom Middle
					checkMove(x, y - 1, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Check Bottom Left
					checkMove(x + 1, y - 1, x, y, enumCurrentTurn, checkTypes.ALL)
					--// Check Middle Left
					checkMove(x + 1, y, x, y, enumCurrentTurn, checkTypes.ALL)
					
				end
			end
		end
	end
end





--// Inform players of their colors
local function informPlayers()
	TurnRemote:FireClient(session[teams.BLACK], {PlayerColor = teams.BLACK})
	TurnRemote:FireClient(session[teams.WHITE], {PlayerColor = teams.WHITE})
end

--// Inform players of current turn
function nextTurn(enumCurrentTurn)
	calculateMoves(enumCurrentTurn)
	
	TurnRemote:FireAllClients({CurrentTurn = enumCurrentTurn, State = Board})
end


--// Initiate basic gameplay loop
function startGame()
	initBoard()
	informPlayers()
	nextTurn(teams.BLACK)
end
