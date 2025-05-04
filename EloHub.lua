local universeId = game.GameId

if universeId == 7436755782 then
    loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ElopingDev/EloHub/refs/heads/main/EloHubGarden.lua"))()

elseif universeId == 5750914919 then
    loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ElopingDev/EloHub/refs/heads/main/EloHubFisch.lua"))()

elseif universeId == 6504986360 then
    loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ElopingDev/EloHub/refs/heads/main/EloHubBGSI.lua"))()

elseif universeId == 7513130835 then
    loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ElopingDev/EloHub/refs/heads/main/EloHubDrill.lua"))()

else
    print("Didn't find supported game")
end
