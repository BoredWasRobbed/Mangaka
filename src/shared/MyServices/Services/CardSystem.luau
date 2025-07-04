--[[
	CardSystem
	
	Manages the core logic for a single-player deck-building game.
	This module handles player decks, hands, resources, and card effects.
	It now includes a "Cohesion" system for card synergy.
	
	Author: Gemini
	Last Updated: July 4, 2025
]]

local CardSystem = {}

--==============================================================================
--[[
	TYPE DEFINITIONS
]]
--==============================================================================

-- Type definition for the player's state
export type PlayerState = {
	Player: Player,
	Deck: { string },
	Hand: { string },
	Discard: { string },
	Resources: {
		Inspiration: number,
		Ink: number,
		Grit: number,
		Hype: number,
	},
	LastTagsPlayed: { string }?,
}

-- Type definition for a single card's data in the registry
export type CardInfo = {
	Name: string,
	Type: string,
	Tags: { string },
	Description: string,
	Cost: number,
	InkCost: number?,
	CohesionDescription: string?,
	OnPlay: (playerState: PlayerState) -> PlayerState,
	Cohesion: {
		RequiredTag: string,
		Bonus: (playerState: PlayerState) -> PlayerState,
	}?,
}

--==============================================================================
--[[
	CARD REGISTRY
	
	This is the "master list" of all cards that can exist in the game.
]]
--==============================================================================
local CardData: { [string]: CardInfo } = {
	-- === STARTER CARDS ===
	["ROUGH_SKETCH"] = {
		Name = "Rough Sketch",
		Type = "Skill",
		Tags = { "Skill" },
		Description = "Gain 1 Inspiration.",
		Cost = 0,
		OnPlay = function(playerState: PlayerState): PlayerState
			playerState.Resources.Inspiration += 1
			print(playerState.Player.Name .. " gained 1 Inspiration.")
			return playerState
		end,
	},
	["ALL_NIGHTER"] = {
		Name = "All-Nighter",
		Type = "Skill",
		Tags = { "Skill" },
		Description = "Gain 2 Ink. Add a 'Burnout' to your discard pile.",
		Cost = 0,
		OnPlay = function(playerState: PlayerState): PlayerState
			playerState.Resources.Ink += 2
			table.insert(playerState.Discard, "BURNOUT")
			print(playerState.Player.Name .. " gained 2 Ink and is feeling the Burnout.")
			return playerState
		end,
	},

	-- === FLAW CARDS ===
	["BURNOUT"] = {
		Name = "Burnout",
		Type = "Flaw",
		Tags = { "Flaw" },
		Description = "Does nothing. A dead card in your hand.",
		Cost = 0,
		OnPlay = function(playerState: PlayerState): PlayerState
			print(playerState.Player.Name .. " is suffering from Burnout! The card does nothing.")
			return playerState
		end,
	},
	["ARTISTS_BLOCK"] = {
		Name = "Artist's Block",
		Type = "Flaw",
		Tags = { "Flaw" },
		Description = "Pay 2 Grit to discard this card.",
		Cost = 0,
		OnPlay = function(playerState: PlayerState): PlayerState
			-- This card's effect is typically handled by a UI prompt,
			-- not by "playing" it. We'll add a print for logic testing.
			print(playerState.Player.Name .. " has Artist's Block! This card shouldn't be 'played' directly.")
			return playerState
		end,
	},

	-- === IDEA CARDS (Examples) ===
	["SPIKY_PROTAGONIST"] = {
		Name = "Spiky-Haired Protagonist",
		Type = "Idea",
		Tags = { "Character", "Protagonist" },
		Description = "A classic hero. Generates 3 Hype when published.",
		Cost = 2, -- Inspiration cost
		InkCost = 1, -- Ink cost to play/publish
		OnPlay = function(playerState: PlayerState): PlayerState
			-- In a real game, this would contribute to a "Manuscript"
			playerState.Resources.Hype += 3
			print(playerState.Player.Name .. " features their Spiky-Haired Protagonist! +3 Hype.")
			return playerState
		end,
	},
	["TOURNAMENT_ARC"] = {
		Name = "Tournament Arc",
		Type = "Idea",
		Tags = { "Trope", "Action" },
		Description = "A classic trope. Generates 5 Hype when published.",
		Cost = 4,
		InkCost = 2,
		OnPlay = function(playerState: PlayerState): PlayerState
			playerState.Resources.Hype += 5
			print(playerState.Player.Name .. " begins a Tournament Arc! +5 Hype.")
			return playerState
		end,
	},
	["DRAMATIC_ENTRANCE"] = {
		Name = "Dramatic Entrance",
		Type = "Idea",
		Tags = { "Trope", "Action" },
		Description = "A sudden appearance. Generates 2 Hype.",
		CohesionDescription = "Cohesion: If played after a 'Character' card, draw a card.",
		Cost = 3,
		InkCost = 1,
		OnPlay = function(playerState: PlayerState): PlayerState
			playerState.Resources.Hype += 2
			print(playerState.Player.Name .. " creates a Dramatic Entrance! +2 Hype.")
			return playerState
		end,
		Cohesion = {
			RequiredTag = "Character",
			Bonus = function(playerState: PlayerState): PlayerState
				print("COHESION BONUS! Drawing a card.")
				-- We call the Draw function directly from within the module
				CardSystem.Draw(playerState.Player, 1)
				return playerState
			end,
		},
	},
}

--==============================================================================
--[[
	PLAYER STATE MANAGEMENT
]]
--==============================================================================

-- A dictionary to hold the state of the current player.
local playerStates: { [number]: PlayerState } = {}

