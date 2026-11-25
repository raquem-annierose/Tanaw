--!strict
-- Who may use the admin tools. One place for both:
--   - the admin panel (AdminPanelService): level per community role in Config.Admin.PanelLevels
--     (only the Owner for now). In a Studio playtest everyone gets level 3.
--   - the chat commands (AdminService): roles in Config.Admin.Roles or Config.Admin.UserIds.
--     AdminService also checks that it runs in DEV / STAGING.
--
-- Both use CommunityRoles, so a failed lookup means "no access" (fails closed).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CommunityRoles = require(script.Parent.Parent.community.CommunityRoles)
local Config = require(ReplicatedStorage.Shared.core.Config)

local AdminAuth = {}

-- 0 = no panel, 1 = Moderator, 2 = Admin, 3 = Owner. Yields the first time (community lookup).
function AdminAuth.panelLevel(player: Player): number
	if Config.Admin.PanelInStudio and RunService:IsStudio() then
		return 3
	end
	local roles = CommunityRoles.get(player)
	local level = 0
	for role, roleLevel in Config.Admin.PanelLevels do
		if roles[role] then
			level = math.max(level, roleLevel)
		end
	end
	return math.clamp(level, 0, 3)
end

-- True if the player may use the chat commands. Yields the first time.
function AdminAuth.canUseCommands(player: Player): boolean
	if table.find(Config.Admin.UserIds, player.UserId) then
		return true
	end
	return CommunityRoles.hasAny(player, Config.Admin.Roles)
end

return AdminAuth
