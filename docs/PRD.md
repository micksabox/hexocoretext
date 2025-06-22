## Title and Overview
This document describes a casual word game application, Hexcoretext. The game logic is executed onchain to guarantee fairness and rule integrity with verifiability. There is a hexagonal grid which is initially filled randomly with an alphabet letter in each tile. Then, up to 2 players take turns in capturing tiles that connect with each other on the hexagonal grid. Each time a hexagon is formed from captured tiles, the player with the majority of those captures is granted a point. The first to 16 points is declared game winner.

### Objective
The game is for casual players and a platform for developers to mod. The objective is fun primarily. It is also designed to be a platform for vibe gaming developers to customize and build upon further.

## Scope
The game should be designed initially for the web but be built so that core component logic can be shared in a React Native application. The game's onchain backend should be implemented with the Dojo system, and the Torii indexer to react to on-chain events.

### User Personas
1. Casual word puzzle players. These are casual gamers who can enjoy a short game in their free time for fun. They play games by inviting other players with a personal link or play against bots. They interact within the game, earn rewards and read hexoLORE.
2. Modders. These are former players converted into game advocates. Community managers and organizers need an integrated experience to serve a custom game series their community.

## Functional Requirements

### Turn Based Play
- Whenever a player captures enough tiles to form a hexagon, and a majority of their tiles are captured in the turn, then the central tile becomes locked to the player with the majority of tiles. For every new hexagon captured, a point is granted to the player with a majority of the captured tiles, regardless of which player is taking the current turn.
- Each turn can result in multiple tiles captured, multiple hexagons captured, and multiple points assigned. Each turn must calculate and update the grid state of captured and locked tiles, if any.
- The current allowable turn player index is enforced at the smart contract level. A player can only submit a turn if it the current player index matches their position.

### Tile position change
- Once per turn, a single position change is allowed. This means the player can choose to swap a hex cell with it's neighbour, if that cell and it's neighbour is unlocked. The tiles being swapped can be captured by either player.

### Hexagon Captures
- A captured hexagon means that all the surrounding tiles of a given cell, including the cell itself, are marked captured by some player. The central tile is locked, and the unlocked tiles surrounding are replaced randomly at the end of the turn, regardless if they are captured. Once the tiles are replaced, points are awarded and the turn rotates to the next player.

### SuperHexagons
- During the process of locking hex tiles, a complete hexagon can form of locked tiles. This is called a Super Hexagon.
- In addition to the unlocked surrounding tiles of a captured hexagon being replaced, all of the tiles in a super hexagon should be replaced randomly

### Game Sessions
- Games are instantiated with parameters:
	- score limit, defaulting to 16. When the score is reached or exceeded after a turn is processed, the game state is marked completed and no further actions can be made for that game. The game session ends.
	- registered player addresses. Maximum 2. If playing against a bot, only a single address is registered.
	- current turn index. A random index initialized from 0 to 1 for 2 total players.
	- word list merkle root. The Merkle root of the valid word list.

### Game Grids
- Cell tile positions are stored in axial coordinate format using q and r variables
- Hexagon grids use the flat top configuration
- Individual cells use North, South, Northwest, Southwest, Northeast and Southeast as neighbour designations
- Center of the grid position is {q:0, r:0} and neighbour positions are a direction vector from center. 
	- North direction is {q:0, r:-1}
	- South direction is {q:0, r:1}
	- Northwest direction is {q:-1, r: 0}
	- Northeast direction is {q:+1, r:-1}
	- Southwest direction is {q:-1, r:1}
	- Southeast direction is {q:1, r:0}
- The grid size (radius from center) should default to 5.
- When initializing the grid, start from center

### Enforcing Game Rules
- Valid word inclusion checks. A word list should be sorted and used for a Merkle tree structure. The Merkle root of the word list should be submitted to the game contract. During each turn, the player submits a transaction with a path from their word to the merkle root. The contract should enforce that only valid words from the word list are valid, else throw with an error.

- Letter chain checks. The player submits a transaction including an array of hex tiles {position} they are capturing during their turn. The contract should check each tile submitted and ensure they are not already captured or locked, or if they are captured or locked, then ensure that it is their own tile and hasn't been captured/locked by another player. The contract should strictly enforce the rule that the tiles must be neighbours with each other, and that each of the positions are distinct and exist within the range of the grid.