-- Creates a new, clean state for a player to start a run.
function CardSystem.InitializePlayer(player: Player)
	local playerState: PlayerState = {
		Player = player,
		Deck = {},
		Hand = {},
		Discard = {},
		Resources = {
			Inspiration = 0,
			Ink = 0,
			Grit = 1,
			Hype = 0,
		},
		LastTagsPlayed = nil,
	}

	-- Populate the starting deck
	for i = 1, 7 do
		table.insert(playerState.Deck, "ROUGH_SKETCH")
	end
	for i = 1, 3 do
		table.insert(playerState.Deck, "ALL_NIGHTER")
	end

	playerStates[player.UserId] = playerState

	print("Initialized player: " .. player.Name)
	CardSystem.Shuffle(player)
end

-- Retrieves the state for a given player.
function CardSystem.GetPlayerState(player: Player): PlayerState?
	return playerStates[player.UserId]
end

--==============================================================================
--[[
	CORE DECK ACTIONS
]]
--==============================================================================

-- Shuffles the player's Discard pile into their Deck pile.
function CardSystem.Shuffle(player: Player)
	local playerState = playerStates[player.UserId]
	if not playerState then
		return
	end

	-- Move all cards from Discard to Deck
	for _, cardId in ipairs(playerState.Discard) do
		table.insert(playerState.Deck, cardId)
	end
	playerState.Discard = {}

	-- Fisher-Yates shuffle algorithm
	local deck = playerState.Deck
	for i = #deck, 2, -1 do
		local j = math.random(i)
		deck[i], deck[j] = deck[j], deck[i]
	end

	print(player.Name .. "'s deck has been shuffled.")
end

-- Draws a specified number of cards from the Deck to the Hand.
function CardSystem.Draw(player: Player, amount: number)
	local playerState = playerStates[player.UserId]
	if not playerState then
		return
	end

	for i = 1, amount do
		-- If deck is empty, shuffle discard pile into it
		if #playerState.Deck == 0 then
			if #playerState.Discard == 0 then
				print("No cards left to draw.")
				break -- Stop drawing if both piles are empty
			end
			print("Deck is empty. Shuffling discard pile.")
			CardSystem.Shuffle(player)
		end

		-- Move card from deck to hand
		local drawnCard = table.remove(playerState.Deck, 1)
		if drawnCard then
			table.insert(playerState.Hand, drawnCard)
			print("Drew card: " .. CardData[drawnCard].Name)
		end
	end
end

-- Plays a card from the player's hand.
-- cardInstanceId is used to differentiate between identical cards in hand.
function CardSystem.PlayCard(player: Player, cardInstanceId: number)
	local playerState = playerStates[player.UserId]
	if not playerState then
		return
	end

	if cardInstanceId > #playerState.Hand or cardInstanceId < 1 then
		warn("Invalid card instance ID.")
		return
	end

	local cardId = table.remove(playerState.Hand, cardInstanceId)
	local cardInfo = CardData[cardId]

	if not cardInfo then
		warn("Attempted to play a card that does not exist in the Card Registry: " .. tostring(cardId))
		return
	end

	print(player.Name .. " plays: " .. cardInfo.Name)

	-- === NEW: COHESION CHECK ===
	if cardInfo.Cohesion and playerState.LastTagsPlayed then
		local requiredTag = cardInfo.Cohesion.RequiredTag
		-- Check if the required tag exists in the list of last played tags
		if table.find(playerState.LastTagsPlayed, requiredTag) then
			playerState = cardInfo.Cohesion.Bonus(playerState)
		end
	end

	-- Execute the card's standard OnPlay effect
	playerState = cardInfo.OnPlay(playerState)

	-- Update the LastTagsPlayed with the tags of the card just played
	playerState.LastTagsPlayed = cardInfo.Tags

	-- Move the played card to the discard pile
	table.insert(playerState.Discard, cardId)

	print(cardInfo.Name .. " was moved to the discard pile.")
end

-- Adds a newly acquired card to the player's discard pile.
function CardSystem.AcquireCard(player: Player, cardId: string)
	local playerState = playerStates[player.UserId]
	if not playerState or not CardData[cardId] then
		return
	end

	-- Check if player can afford it (example logic)
	local cost = CardData[cardId].Cost
	if playerState.Resources.Inspiration >= cost then
		playerState.Resources.Inspiration -= cost
		table.insert(playerState.Discard, cardId)
		print(player.Name .. " acquired '" .. CardData[cardId].Name .. "' for " .. cost .. " Inspiration.")
	else
		print(player.Name .. " cannot afford '" .. CardData[cardId].Name .. "'.")
	end
end

-- Resets a player's resources and state at the start of a new turn/round.
function CardSystem.ResetTurnResources(player: Player)
	local playerState = playerStates[player.UserId]
	if not playerState then
		return
	end

	playerState.Resources.Inspiration = 0
	playerState.Resources.Ink = 0
	-- Grit and Hype persist between turns, but you could change that here.

	-- NEW: Reset the cohesion tracker for the new turn
	playerState.LastTagsPlayed = nil

	print("Turn resources and cohesion have been reset.")
end

-- A utility function to get the full data for cards in a player's hand
function CardSystem.GetHandData(player: Player): { { [string]: any } }
	local playerState = playerStates[player.UserId]
	local handData = {}
	if not playerState then
		return handData
	end

	for i, cardId in ipairs(playerState.Hand) do
		-- Create a copy of the card data to avoid modifying the master registry
		local data = {}
		for k, v in pairs(CardData[cardId]) do
			data[k] = v
		end

		-- Add the instance ID so the UI knows which card to tell the system to play
		data.InstanceId = i
		table.insert(handData, data)
	end

	return handData
end

return CardSystem
