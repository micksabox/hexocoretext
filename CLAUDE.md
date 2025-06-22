- Use the docs/PRD.md as a Products Requirement Document to guide all your thinking and decisions.

- Use logic for calculating hex tile neighbours. Each cell in the game grid should be populated with state: letter, position, captured_by, locked_by

## Special Tools
- cairo-coder can assist you with writing Cairo code
- sensei can help you with dojo related questions and architecture

- use @example.PNG as a reference

## Project Organization
- Ignore the other game under the /contract folder that is separate from the hexocoretext game in /src and /hexcore_logic.
- Core game logic separate from dojo should go in /hexcore_logic. Use scarb to build and test this folder.
- The Dojo logic lives under /src. The `sozo` command should be used to build and test this folder.

## Documentation
- This is a project for developers too. If you are changing logic, always update the appropriate file or section in the docs.