### Smart Contract System
- Gameplay logic is executed on-chain on the Starknet network.
- Contract emitted events are captured by the Torii indexer infrastructure and game state is saved.

### Localization
- The app should aim to be localized for different languages. This includes user interface elements, documentation and word lists.
- The app should implement a strategy according to best practices for localization and internationalization.
- For word lists, special characters should be normalized. Ex. é should simply be "e", so any words in other languages that use é should have their word in the word list be normalized to the simple letter "e".

### Monorepo
- Relevant core logic should be separated into modules that can be used both in a webapp and React Native mobile application. The goal is to be able to reuse logic written in Typescript as much as possible across platforms. The initial focus should be on the web application, with the mobile application being developed later.
- The Bun tool should be used for the monorepo.
- The documentation should be a separate repo.

### Game Shareability
- Each game instance can be shared using a unique hyperlink. The game moves for that game instance should be able to be replayed by viewers. This means that the game actions are stored in a game server database, using Torii indexer to capture events.

### Game Customizability
- There should be an interface for word sponsors to add custom words to the word list. This would generate a new Merkle tree and root, and the root can be submitted to a game that has been initialized with that root.
- In order to create a new game, a fee must be paid in ERC-20 compatible cryptocurrency. This fee becomes part of the prize pool for the game, with a customizable percentage going towards the game creator and bot creator.
- Core game parameters should be permissioned under administrative privileges
- There is a custom interface for creating custom games with a modified word list, prize pool, sponsorship and animation set.

### AI Bot
- There should be an AI bot that is able to play the game. Strategies should be developed such that a computerized system is able to: discover possible words, rank word choices with strategies, plan multiple steps ahead, and execute autonomous contract interactions. These can be prompted to an LLM or AI model. Different hexocoretexes can use different LLM models and varying difficulties.

### Rewards System
- Each word captured rewards the player with points if they meet a criteria system.
- Additional achievements should be possible like longest word of the day/week.
- Fixed Achievements
	- Over 8 letters
	- Over 9 letters
	- 2-point turn
	- 3-point turn
- Points accrue to the player based on Achievements and contract emitted events, which the Torii indexer integration uses to show game animations and notices.

### Animations & Interactivity
- Animations should be prepared to engage and notify the user. Whenever events occur by the player or their opponent, an animation should trigger playing.
- Animations may be customizable with an EMOJI, sponsors could include custom animations in their campaigns.

### Sponsorship Campaigns
- Requires sending and locking an admin parameterized amount of digital tokens that are distributed as player rewards per match.
- Custom words can be added to the games wordlist, and game contracts deployed in a reserved sequence.
- Sponsorship campaigns have their own dashboard and owner.

### Consistency
- Phrasing across application should be used consistently to simplify. It helps making the application easier to localize also.
- Common narrative themes can span across all elements related to the background lore of the Hexocortext game
	- The "brain" of the bots and opponent persona is the hexocortex.
	- Submitting and building onchain transactions is referred to as "hexocoreTX".
	- Whenever a letter chain completes 1 or many hexagon(s) in a turn and locks, the action is "mining hexoCORE" if points were awarded
	- After a game is played, the list of words used are transcribed into a decorated certificate, the set of which is referred to as "hexoLORE"
- Common branding elements should be modularized (icons, brand names, brand colours) and also customizable via sponsorship campaign
### Acceptance Criteria
- The various logical scenarios of the game rules should be rigorously testable.
- Each stakeholder should have a page dedicated to their learning goals and integration call to action landing page.
- All processes should be documented in parallel.

## Milestones
1. Core components
	1. Smart contract logic rule testing scenarios.
	2. Integration of contract and game logic with Dojo entity system.
	3. Word list merklization CLI. SCRABBLE list.
	4. Calculating merkle tree path.
2. Testing Core Components
3. In Game session
	1. Hexagon grid game state machine
	2. Player action toolbar
	3. Top Navigation menu and player profile trigger
		1. Notification and animation system
4. Game Lobby
	1. Start game
		1. Game Mode: Player vs Player
		2. Game Mode: Player vs hexocoretext (AI)
		3. Game Mode: Build hexocoretext
5. hexoLORE: server saved indexed game histories (with word list and timing)
		1. Personal history of matches and results, with word list used
