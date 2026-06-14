-- Entry point that activates the top-down camera once the local character
-- spawns. The character only loads after file-select (CharacterAutoLoads is
-- off), so binding on CharacterAdded keeps the menu camera default.
local TopDownCamera = require(script.Parent.TopDownCamera)

TopDownCamera.bindLocalPlayer()
